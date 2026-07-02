/**
 * rgimageconv - Decoder registry and dispatch.
 *
 * A new image format is added by:
 *   1. Creating a module under source/decoders/ that exports an
 *      immutable DecoderEntry.
 *   2. Appending that entry to the `decoders` array below.
 *
 * Authors:
 *  Mike Bierlee, m.bierlee@lostmoment.com
 * Copyright: 2014-2026 Mike Bierlee
 * License:
 *  This software is licensed under the terms of the MIT license.
 *  The full terms of the license can be found in the LICENSE.txt file.
 */

module decoder;

import std.path : extension;
import std.uni : toLower;

import image : DecodedImage;
import decoders.bmp : bmpDecoder;
import decoders.png : pngDecoder;
import decoders.tga : tgaDecoder;
import decoders.jpeg : jpegDecoder;

struct DecodeResult {
    bool ok;
    string error;
    DecodedImage image;
}

alias SniffFn = bool function(const(ubyte)[]);
alias DecodeFn = DecodeResult function(const(ubyte)[]);

struct DecoderEntry {
    string name;
    string[] extensions;
    SniffFn sniff;
    DecodeFn decode;
}

immutable DecoderEntry[] decoders = [bmpDecoder, pngDecoder, tgaDecoder, jpegDecoder];

DecodeResult decodeImage(string path, const(ubyte)[] bytes) {
    foreach (entry; decoders) {
        if (entry.sniff !is null && entry.sniff(bytes)) {
            return entry.decode(bytes);
        }
    }

    string ext = extension(path).toLower();
    if (ext.length > 0) {
        foreach (entry; decoders) {
            foreach (e; entry.extensions) {
                if (e == ext) {
                    return entry.decode(bytes);
                }
            }
        }
    }

    return DecodeResult(false,
        "No matching decoder. Supported formats: " ~ supportedList() ~ ".",
        DecodedImage.init);
}

string supportedList() {
    string result = "";
    foreach (i, entry; decoders) {
        if (i > 0) {
            result ~= ", ";
        }
        result ~= entry.name;
    }
    return result;
}
