/**
 * rgimageconv - RGI image format encoder.
 *
 * Builds an RGI file in memory from a DecodedImage. Supports direct color
 * mode, indexed color mode, and an auto mode that emits whichever encoding
 * produces the smaller file.
 *
 * Authors:
 *  Mike Bierlee, m.bierlee@lostmoment.com
 * Copyright: 2014-2026 Mike Bierlee
 * License:
 *  This software is licensed under the terms of the MIT license.
 *  The full terms of the license can be found in the LICENSE.txt file.
 */

module encoders.rgi;

import std.array : Appender, appender;
import std.bitmanip : nativeToLittleEndian;

import retrograde.assets.rgi : ColorMode, CompressionType, IndexFormat, rgiMagicNumber;
import retrograde.assets.image : ChannelFormat;

import image : DecodedImage, PixelFormat, channelCount, bytesPerPixel;

enum ushort rgiVersion = 1;

enum Mode {
    direct,
    indexed,
    auto_,
}

struct EncodeOutcome {
    Mode chosen;
    ubyte[] bytes;
    size_t directSize;
    bool directComputed;
    size_t indexedSize;
    bool indexedComputed;
    uint paletteEntries;
    IndexFormat indexFmt;
}

private ChannelFormat toRgiChannelFormat(PixelFormat f) {
    final switch (f) {
    case PixelFormat.y8:
        return ChannelFormat.u8;
    case PixelFormat.ya8:
        return ChannelFormat.u8;
    case PixelFormat.rgb8:
        return ChannelFormat.u8;
    case PixelFormat.rgba8:
        return ChannelFormat.u8;
    }
}

private IndexFormat pickIndexFormat(size_t paletteCount) {
    if (paletteCount <= 256) {
        return IndexFormat.u8;
    }
    if (paletteCount <= 65_536) {
        return IndexFormat.u16;
    }
    return IndexFormat.u32;
}

ubyte[] encodeDirect(in DecodedImage img) {
    auto buf = appender!(ubyte[])();
    writeFileHeader(buf, ColorMode.direct, IndexFormat.u8);
    writeImageHeader(buf, img);
    buf.put(img.pixels);
    return buf.data;
}

struct IndexedEncode {
    ubyte[] bytes;
    uint paletteEntries;
    IndexFormat indexFmt;
}

IndexedEncode encodeIndexed(in DecodedImage img) {
    immutable ubyte channels = channelCount(img.format);
    immutable size_t pixelBytes = bytesPerPixel(img.format);
    immutable size_t pixelCount = cast(size_t) img.width * cast(size_t) img.height;

    uint[uint] paletteIndex;
    auto paletteBytes = appender!(ubyte[])();
    auto indices = new uint[pixelCount];
    uint nextIndex = 0;

    foreach (size_t i; 0 .. pixelCount) {
        immutable size_t off = i * pixelBytes;
        immutable uint key = packPixelKey(img.pixels[off .. off + pixelBytes]);
        auto existing = key in paletteIndex;
        if (existing !is null) {
            indices[i] = *existing;
        } else {
            indices[i] = nextIndex;
            paletteIndex[key] = nextIndex;
            paletteBytes.put(img.pixels[off .. off + pixelBytes]);
            nextIndex++;
        }
    }

    immutable IndexFormat indexFmt = pickIndexFormat(nextIndex);

    auto buf = appender!(ubyte[])();
    writeFileHeader(buf, ColorMode.indexed, indexFmt);
    writeImageHeader(buf, img);

    writeUint(buf, nextIndex);
    buf.put(paletteBytes.data);

    final switch (indexFmt) {
    case IndexFormat.u8:
        foreach (uint idx; indices) {
            writeUbyte(buf, cast(ubyte) idx);
        }
        break;
    case IndexFormat.u16:
        foreach (uint idx; indices) {
            writeUshort(buf, cast(ushort) idx);
        }
        break;
    case IndexFormat.u32:
        foreach (uint idx; indices) {
            writeUint(buf, idx);
        }
        break;
    }

    IndexedEncode result;
    result.bytes = buf.data;
    result.paletteEntries = nextIndex;
    result.indexFmt = indexFmt;
    return result;
}

EncodeOutcome encodeRgi(in DecodedImage img, Mode mode) {
    EncodeOutcome outcome;

    final switch (mode) {
    case Mode.direct:
        outcome.bytes = encodeDirect(img);
        outcome.directSize = outcome.bytes.length;
        outcome.directComputed = true;
        outcome.chosen = Mode.direct;
        return outcome;

    case Mode.indexed:
        auto idx = encodeIndexed(img);
        outcome.bytes = idx.bytes;
        outcome.indexedSize = idx.bytes.length;
        outcome.indexedComputed = true;
        outcome.paletteEntries = idx.paletteEntries;
        outcome.indexFmt = idx.indexFmt;
        outcome.chosen = Mode.indexed;
        return outcome;

    case Mode.auto_:
        auto direct = encodeDirect(img);
        auto idx = encodeIndexed(img);
        outcome.directSize = direct.length;
        outcome.directComputed = true;
        outcome.indexedSize = idx.bytes.length;
        outcome.indexedComputed = true;
        outcome.paletteEntries = idx.paletteEntries;
        outcome.indexFmt = idx.indexFmt;
        if (idx.bytes.length < direct.length) {
            outcome.bytes = idx.bytes;
            outcome.chosen = Mode.indexed;
        } else {
            outcome.bytes = direct;
            outcome.chosen = Mode.direct;
        }
        return outcome;
    }
}

private uint packPixelKey(const(ubyte)[] pixel) {
    uint key = 0;
    foreach (size_t i, ubyte b; pixel) {
        key |= cast(uint) b << (i * 8);
    }
    return key;
}

private void writeFileHeader(ref Appender!(ubyte[]) buf, ColorMode colorMode, IndexFormat indexFmt) {
    buf.put(cast(const(ubyte)[]) rgiMagicNumber);
    writeUshort(buf, rgiVersion);
    writeUbyte(buf, cast(ubyte) CompressionType.none);
    writeUbyte(buf, cast(ubyte) colorMode);
    immutable ubyte indexByte = colorMode == ColorMode.indexed ? cast(ubyte) indexFmt : 0;
    writeUbyte(buf, indexByte);
}

private void writeImageHeader(ref Appender!(ubyte[]) buf, in DecodedImage img) {
    writeUint(buf, img.width);
    writeUint(buf, img.height);
    writeUbyte(buf, channelCount(img.format));
    writeUbyte(buf, cast(ubyte) toRgiChannelFormat(img.format));
}

private void writeUint(ref Appender!(ubyte[]) buf, uint value) {
    ubyte[4] bytes = nativeToLittleEndian(value);
    buf.put(bytes[]);
}

private void writeUshort(ref Appender!(ubyte[]) buf, ushort value) {
    ubyte[2] bytes = nativeToLittleEndian(value);
    buf.put(bytes[]);
}

private void writeUbyte(ref Appender!(ubyte[]) buf, ubyte value) {
    buf.put(value);
}
