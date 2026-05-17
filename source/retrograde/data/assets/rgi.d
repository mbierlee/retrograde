/**
 * Retrograde Engine
 *
 * Authors:
 *  Mike Bierlee, m.bierlee@lostmoment.com
 * Copyright: 2014-2026 Mike Bierlee
 * License:
 *  This software is licensed under the terms of the MIT license.
 *  The full terms of the license can be found in the LICENSE.txt file.
 */

module retrograde.data.assets.rgi;

import retrograde.data.image : Image, ChannelFormat, bytesPerChannel;
import retrograde.data.assets.readercommon : readUInt, readUShort, readUByte;
import retrograde.std.memory : ResultPtr, failedPtr, makeRaw, successPtr;
import retrograde.std.stringid : StringId, sid;
import retrograde.std.result : Result, success, failure;

enum byte[] rgiMagicNumber = [0x52, 0x47, 0x49, 0x20];
private enum size_t rgiHeaderSize = 9;
private enum size_t rgiImageHeaderSize = 10;
private enum size_t rgiPaletteCountSize = 4;

enum CompressionType : ubyte {
    none = 0,
}

enum ColorMode : ubyte {
    direct = 0,
    indexed = 1,
}

enum IndexFormat : ubyte {
    u8 = 0,
    u16 = 1,
    u32 = 2,
}

size_t bytesPerIndex(IndexFormat fmt) {
    final switch (fmt) {
    case IndexFormat.u8:
        return 1;
    case IndexFormat.u16:
        return 2;
    case IndexFormat.u32:
        return 4;
    }
}

private bool exceedsIndexFormatRange(uint paletteCount, IndexFormat fmt) {
    final switch (fmt) {
    case IndexFormat.u8:
        return paletteCount > 256;
    case IndexFormat.u16:
        return paletteCount > 65_536;
    case IndexFormat.u32:
        // Palette entry count is a uint, so it always fits in a u32 index.
        return false;
    }
}

/**
 * Metadata for the RGI file header, image header, and (when indexed) palette
 * entry count. After a successful parse all fields are guaranteed to be valid
 * and self-consistent; in particular `paletteEntryCount` is 0 in direct color
 * mode and `indexFormat` is meaningful only in indexed mode.
 */
struct ImageHeader {
    /// File format version (currently always 1).
    ushort formatVersion;
    /// Compression applied to the pixel data section.
    CompressionType compression;
    /// Whether pixels are stored as direct samples or as palette indices.
    ColorMode colorMode;
    /// Encoding of each palette index. Only meaningful when `colorMode == indexed`.
    IndexFormat indexFormat;
    /// Image width in pixels (always > 0).
    uint width;
    /// Image height in pixels (always > 0).
    uint height;
    /// Number of channels per pixel (1..4).
    ubyte channelCount;
    /// Per-channel storage format.
    ChannelFormat channelFormat;
    /// Number of palette entries. 0 in direct mode.
    uint paletteEntryCount;
}

/**
 * Parse and validate the leading headers of an RGI file: the 9-byte file
 * header, the 10-byte image header, and (in indexed mode) the 4-byte palette
 * entry count. Palette entries and pixel data are not read.
 *
 * Params:
 *   data = The raw RGI file bytes.
 * Returns:
 *   A successful `Result!ImageHeader` containing the parsed header, or a
 *   failure with a descriptive error message if the headers are missing,
 *   malformed, or specify an unsupported value.
 */
