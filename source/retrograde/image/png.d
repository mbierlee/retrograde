/**
 * Retrograde Engine
 *
 * Authors:
 *  Mike Bierlee, m.bierlee@lostmoment.com
 * Copyright: 2014-2023 Mike Bierlee
 * License:
 *  This software is licensed under the terms of the MIT license.
 *  The full terms of the license can be found in the LICENSE.txt file.
 */

module retrograde.image.png;

import retrograde.core.image : Image, ImageLoader, ColorFormat, ColorDepth;
import retrograde.core.storage : File;

import imageformats : ColFmt;
import imageformats.png : PNG_Header, read_png_header_from_mem, read_png_from_mem, read_png16_from_mem,
    read_png_info_from_mem;

/** 
 * Loads PNG image data.
 */
class PngImageLoader : ImageLoader {
    public Image load(File imageFile) {
        PNG_Header header = read_png_header_from_mem(imageFile.data);
        int channels, irrelevant;
        read_png_info_from_mem(imageFile.data, irrelevant, irrelevant, channels);

        if (header.bit_depth == 8) {
            return load8BitImage(imageFile, channels);
        } else if (header.bit_depth == 16) {
            return load16BitImage(imageFile, channels);
        } else {
            throw new Exception("Unsupported PNG image color bit depth: " ~ header.bit_depth);
        }
    }

    private Image load8BitImage(const File imageFile, const int channels) {
        auto image = new Image();
        auto imageData = read_png_from_mem(imageFile.data, channels);
        image.width = imageData.w;
        image.height = imageData.h;
        image.channels = imageData.c;
        image.data = imageData.pixels;
        image.colorFormat = getColorFormat(channels);
        image.colorDepth = ColorDepth.bit8;
        return image;
    }

    private Image load16BitImage(const File imageFile, const int channels) {
        auto image = new Image();
        auto imageData = read_png16_from_mem(imageFile.data, channels);
        image.width = imageData.w;
        image.height = imageData.h;
        image.channels = imageData.c;
        image.colorFormat = getColorFormat(channels);
        image.colorDepth = ColorDepth.bit16;
        foreach (ushort pixel; imageData.pixels) {
            image.data ~= cast(ubyte) pixel & 0x00FF;
            image.data ~= cast(ubyte)((pixel & 0xFF00) >> 8);
        }

        return image;
    }

    private ColorFormat getColorFormat(const int channels) {
        switch (channels) {
        case 1:
            return ColorFormat.grayscale;
        case 2:
            return ColorFormat.grayscaleAlpha;
        case 3:
            return ColorFormat.rgb;
        case 4:
            return ColorFormat.rgba;
        default:
            return ColorFormat.rgba;
        }
    }
}
