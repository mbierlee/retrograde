/**
 * rgimageconv - BMP image decoder.
 *
 * Supports uncompressed BI_RGB BMP files with a BITMAPINFOHEADER and a
 * bit count of 24 (BGR) or 32 (BGRA). Handles both bottom-up (positive
 * height) and top-down (negative height) row orderings. Output pixels
 * are in RGI canonical layout: top-left origin, RGB(A) channel order,
 * tightly packed.
 *
 * Authors:
 *  Mike Bierlee, m.bierlee@lostmoment.com
 * Copyright: 2014-2026 Mike Bierlee
 * License:
 *  This software is licensed under the terms of the MIT license.
 *  The full terms of the license can be found in the LICENSE.txt file.
 */

module decoders.bmp;

import std.format : format;

import decoder : DecodeResult, DecoderEntry;
import image : DecodedImage, PixelFormat;

immutable DecoderEntry bmpDecoder = {
    name: "BMP",
    extensions: [".bmp"],
    sniff: &sniffBmp,
    decode: &decodeBmp,
};

private bool sniffBmp(const(ubyte)[] bytes) {
    return bytes.length >= 2 && bytes[0] == 'B' && bytes[1] == 'M';
}

private enum size_t fileHeaderSize = 14;
private enum size_t infoHeaderSize = 40;

private DecodeResult decodeBmp(const(ubyte)[] bytes) {
    if (bytes.length < fileHeaderSize + infoHeaderSize) {
        return DecodeResult(false, "BMP: file is too short to contain headers.", DecodedImage.init);
    }

    if (bytes[0] != 'B' || bytes[1] != 'M') {
        return DecodeResult(false, "BMP: missing 'BM' magic.", DecodedImage.init);
    }

    immutable uint bfOffBits = readUint(bytes, 10);

    immutable uint biSize = readUint(bytes, 14);
    // BITMAPINFOHEADER (40), BITMAPV2INFOHEADER (52), BITMAPV3INFOHEADER (56),
    // BITMAPV4HEADER (108), BITMAPV5HEADER (124) all share the same first 40 bytes;
    // the extra fields are color-space/gamma data that we ignore for BI_RGB pixels.
    if (biSize < infoHeaderSize) {
        return DecodeResult(false,
            format("BMP: unsupported DIB header size %d (need BITMAPINFOHEADER / 40 bytes or larger).", biSize),
            DecodedImage.init);
    }
    if (bytes.length < fileHeaderSize + biSize) {
        return DecodeResult(false, "BMP: file is too short for declared DIB header size.", DecodedImage.init);
    }

    immutable int biWidth = readInt(bytes, 18);
    immutable int biHeight = readInt(bytes, 22);
    immutable ushort biPlanes = readUshort(bytes, 26);
    immutable ushort biBitCount = readUshort(bytes, 28);
    immutable uint biCompression = readUint(bytes, 30);

    if (biWidth <= 0) {
        return DecodeResult(false,
            format("BMP: invalid width %d (must be > 0).", biWidth), DecodedImage.init);
    }

    if (biHeight == 0) {
        return DecodeResult(false, "BMP: invalid height 0.", DecodedImage.init);
    }

    if (biPlanes != 1) {
        return DecodeResult(false,
            format("BMP: unsupported plane count %d (must be 1).", biPlanes), DecodedImage.init);
    }

    if (biCompression != 0) {
        return DecodeResult(false,
            format("BMP: unsupported compression %d (only uncompressed BI_RGB supported).", biCompression),
            DecodedImage.init);
    }

    if (biBitCount != 24 && biBitCount != 32) {
        return DecodeResult(false,
            format("BMP: unsupported bit count %d (only 24 and 32 supported).", biBitCount),
            DecodedImage.init);
    }

    immutable uint width = cast(uint) biWidth;
    immutable bool topDown = biHeight < 0;
    immutable uint height = cast(uint) (topDown ? -biHeight : biHeight);

    immutable size_t bytesPerSourcePixel = biBitCount / 8;
    immutable size_t rowStride = ((width * bytesPerSourcePixel) + 3) & ~3UL;
    immutable size_t pixelDataSize = rowStride * height;

    if (bfOffBits > bytes.length || bfOffBits + pixelDataSize > bytes.length) {
        return DecodeResult(false,
            "BMP: pixel data offset/size exceeds file length.", DecodedImage.init);
    }

    immutable PixelFormat outFormat = biBitCount == 24 ? PixelFormat.rgb8 : PixelFormat.rgba8;
    immutable size_t outChannels = biBitCount == 24 ? 3 : 4;

    auto outPixels = new ubyte[width * height * outChannels];

    foreach (uint y; 0 .. height) {
        immutable uint srcRow = topDown ? y : (height - 1 - y);
        immutable size_t srcRowOffset = bfOffBits + srcRow * rowStride;
        immutable size_t dstRowOffset = y * width * outChannels;

        foreach (uint x; 0 .. width) {
            immutable size_t s = srcRowOffset + x * bytesPerSourcePixel;
            immutable size_t d = dstRowOffset + x * outChannels;
            outPixels[d] = bytes[s + 2];     // R
            outPixels[d + 1] = bytes[s + 1]; // G
            outPixels[d + 2] = bytes[s];     // B
            if (biBitCount == 32) {
                outPixels[d + 3] = bytes[s + 3]; // A
            }
        }
    }

    DecodedImage image;
    image.width = width;
    image.height = height;
    image.format = outFormat;
    image.pixels = outPixels;
    return DecodeResult(true, "", image);
}

private uint readUint(const(ubyte)[] data, size_t offset) {
    return cast(uint) data[offset]
        | (cast(uint) data[offset + 1] << 8)
        | (cast(uint) data[offset + 2] << 16)
        | (cast(uint) data[offset + 3] << 24);
}

private int readInt(const(ubyte)[] data, size_t offset) {
    return cast(int) readUint(data, offset);
}

private ushort readUshort(const(ubyte)[] data, size_t offset) {
    return cast(ushort) (cast(ushort) data[offset]
        | (cast(ushort) data[offset + 1] << 8));
}