Result!ImageHeader loadImageHeader(const(ubyte)[] data) {
    if (data.length < rgiHeaderSize) {
        return failure!ImageHeader("Data is too short to be an RGI file.");
    }

    if (data[0 .. 4] != rgiMagicNumber) {
        return failure!ImageHeader("Data is not a valid RGI file.");
    }

    if (data[4 .. 6] != [0x01, 0x00]) {
        return failure!ImageHeader("Unsupported RGI version.");
    }

    if (data[6] != cast(ubyte) CompressionType.none) {
        return failure!ImageHeader("Unsupported RGI compression type.");
    }

    ubyte rawColorMode = data[7];
    if (rawColorMode != cast(ubyte) ColorMode.direct
        && rawColorMode != cast(ubyte) ColorMode.indexed) {
        return failure!ImageHeader("Unsupported RGI color mode.");
    }

    ColorMode colorMode = cast(ColorMode) rawColorMode;

    ubyte rawIndexFormat = data[8];
    if (colorMode == ColorMode.direct) {
        if (rawIndexFormat != 0) {
            return failure!ImageHeader("RGI index format must be 0 in direct color mode.");
        }
    } else {
        if (rawIndexFormat != cast(ubyte) IndexFormat.u8
            && rawIndexFormat != cast(ubyte) IndexFormat.u16
            && rawIndexFormat != cast(ubyte) IndexFormat.u32) {
            return failure!ImageHeader("Unsupported RGI index format.");
        }
    }

    IndexFormat indexFormat = cast(IndexFormat) rawIndexFormat;

    size_t offset = rgiHeaderSize;
    if (data.length - offset < rgiImageHeaderSize) {
        return failure!ImageHeader("Cannot read RGI image header: Unexpected end of data.");
    }

    uint width = readUInt(data, offset);
    offset += 4;
    if (width == 0) {
        return failure!ImageHeader("Invalid RGI image width.");
    }

    uint height = readUInt(data, offset);
    offset += 4;
    if (height == 0) {
        return failure!ImageHeader("Invalid RGI image height.");
    }

    ubyte channelCount = readUByte(data, offset);
    offset += 1;
    if (channelCount < 1 || channelCount > 4) {
        return failure!ImageHeader("Invalid RGI channel count.");
    }

    ubyte rawChannelFormat = readUByte(data, offset);
    offset += 1;
    if (rawChannelFormat != cast(ubyte) ChannelFormat.u8
        && rawChannelFormat != cast(ubyte) ChannelFormat.u16
        && rawChannelFormat != cast(ubyte) ChannelFormat.u32) {
        return failure!ImageHeader("Unsupported RGI channel format.");
    }

    ChannelFormat channelFormat = cast(ChannelFormat) rawChannelFormat;

    uint paletteEntryCount = 0;
    if (colorMode == ColorMode.indexed) {
        if (data.length - offset < rgiPaletteCountSize) {
            return failure!ImageHeader("Cannot read RGI palette entry count: Unexpected end of data.");
        }

        paletteEntryCount = readUInt(data, offset);
        if (paletteEntryCount == 0) {
            return failure!ImageHeader("Invalid RGI palette entry count.");
        }

        if (exceedsIndexFormatRange(paletteEntryCount, indexFormat)) {
            return failure!ImageHeader("RGI palette entry count exceeds index format range.");
        }
    }

    ImageHeader header;
    header.formatVersion = 1;
    header.compression = cast(CompressionType) data[6];
    header.colorMode = colorMode;
    header.indexFormat = indexFormat;
    header.width = width;
    header.height = height;
    header.channelCount = channelCount;
    header.channelFormat = channelFormat;
    header.paletteEntryCount = paletteEntryCount;
    return success(header);
}

ResultPtr!Image loadImage(const(ubyte)[] data, StringId name = sid("unknown")) {
    auto headerResult = loadImageHeader(data);
    if (headerResult.isFailure()) {
        return failedPtr!Image(headerResult.errorMessage());
    }

    ImageHeader header = headerResult.value();

    size_t pixelBytes = cast(size_t) header.channelCount * bytesPerChannel(header.channelFormat);
    size_t totalPixels = cast(size_t) header.width * cast(size_t) header.height;
    size_t expandedPixelBytes = totalPixels * pixelBytes;

    Image* image = makeRaw!Image();
    image.name = name;
    image.width = header.width;
    image.height = header.height;
    image.channelCount = header.channelCount;
    image.channelFormat = header.channelFormat;
    image.pixelData.capacity = expandedPixelBytes;

    size_t offset = rgiHeaderSize + rgiImageHeaderSize;
    if (header.colorMode == ColorMode.indexed) {
        offset += rgiPaletteCountSize;
    }

    if (header.colorMode == ColorMode.direct) {
        if (data.length - offset < expandedPixelBytes) {
            return failedPtr!Image("Cannot read RGI pixel data: Unexpected end of data.");
        }

        for (size_t i = 0; i < expandedPixelBytes; i++) {
            image.pixelData ~= data[offset + i];
        }

        offset += expandedPixelBytes;
    } else {
        // Indexed: read palette, then read indices and expand to direct samples.
        size_t paletteBytes = cast(size_t) header.paletteEntryCount * pixelBytes;
        if (data.length - offset < paletteBytes) {
            return failedPtr!Image("Cannot read RGI palette data: Unexpected end of data.");
        }

        size_t paletteOffset = offset;
        offset += paletteBytes;

        size_t indexedPixelBytes = totalPixels * bytesPerIndex(header.indexFormat);
        if (data.length - offset < indexedPixelBytes) {
            return failedPtr!Image("Cannot read RGI indexed pixel data: Unexpected end of data.");
        }

        for (size_t i = 0; i < totalPixels; i++) {
            uint index;
            final switch (header.indexFormat) {
            case IndexFormat.u8:
                index = readUByte(data, offset);
                offset += 1;
                break;
            case IndexFormat.u16:
                index = readUShort(data, offset);
                offset += 2;
                break;
            case IndexFormat.u32:
                index = readUInt(data, offset);
                offset += 4;
                break;
            }

            if (index >= header.paletteEntryCount) {
                return failedPtr!Image("RGI pixel index out of palette range.");
            }

            size_t entryStart = paletteOffset + cast(size_t) index * pixelBytes;
            for (size_t b = 0; b < pixelBytes; b++) {
                image.pixelData ~= data[entryStart + b];
            }
        }
    }

    if (offset != data.length) {
        return failedPtr!Image("RGI file contains unexpected trailing bytes.");
    }

    return successPtr(image);
}

