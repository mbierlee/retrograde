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

import imageformats : IFImage, read_image_from_mem, ColFmt;
import imageformats.png : read_png_from_mem, read_png16_from_mem;

/** 
 * Loads PNG image data.
 */
class PngImageLoader : ImageLoader {
    public Image load(
        File imageFile,
        ColorFormat colorFormat = ColorFormat.rgba,
        ColorDepth colorDepth = ColorDepth.bit8
    ) {
        switch (colorDepth) {
        case ColorDepth.bit16:
            return load16BitImage(imageFile, colorFormat);
        default:
            return load8BitImage(imageFile, colorFormat);
        }
    }

    private Image load8BitImage(File imageFile, ColorFormat colorFormat = ColorFormat.rgba) {
        auto image = new Image();
        auto imageData = read_png_from_mem(imageFile.data, convertColorFormat(colorFormat));
        image.width = imageData.w;
        image.height = imageData.h;
        image.channels = imageData.c;
        image.data = imageData.pixels;
        image.colorFormat = colorFormat;
        image.colorDepth = ColorDepth.bit8;
        return image;
    }

    private Image load16BitImage(File imageFile, ColorFormat colorFormat = ColorFormat.rgba) {
        auto image = new Image();
        auto imageData = read_png16_from_mem(imageFile.data, convertColorFormat(colorFormat));
        image.width = imageData.w;
        image.height = imageData.h;
        image.channels = imageData.c;
        image.colorFormat = colorFormat;
        image.colorDepth = ColorDepth.bit16;
        foreach (ushort pixel; imageData.pixels) {
            image.data ~= cast(ubyte) pixel & 0x00FF;
            image.data ~= cast(ubyte)((pixel & 0xFF00) >> 8);
        }

        return image;
    }

    private ColFmt convertColorFormat(ColorFormat colorFormat) {
        switch (colorFormat) {
        case ColorFormat.grayscale:
            return ColFmt.Y;
        case ColorFormat.grayscaleAlpha:
            return ColFmt.YA;
        case ColorFormat.rgb:
            return ColFmt.RGB;
        default:
            return ColFmt.RGBA;
        }
    }
}
