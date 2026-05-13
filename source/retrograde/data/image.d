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

module retrograde.data.image;

import retrograde.std.collections : Array;
import retrograde.std.stringid : StringId, sid;
import retrograde.std.dlang : CopyConstructors;
import retrograde.std.endian : toPlatformEndian, Endian;

enum ImageComponentType = sid("comp_image");

/**
 * Per-channel storage format. Multi-byte samples are stored in `pixelData`
 * in little-endian byte order, the same order they appear in on disk.
 * Use `samplesAsU16` / `samplesAsU32` to obtain a typed, platform-endian
 * sample array from an image.
 *
 * Reserved IDs cover future formats (e.g. f16, f32).
 */
enum ChannelFormat : ubyte {
    u8 = 0,
    u16 = 1,
    u32 = 2,
}

/**
 * Returns the size in bytes of a single channel sample for the given format.
 */
size_t bytesPerChannel(ChannelFormat fmt) {
    final switch (fmt) {
    case ChannelFormat.u8:
        return 1;
    case ChannelFormat.u16:
        return 2;
    case ChannelFormat.u32:
        return 4;
    }
}

/**
 * A single raster image, ready for direct use by the renderer.
 *
 * Pixel data is tightly packed, row-major, with a top-left origin
 * (row 0 is the top of the image). For RGBA images the channel order
 * within each pixel is R, G, B, A.
 *
 * Channel count semantics (matching PNG / glTF conventions):
 *   1 = grayscale, 2 = grayscale + alpha, 3 = RGB, 4 = RGBA.
 *
 * The semantic role of the image (albedo, normal map, depth map, PBR mask, ...)
 * is decided by the consumer, not by this struct.
 *
 * File-format encoding details (palette/indexed mode, on-disk compression)
 * are resolved by the loader before this struct is populated, so consumers
 * can always treat `pixelData` as direct samples.
 */
struct Image {
    StringId name;
    uint width;
    uint height;
    ubyte channelCount;
    ChannelFormat channelFormat = ChannelFormat.u8;
    Array!ubyte pixelData;

    mixin CopyConstructors!Image;
}

/**
 * Returns a copy of the image's pixel data interpreted as `T`-typed
 * samples, where `T` is `ushort` (matching `ChannelFormat.u16`) or `uint`
 * (matching `ChannelFormat.u32`). The image's channel format must match
 * `T`; passing a mismatched image trips an assert in debug builds and
 * returns an empty `Array!T` in release builds (where the assert may be
 * compiled away), so the caller never sees garbage samples.
 *
 * Each `T.sizeof`-byte group in `pixelData` is read in little-endian order
 * (the format's on-disk byte order) and converted to a platform-endian `T`,
 * so the returned array is ready to use regardless of host endianness.
 *
 * The public entry points are the aliases `samplesAsU16` and `samplesAsU32`
 * just below.
 */
Array!T samplesAs(T)(const ref Image image) if (is(T == ushort) || is(T == uint)) {
    static if (is(T == ushort)) {
        enum ChannelFormat expectedFormat = ChannelFormat.u16;
    } else {
        enum ChannelFormat expectedFormat = ChannelFormat.u32;
    }

    Array!T samples;
    assert(image.channelFormat == expectedFormat);
    if (image.channelFormat != expectedFormat) {
        return samples;
    }

    size_t sampleCount = image.pixelData.length / T.sizeof;
    samples.capacity = sampleCount;
    for (size_t i = 0; i < sampleCount; i++) {
        ubyte[T.sizeof] bytes;
        for (size_t b = 0; b < T.sizeof; b++) {
            bytes[b] = image.pixelData[i * T.sizeof + b];
        }
        samples ~= toPlatformEndian!T(bytes, Endian.little);
    }

    return samples;
}

alias samplesAsU16 = samplesAs!ushort;
alias samplesAsU32 = samplesAs!uint;

private T readSampleLE(T)(const ref Array!ubyte data, size_t index)
        if (is(T == ubyte) || is(T == ushort) || is(T == uint)) {
    static if (is(T == ubyte)) {
        return data[index];
    } else {
        ubyte[T.sizeof] bytes;
        for (size_t b = 0; b < T.sizeof; b++) {
            bytes[b] = data[index * T.sizeof + b];
        }
        return toPlatformEndian!T(bytes, Endian.little);
    }
}

private void appendSampleLE(T)(ref Array!ubyte dest, T value)
        if (is(T == ubyte) || is(T == ushort) || is(T == uint)) {
    static if (is(T == ubyte)) {
        dest ~= value;
    } else {
        for (size_t b = 0; b < T.sizeof; b++) {
            dest ~= cast(ubyte)((value >> (b * 8)) & 0xFF);
        }
    }
}

