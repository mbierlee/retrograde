/**
 * rgimageconv - Adapter from imageformats results to DecodedImage.
 *
 * Every built-in decoder is a thin wrapper over one of imageformats'
 * `read_*_from_mem` readers. This module holds the shared glue: it invokes
 * the reader, turns thrown ImageIOExceptions into DecodeResult errors, and
 * maps the returned ColFmt to the tool's PixelFormat.
 *
 * Authors:
 *  Mike Bierlee, m.bierlee@lostmoment.com
 * Copyright: 2014-2026 Mike Bierlee
 * License:
 *  This software is licensed under the terms of the MIT license.
 *  The full terms of the license can be found in the LICENSE.txt file.
 */

module decoders.adapter;

import std.format : format;

import imageformats : IFImage, ColFmt;

import decoder : DecodeResult;
import image : DecodedImage, PixelFormat;

/// Function pointer matching imageformats' `read_*_from_mem` readers.
alias ReadFromMem = IFImage function(in ubyte[] source, long req_chans);

/**
 * Decodes `bytes` with the given imageformats reader and adapts the result
 * into a DecodedImage. `tag` prefixes any error message (e.g. "PNG").
 */
DecodeResult decodeWith(ReadFromMem read, string tag, const(ubyte)[] bytes) {
    IFImage img;
    try {
        img = read(bytes, 0);
    } catch (Exception e) {
        return DecodeResult(false, tag ~ ": " ~ e.msg, DecodedImage.init);
    }

    PixelFormat outFormat;
    switch (img.c) {
    case ColFmt.Y:
        outFormat = PixelFormat.y8;
        break;
    case ColFmt.YA:
        outFormat = PixelFormat.ya8;
        break;
    case ColFmt.RGB:
        outFormat = PixelFormat.rgb8;
        break;
    case ColFmt.RGBA:
        outFormat = PixelFormat.rgba8;
        break;
    default:
        return DecodeResult(false,
            format("%s: unsupported channel count %d.", tag, cast(int) img.c),
            DecodedImage.init);
    }

    DecodedImage image;
    image.width = cast(uint) img.w;
    image.height = cast(uint) img.h;
    image.format = outFormat;
    image.pixels = img.pixels;
    return DecodeResult(true, "", image);
}