version (UnitTesting)  :  ///

void runRgiTests() {
    import retrograde.std.test : test, writeSection;

    writeSection("-- RGI tests --");

    test("Load 2x2 RGBA direct image", {
        ubyte[35] imageData = [
            // File header
            0x52, 0x47, 0x49, 0x20, // Magic ("RGI ")
            0x01, 0x00, // Version (1)
            0x00, // Compression (None)
            0x00, // ColorMode (Direct)
            0x00, // IndexFormat (unused / 0)

            // Image header
            0x02, 0x00, 0x00, 0x00, // Width  (2)
            0x02, 0x00, 0x00, 0x00, // Height (2)
            0x04, // Channel count (4)
            0x00, // Channel format (u8)

            // Pixel data
            0xFF, 0x00, 0x00, 0xFF, // (0,0) red
            0x00, 0xFF, 0x00, 0xFF, // (1,0) green
            0x00, 0x00, 0xFF, 0xFF, // (0,1) blue
            0xFF, 0xFF, 0xFF, 0x80, // (1,1) translucent white
        ];

        auto result = loadImage(imageData);
        assert(result.isSuccessful());

        auto image = result.unique();
        assert(image.width == 2);
        assert(image.height == 2);
        assert(image.channelCount == 4);
        assert(image.channelFormat == ChannelFormat.u8);
        assert(image.pixelData.length == 16);

        assert(image.pixelData[0] == 0xFF);
        assert(image.pixelData[1] == 0x00);
        assert(image.pixelData[2] == 0x00);
        assert(image.pixelData[3] == 0xFF);

        assert(image.pixelData[12] == 0xFF);
        assert(image.pixelData[13] == 0xFF);
        assert(image.pixelData[14] == 0xFF);
        assert(image.pixelData[15] == 0x80);
    });

    test("Load 3x1 grayscale direct image", {
        ubyte[22] imageData = [
            0x52, 0x47, 0x49, 0x20,
            0x01, 0x00,
            0x00,
            0x00,
            0x00,

            0x03, 0x00, 0x00, 0x00, // Width  (3)
            0x01, 0x00, 0x00, 0x00, // Height (1)
            0x01, // Channels (1)
            0x00, // Format (u8)

            0x10, 0x80, 0xF0,
        ];

        auto result = loadImage(imageData);
        assert(result.isSuccessful());

        auto image = result.unique();
        assert(image.width == 3);
        assert(image.height == 1);
        assert(image.channelCount == 1);
        assert(image.pixelData.length == 3);
        assert(image.pixelData[0] == 0x10);
        assert(image.pixelData[1] == 0x80);
        assert(image.pixelData[2] == 0xF0);
    });

    test("Load 2x1 RGB direct image with u16 channels", {
        // Two pixels, three channels each, each channel two bytes (LE).
        ubyte[31] imageData = [
            0x52, 0x47, 0x49, 0x20,
            0x01, 0x00,
            0x00,
            0x00,
            0x00,

            0x02, 0x00, 0x00, 0x00, // Width  (2)
            0x01, 0x00, 0x00, 0x00, // Height (1)
            0x03, // Channels (3 - RGB)
            0x01, // Channel format (u16)

            // Pixel (0, 0)
            0x00, 0x01, // R = 0x0100
            0x00, 0x02, // G = 0x0200
            0x00, 0x03, // B = 0x0300
            // Pixel (1, 0)
            0x00, 0x04, // R = 0x0400
            0x00, 0x05, // G = 0x0500
            0x00, 0x06, // B = 0x0600
        ];

        auto result = loadImage(imageData);
        assert(result.isSuccessful());

        auto image = result.unique();
        assert(image.width == 2);
        assert(image.height == 1);
        assert(image.channelCount == 3);
        assert(image.channelFormat == ChannelFormat.u16);
        assert(image.pixelData.length == 12);

        // Bytes are stored as-is from the file (little-endian per the spec).
        assert(image.pixelData[0] == 0x00 && image.pixelData[1] == 0x01);
        assert(image.pixelData[2] == 0x00 && image.pixelData[3] == 0x02);
        assert(image.pixelData[4] == 0x00 && image.pixelData[5] == 0x03);
        assert(image.pixelData[6] == 0x00 && image.pixelData[7] == 0x04);
        assert(image.pixelData[8] == 0x00 && image.pixelData[9] == 0x05);
        assert(image.pixelData[10] == 0x00 && image.pixelData[11] == 0x06);
    });

    test("Load 1x1 RGBA direct image with u32 channels", {
        // One pixel, four channels, each channel four bytes (LE).
        ubyte[35] imageData = [
            0x52, 0x47, 0x49, 0x20,
            0x01, 0x00,
            0x00,
            0x00,
            0x00,

            0x01, 0x00, 0x00, 0x00, // Width  (1)
            0x01, 0x00, 0x00, 0x00, // Height (1)
            0x04, // Channels (4 - RGBA)
            0x02, // Channel format (u32)

            0x78, 0x56, 0x34, 0x12, // R = 0x12345678
            0x21, 0x43, 0x65, 0x87, // G = 0x87654321
            0xAA, 0xBB, 0xCC, 0xDD, // B = 0xDDCCBBAA
            0xFF, 0xFF, 0xFF, 0xFF, // A = 0xFFFFFFFF
        ];

        auto result = loadImage(imageData);
        assert(result.isSuccessful());

        auto image = result.unique();
        assert(image.width == 1);
        assert(image.height == 1);
        assert(image.channelCount == 4);
        assert(image.channelFormat == ChannelFormat.u32);
        assert(image.pixelData.length == 16);

        assert(image.pixelData[0] == 0x78 && image.pixelData[1] == 0x56
            && image.pixelData[2] == 0x34 && image.pixelData[3] == 0x12);
        assert(image.pixelData[4] == 0x21 && image.pixelData[5] == 0x43
            && image.pixelData[6] == 0x65 && image.pixelData[7] == 0x87);
        assert(image.pixelData[8] == 0xAA && image.pixelData[9] == 0xBB
            && image.pixelData[10] == 0xCC && image.pixelData[11] == 0xDD);
        assert(image.pixelData[12] == 0xFF && image.pixelData[13] == 0xFF
            && image.pixelData[14] == 0xFF && image.pixelData[15] == 0xFF);
    });

    test("Load 2x2 indexed RGB image with u8 indices", {
        // 4 vivid palette entries, 4 pixels each picking one entry.
        ubyte[39] imageData = [
            // File header
            0x52, 0x47, 0x49, 0x20,
            0x01, 0x00,
            0x00, // Compression (None)
            0x01, // ColorMode (Indexed)
            0x00, // IndexFormat (u8)

            // Image header
            0x02, 0x00, 0x00, 0x00, // Width  (2)
            0x02, 0x00, 0x00, 0x00, // Height (2)
            0x03, // Channels (3 - RGB)
            0x00, // Format (u8)

            // Palette section
            0x04, 0x00, 0x00, 0x00, // Palette entry count (4)
            // Entry 0: red
            0xFF, 0x00, 0x00,
            // Entry 1: green
            0x00, 0xFF, 0x00,
            // Entry 2: blue
            0x00, 0x00, 0xFF,
            // Entry 3: white
            0xFF, 0xFF, 0xFF,

            // Pixel indices: red, green, blue, white
            0x00, 0x01, 0x02, 0x03,
        ];

        auto result = loadImage(imageData);
        assert(result.isSuccessful());

        auto image = result.unique();
        assert(image.width == 2);
        assert(image.height == 2);
        assert(image.channelCount == 3);
        assert(image.pixelData.length == 12);

        // Pre-expanded into direct samples.
        assert(image.pixelData[0] == 0xFF && image.pixelData[1] == 0x00 && image.pixelData[2] == 0x00);
        assert(image.pixelData[3] == 0x00 && image.pixelData[4] == 0xFF && image.pixelData[5] == 0x00);
        assert(image.pixelData[6] == 0x00 && image.pixelData[7] == 0x00 && image.pixelData[8] == 0xFF);
        assert(image.pixelData[9] == 0xFF && image.pixelData[10] == 0xFF && image.pixelData[11] == 0xFF);
    });

    test("Load 1x3 indexed RGBA image with u16 indices", {
        // Two palette entries, three pixels: index 1, 0, 1.
        ubyte[37] imageData = [
            0x52, 0x47, 0x49, 0x20,
            0x01, 0x00,
            0x00,
            0x01, // ColorMode (Indexed)
            0x01, // IndexFormat (u16)

            0x01, 0x00, 0x00, 0x00, // Width  (1)
            0x03, 0x00, 0x00, 0x00, // Height (3)
            0x04, // Channels (4 - RGBA)
            0x00, // Format (u8)

            0x02, 0x00, 0x00, 0x00, // Palette entry count (2)
            0x10, 0x20, 0x30, 0x40, // Entry 0
            0x50, 0x60, 0x70, 0x80, // Entry 1

            0x01, 0x00, // Pixel 0 -> entry 1
            0x00, 0x00, // Pixel 1 -> entry 0
            0x01, 0x00, // Pixel 2 -> entry 1
        ];

        auto result = loadImage(imageData);
        assert(result.isSuccessful());

        auto image = result.unique();
        assert(image.width == 1);
        assert(image.height == 3);
        assert(image.channelCount == 4);
        assert(image.pixelData.length == 12);

        assert(image.pixelData[0] == 0x50 && image.pixelData[1] == 0x60
            && image.pixelData[2] == 0x70 && image.pixelData[3] == 0x80);
        assert(image.pixelData[4] == 0x10 && image.pixelData[5] == 0x20
            && image.pixelData[6] == 0x30 && image.pixelData[7] == 0x40);
        assert(image.pixelData[8] == 0x50 && image.pixelData[9] == 0x60
            && image.pixelData[10] == 0x70 && image.pixelData[11] == 0x80);
    });

    test("Load 2x1 indexed RGB image with u32 indices", {
        // Two palette entries, two pixels: index 1, 0.
        ubyte[37] imageData = [
            0x52, 0x47, 0x49, 0x20,
            0x01, 0x00,
            0x00,
            0x01, // ColorMode (Indexed)
            0x02, // IndexFormat (u32)

            0x02, 0x00, 0x00, 0x00, // Width  (2)
            0x01, 0x00, 0x00, 0x00, // Height (1)
            0x03, // Channels (3 - RGB)
            0x00, // Format (u8)

            0x02, 0x00, 0x00, 0x00, // Palette entry count (2)
            0xAA, 0xBB, 0xCC,       // Entry 0
            0x11, 0x22, 0x33,       // Entry 1

            0x01, 0x00, 0x00, 0x00, // Pixel 0 -> entry 1
            0x00, 0x00, 0x00, 0x00, // Pixel 1 -> entry 0
        ];

        auto result = loadImage(imageData);
        assert(result.isSuccessful());

        auto image = result.unique();
        assert(image.width == 2);
        assert(image.height == 1);
        assert(image.channelCount == 3);
        assert(image.pixelData.length == 6);

        assert(image.pixelData[0] == 0x11 && image.pixelData[1] == 0x22 && image.pixelData[2] == 0x33);
        assert(image.pixelData[3] == 0xAA && image.pixelData[4] == 0xBB && image.pixelData[5] == 0xCC);
    });

    test("Reject buffer too short for header", {
        ubyte[3] tooShort = [0x52, 0x47, 0x49];
        auto result = loadImage(tooShort);
        assert(!result.isSuccessful());
    });

    test("Reject wrong magic number", {
        ubyte[19] imageData = [
            0x42, 0x41, 0x44, 0x21, // Bad magic
            0x01, 0x00,
            0x00, 0x00, 0x00,
            0x01, 0x00, 0x00, 0x00,
            0x01, 0x00, 0x00, 0x00,
            0x01,
            0x00,
        ];
        auto result = loadImage(imageData);
        assert(!result.isSuccessful());
    });

    test("Reject unsupported version", {
        ubyte[19] imageData = [
            0x52, 0x47, 0x49, 0x20,
            0x02, 0x00, // Version 2 (unsupported)
            0x00, 0x00, 0x00,
            0x01, 0x00, 0x00, 0x00,
            0x01, 0x00, 0x00, 0x00,
            0x01,
            0x00,
        ];
        auto result = loadImage(imageData);
        assert(!result.isSuccessful());
    });

    test("Reject unsupported compression type", {
        ubyte[19] imageData = [
            0x52, 0x47, 0x49, 0x20,
            0x01, 0x00,
            0x01, // Compression 1 (unsupported)
            0x00, 0x00,
            0x01, 0x00, 0x00, 0x00,
            0x01, 0x00, 0x00, 0x00,
            0x01,
            0x00,
        ];
        auto result = loadImage(imageData);
        assert(!result.isSuccessful());
    });

    test("Reject unsupported color mode", {
        ubyte[19] imageData = [
            0x52, 0x47, 0x49, 0x20,
            0x01, 0x00,
            0x00,
            0x02, // ColorMode 2 (unsupported)
            0x00,
            0x01, 0x00, 0x00, 0x00,
            0x01, 0x00, 0x00, 0x00,
            0x01,
            0x00,
        ];
        auto result = loadImage(imageData);
        assert(!result.isSuccessful());
    });

    test("Reject non-zero index format in direct color mode", {
        ubyte[20] imageData = [
            0x52, 0x47, 0x49, 0x20,
            0x01, 0x00,
            0x00,
            0x00, // ColorMode (Direct)
            0x01, // IndexFormat must be 0 in Direct mode

            0x01, 0x00, 0x00, 0x00,
            0x01, 0x00, 0x00, 0x00,
            0x01,
            0x00,
            0x00,
        ];
        auto result = loadImage(imageData);
        assert(!result.isSuccessful());
    });

    test("Reject unsupported index format in indexed color mode", {
        ubyte[20] imageData = [
            0x52, 0x47, 0x49, 0x20,
            0x01, 0x00,
            0x00,
            0x01, // ColorMode (Indexed)
            0x05, // IndexFormat 5 (unsupported)

            0x01, 0x00, 0x00, 0x00,
            0x01, 0x00, 0x00, 0x00,
            0x01,
            0x00,
            0x00,
        ];
        auto result = loadImage(imageData);
        assert(!result.isSuccessful());
    });

    test("Reject zero width", {
        ubyte[20] imageData = [
            0x52, 0x47, 0x49, 0x20,
            0x01, 0x00,
            0x00, 0x00, 0x00,
            0x00, 0x00, 0x00, 0x00, // Width 0
            0x01, 0x00, 0x00, 0x00,
            0x01,
            0x00,
            0x00,
        ];
        auto result = loadImage(imageData);
        assert(!result.isSuccessful());
    });

    test("Reject zero height", {
        ubyte[20] imageData = [
            0x52, 0x47, 0x49, 0x20,
            0x01, 0x00,
            0x00, 0x00, 0x00,
            0x01, 0x00, 0x00, 0x00,
            0x00, 0x00, 0x00, 0x00, // Height 0
            0x01,
            0x00,
            0x00,
        ];
        auto result = loadImage(imageData);
        assert(!result.isSuccessful());
    });

    test("Reject invalid channel count", {
        ubyte[24] imageData = [
            0x52, 0x47, 0x49, 0x20,
            0x01, 0x00,
            0x00, 0x00, 0x00,
            0x01, 0x00, 0x00, 0x00,
            0x01, 0x00, 0x00, 0x00,
            0x05, // Channels 5 (invalid)
            0x00,
            0x00, 0x00, 0x00, 0x00, 0x00,
        ];
        auto result = loadImage(imageData);
        assert(!result.isSuccessful());
    });

    test("Reject unsupported channel format", {
        ubyte[20] imageData = [
            0x52, 0x47, 0x49, 0x20,
            0x01, 0x00,
            0x00, 0x00, 0x00,
            0x01, 0x00, 0x00, 0x00,
            0x01, 0x00, 0x00, 0x00,
            0x01,
            0x05, // Format 5 (unsupported)
            0x00,
        ];
        auto result = loadImage(imageData);
        assert(!result.isSuccessful());
    });

    test("Reject truncated direct pixel data", {
        ubyte[20] imageData = [
            0x52, 0x47, 0x49, 0x20,
            0x01, 0x00,
            0x00, 0x00, 0x00,
            0x02, 0x00, 0x00, 0x00, // Width 2
            0x02, 0x00, 0x00, 0x00, // Height 2
            0x04, // Channels 4 -> needs 16 pixel bytes
            0x00,
            0x00, // Only 1 pixel byte present
        ];
        auto result = loadImage(imageData);
        assert(!result.isSuccessful());
    });

    test("Reject zero palette entry count", {
        ubyte[24] imageData = [
            0x52, 0x47, 0x49, 0x20,
            0x01, 0x00,
            0x00,
            0x01, // Indexed
            0x00, // u8 indices

            0x01, 0x00, 0x00, 0x00,
            0x01, 0x00, 0x00, 0x00,
            0x03,
            0x00,

            0x00, 0x00, 0x00, 0x00, // Palette count 0 (invalid)
            0x00, // would-be index
        ];
        auto result = loadImage(imageData);
        assert(!result.isSuccessful());
    });

    test("Reject palette count exceeding index format range", {
        // u8 indices, but palette claims 257 entries.
        ubyte[24] imageData = [
            0x52, 0x47, 0x49, 0x20,
            0x01, 0x00,
            0x00,
            0x01, // Indexed
            0x00, // u8 indices

            0x01, 0x00, 0x00, 0x00,
            0x01, 0x00, 0x00, 0x00,
            0x03,
            0x00,

            0x01, 0x01, 0x00, 0x00, // Palette count 257 (> 256)
            0x00,
        ];
        auto result = loadImage(imageData);
        assert(!result.isSuccessful());
    });

    test("Reject pixel index out of palette range", {
        ubyte[31] imageData = [
            0x52, 0x47, 0x49, 0x20,
            0x01, 0x00,
            0x00,
            0x01,
            0x00,

            0x01, 0x00, 0x00, 0x00, // Width 1
            0x02, 0x00, 0x00, 0x00, // Height 2
            0x03,
            0x00,

            0x02, 0x00, 0x00, 0x00, // Palette count 2
            0xAA, 0xBB, 0xCC, // Entry 0
            0x11, 0x22, 0x33, // Entry 1

            0x00, // Pixel 0 -> entry 0 (valid)
            0x05, // Pixel 1 -> entry 5 (out of range)
        ];
        auto result = loadImage(imageData);
        assert(!result.isSuccessful());
    });

    test("Reject indexed file with truncated palette", {
        ubyte[27] imageData = [
            0x52, 0x47, 0x49, 0x20,
            0x01, 0x00,
            0x00,
            0x01,
            0x00,

            0x01, 0x00, 0x00, 0x00,
            0x01, 0x00, 0x00, 0x00,
            0x04, // 4 channels -> 4 bytes per palette entry
            0x00,

            0x02, 0x00, 0x00, 0x00, // 2 palette entries -> need 8 bytes of palette
            0x10, 0x20, 0x30, 0x40, // Only 4 bytes provided
        ];
        auto result = loadImage(imageData);
        assert(!result.isSuccessful());
    });

    test("Reject file with unexpected trailing bytes", {
        ubyte[23] imageData = [
            0x52, 0x47, 0x49, 0x20,
            0x01, 0x00,
            0x00, 0x00, 0x00,
            0x03, 0x00, 0x00, 0x00,
            0x01, 0x00, 0x00, 0x00,
            0x01,
            0x00,
            0x10, 0x80, 0xF0,
            0xFF, // Unexpected trailing byte
        ];
        auto result = loadImage(imageData);
        assert(!result.isSuccessful());
    });
}
