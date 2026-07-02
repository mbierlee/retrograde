/**
 * rgimageconv - JPEG image decoder.
 *
 * Thin adapter over the imageformats library's JPEG reader (baseline and
 * progressive). Decoded pixels are in RGI canonical layout: top-left
 * origin, gray or RGB channel order, tightly packed. JPEG has no alpha.
 *
 * Authors:
 *  Mike Bierlee, m.bierlee@lostmoment.com
 * Copyright: 2014-2026 Mike Bierlee
 * License:
 *  This software is licensed under the terms of the MIT license.
 *  The full terms of the license can be found in the LICENSE.txt file.
 */

module decoders.jpeg;

import imageformats : read_jpeg_from_mem;

import decoder : DecodeResult, DecoderEntry;
import decoders.adapter : decodeWith;

immutable DecoderEntry jpegDecoder = {
    name: "JPEG",
    extensions: [".jpg", ".jpeg"],
    sniff: &sniffJpeg,
    decode: &decodeJpeg,
};

private bool sniffJpeg(const(ubyte)[] bytes) {
    // A JPEG stream opens with the SOI marker (FF D8) immediately followed
    // by another marker (FF ..).
    return bytes.length >= 3 && bytes[0] == 0xFF && bytes[1] == 0xD8 && bytes[2] == 0xFF;
}

private DecodeResult decodeJpeg(const(ubyte)[] bytes) {
    return decodeWith(&read_jpeg_from_mem, "JPEG", bytes);
}
