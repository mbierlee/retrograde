/**
 * rgimageconv - TGA (Truevision Targa) image decoder.
 *
 * Thin adapter over the imageformats library's TGA reader (raw and RLE).
 * Decoded pixels are in RGI canonical layout: top-left origin, gray /
 * gray+alpha / RGB / RGBA channel order, tightly packed.
 *
 * TGA has no reliable leading magic number: v1 files begin straight with
 * the 18-byte image header, and the v2 "TRUEVISION-XFILE" signature lives
 * only in a trailing footer. Detection is therefore left to the file
 * extension, so `sniff` is null (the decoder registry falls back to the
 * extension when no sniffer matches).
 *
 * Authors:
 *  Mike Bierlee, m.bierlee@lostmoment.com
 * Copyright: 2014-2026 Mike Bierlee
 * License:
 *  This software is licensed under the terms of the MIT license.
 *  The full terms of the license can be found in the LICENSE.txt file.
 */

module decoders.tga;

import imageformats : read_tga_from_mem;

import decoder : DecodeResult, DecoderEntry;
import decoders.adapter : decodeWith;

immutable DecoderEntry tgaDecoder = {
    name: "TGA",
    extensions: [".tga"],
    sniff: null,
    decode: &decodeTga,
};

private DecodeResult decodeTga(const(ubyte)[] bytes) {
    return decodeWith(&read_tga_from_mem, "TGA", bytes);
}
