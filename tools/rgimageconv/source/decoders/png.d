/**
 * rgimageconv - PNG image decoder.
 *
 * Thin adapter over the imageformats library's PNG reader. Decoded pixels
 * are in RGI canonical layout: top-left origin, gray / gray+alpha / RGB /
 * RGBA channel order, tightly packed.
 *
 * Authors:
 *  Mike Bierlee, m.bierlee@lostmoment.com
 * Copyright: 2014-2026 Mike Bierlee
 * License:
 *  This software is licensed under the terms of the MIT license.
 *  The full terms of the license can be found in the LICENSE.txt file.
 */

module decoders.png;

import imageformats : read_png_from_mem;

import decoder : DecodeResult, DecoderEntry;
import decoders.adapter : decodeWith;

immutable DecoderEntry pngDecoder = {
    name: "PNG",
    extensions: [".png"],
    sniff: &sniffPng,
    decode: &decodePng,
};

private static immutable ubyte[8] pngSignature = [0x89, 'P', 'N', 'G', 0x0D, 0x0A, 0x1A, 0x0A];

private bool sniffPng(const(ubyte)[] bytes) {
    return bytes.length >= pngSignature.length && bytes[0 .. pngSignature.length] == pngSignature[];
}

private DecodeResult decodePng(const(ubyte)[] bytes) {
    return decodeWith(&read_png_from_mem, "PNG", bytes);
}
