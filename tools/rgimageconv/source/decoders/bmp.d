/**
 * rgimageconv - BMP image decoder.
 *
 * Thin adapter over the imageformats library's BMP reader. imageformats
 * decodes uncompressed and bitfield BMPs (24/32-bit truecolor as well as
 * 8-bit paletted) and returns pixels in RGI canonical layout: top-left
 * origin, RGB(A) channel order, tightly packed.
 *
 * Authors:
 *  Mike Bierlee, m.bierlee@lostmoment.com
 * Copyright: 2014-2026 Mike Bierlee
 * License:
 *  This software is licensed under the terms of the MIT license.
 *  The full terms of the license can be found in the LICENSE.txt file.
 */

module decoders.bmp;

import imageformats : read_bmp_from_mem;

import decoder : DecodeResult, DecoderEntry;
import decoders.adapter : decodeWith;

immutable DecoderEntry bmpDecoder = {
    name: "BMP",
    extensions: [".bmp"],
    sniff: &sniffBmp,
    decode: &decodeBmp,
};

private bool sniffBmp(const(ubyte)[] bytes) {
    return bytes.length >= 2 && bytes[0] == 'B' && bytes[1] == 'M';
}

private DecodeResult decodeBmp(const(ubyte)[] bytes) {
    return decodeWith(&read_bmp_from_mem, "BMP", bytes);
}