private T upsampleSample(S, T)(S value)
        if ((is(S == ubyte) || is(S == ushort) || is(S == uint))
        && (is(T == ubyte) || is(T == ushort) || is(T == uint))
        && S.sizeof <= T.sizeof) {
    static if (is(S == T)) {
        return value;
    } else static if (is(S == ubyte) && is(T == ushort)) {
        return cast(ushort)((value << 8) | value);
    } else static if (is(S == ubyte) && is(T == uint)) {
        uint x = value;
        return (x << 24) | (x << 16) | (x << 8) | x;
    } else static if (is(S == ushort) && is(T == uint)) {
        uint x = value;
        return (x << 16) | x;
    }
}

/**
 * Returns a new `Image` with channel format `T`, upsampling the source's
 * pixel data sample-by-sample where needed. `T` is `ubyte` (mapping to
 * `ChannelFormat.u8`), `ushort` (`u16`), or `uint` (`u32`). Other metadata
 * (name, width, height, channel count) is copied as-is. The source image
 * is not modified.
 *
 * Downsampling is not allowed because it loses information. If the
 * source's channel format is wider than `T`, the function trips an assert
 * in debug builds and returns an `Image` with empty `pixelData` (metadata
 * still populated) in release builds, so the caller never sees garbage.
 *
 * Sample values are upsampled by bit replication: a `ubyte` `0xAB`
 * becomes the `ushort` `0xABAB` and the `uint` `0xABABABAB`. This
 * preserves zero and full-scale values exactly across the conversion.
 *
 * The public entry points are the aliases `convertToU8`, `convertToU16`,
 * and `convertToU32` just below.
 */
Image convertTo(T)(const ref Image source)
        if (is(T == ubyte) || is(T == ushort) || is(T == uint)) {
    static if (is(T == ubyte)) {
        enum ChannelFormat targetFormat = ChannelFormat.u8;
    } else static if (is(T == ushort)) {
        enum ChannelFormat targetFormat = ChannelFormat.u16;
    } else {
        enum ChannelFormat targetFormat = ChannelFormat.u32;
    }

    Image result;
    result.name = source.name;
    result.width = source.width;
    result.height = source.height;
    result.channelCount = source.channelCount;
    result.channelFormat = targetFormat;

    assert(bytesPerChannel(source.channelFormat) <= T.sizeof);
    if (bytesPerChannel(source.channelFormat) > T.sizeof) {
        return result;
    }

    size_t srcBytes = bytesPerChannel(source.channelFormat);
    size_t totalSamples = source.pixelData.length / srcBytes;
    result.pixelData.capacity = totalSamples * T.sizeof;

    final switch (source.channelFormat) {
    case ChannelFormat.u8:
        for (size_t i = 0; i < totalSamples; i++) {
            T sample = upsampleSample!(ubyte, T)(source.pixelData[i]);
            appendSampleLE!T(result.pixelData, sample);
        }

        break;
    case ChannelFormat.u16:
        static if (T.sizeof >= ushort.sizeof) {
            for (size_t i = 0; i < totalSamples; i++) {
                ushort src = readSampleLE!ushort(source.pixelData, i);
                T sample = upsampleSample!(ushort, T)(src);
                appendSampleLE!T(result.pixelData, sample);
            }
        }

        break;
    case ChannelFormat.u32:
        static if (T.sizeof >= uint.sizeof) {
            for (size_t i = 0; i < totalSamples; i++) {
                uint src = readSampleLE!uint(source.pixelData, i);
                appendSampleLE!T(result.pixelData, src);
            }
        }

        break;
    }

    return result;
}

alias convertToU8 = convertTo!ubyte;
alias convertToU16 = convertTo!ushort;
alias convertToU32 = convertTo!uint;

version (UnitTesting)  :  ///

void runImageTests() {
    import retrograde.std.test : test, writeSection;

    writeSection("-- Image tests --");

    test("samplesAsU16 reads little-endian byte pairs as ushort", {
        Image image;
        image.channelFormat = ChannelFormat.u16;
        image.pixelData ~= cast(ubyte) 0x34;
        image.pixelData ~= cast(ubyte) 0x12;
        image.pixelData ~= cast(ubyte) 0x78;
        image.pixelData ~= cast(ubyte) 0x56;

        Array!ushort samples = samplesAsU16(image);
        assert(samples.length == 2);
        assert(samples[0] == 0x1234);
        assert(samples[1] == 0x5678);
    });

    test("samplesAsU32 reads little-endian byte quads as uint", {
        Image image;
        image.channelFormat = ChannelFormat.u32;
        image.pixelData ~= cast(ubyte) 0x78;
        image.pixelData ~= cast(ubyte) 0x56;
        image.pixelData ~= cast(ubyte) 0x34;
        image.pixelData ~= cast(ubyte) 0x12;
        image.pixelData ~= cast(ubyte) 0x21;
        image.pixelData ~= cast(ubyte) 0x43;
        image.pixelData ~= cast(ubyte) 0x65;
        image.pixelData ~= cast(ubyte) 0x87;

        Array!uint samples = samplesAsU32(image);
        assert(samples.length == 2);
        assert(samples[0] == 0x12345678);
        assert(samples[1] == 0x87654321);
    });

    test("convertToU16 upsamples u8 source by bit replication", {
        Image src;
        src.width = 2;
        src.height = 1;
        src.channelCount = 1;
        src.channelFormat = ChannelFormat.u8;
        src.pixelData ~= cast(ubyte) 0xAB;
        src.pixelData ~= cast(ubyte) 0xFF;

        Image dst = convertToU16(src);

        assert(dst.width == 2);
        assert(dst.height == 1);
        assert(dst.channelCount == 1);
        assert(dst.channelFormat == ChannelFormat.u16);
        assert(dst.pixelData.length == 4);

        // 0xAB -> 0xABAB, LE bytes [0xAB, 0xAB].
        assert(dst.pixelData[0] == 0xAB);
        assert(dst.pixelData[1] == 0xAB);
        // 0xFF -> 0xFFFF, full-scale preserved.
        assert(dst.pixelData[2] == 0xFF);
        assert(dst.pixelData[3] == 0xFF);
    });

    test("convertToU32 upsamples u8 source by 4x bit replication", {
        Image src;
        src.width = 1;
        src.height = 1;
        src.channelCount = 1;
        src.channelFormat = ChannelFormat.u8;
        src.pixelData ~= cast(ubyte) 0xAB;

        Image dst = convertToU32(src);

        assert(dst.channelFormat == ChannelFormat.u32);
        assert(dst.pixelData.length == 4);
        // 0xAB -> 0xABABABAB, LE bytes all 0xAB.
        assert(dst.pixelData[0] == 0xAB);
        assert(dst.pixelData[1] == 0xAB);
        assert(dst.pixelData[2] == 0xAB);
        assert(dst.pixelData[3] == 0xAB);
    });

    test("convertToU32 upsamples u16 source by 16-bit replication", {
        Image src;
        src.width = 1;
        src.height = 1;
        src.channelCount = 1;
        src.channelFormat = ChannelFormat.u16;
        // Source u16 = 0xABCD, stored LE as [0xCD, 0xAB].
        src.pixelData ~= cast(ubyte) 0xCD;
        src.pixelData ~= cast(ubyte) 0xAB;

        Image dst = convertToU32(src);

        assert(dst.channelFormat == ChannelFormat.u32);
        assert(dst.pixelData.length == 4);
        // 0xABCD -> 0xABCDABCD, LE bytes [0xCD, 0xAB, 0xCD, 0xAB].
        assert(dst.pixelData[0] == 0xCD);
        assert(dst.pixelData[1] == 0xAB);
        assert(dst.pixelData[2] == 0xCD);
        assert(dst.pixelData[3] == 0xAB);
    });

    test("convertToU8 with u8 source is an identity copy", {
        Image src;
        src.width = 2;
        src.height = 1;
        src.channelCount = 1;
        src.channelFormat = ChannelFormat.u8;
        src.pixelData ~= cast(ubyte) 0x10;
        src.pixelData ~= cast(ubyte) 0x20;

        Image dst = convertToU8(src);

        assert(dst.channelFormat == ChannelFormat.u8);
        assert(dst.pixelData.length == 2);
        assert(dst.pixelData[0] == 0x10);
        assert(dst.pixelData[1] == 0x20);
    });

    test("convertTo does not modify the source image", {
        Image src;
        src.width = 1;
        src.height = 1;
        src.channelCount = 1;
        src.channelFormat = ChannelFormat.u8;
        src.pixelData ~= cast(ubyte) 0x77;

        Image dst = convertToU16(src);

        assert(src.channelFormat == ChannelFormat.u8);
        assert(src.pixelData.length == 1);
        assert(src.pixelData[0] == 0x77);
        assert(dst.channelFormat == ChannelFormat.u16);
        assert(dst.pixelData.length == 2);
    });
}
