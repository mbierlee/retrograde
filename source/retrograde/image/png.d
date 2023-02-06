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

import retrograde.core.image : Image, ImageLoader, ColorFormat;
import retrograde.core.storage : File;

import imageformats : IFImage, read_image_from_mem, ColFmt;

/** 
 * Loads PNG image data.
 */
class PngImageLoader : ImageLoader {
    public Image load(File imageFile, ColorFormat colorFormat = ColorFormat.rgba) {
        auto imageData = read_image_from_mem(imageFile.data, convertColorFormat(colorFormat));
        auto image = new Image();
        image.width = imageData.w;
        image.height = imageData.h;
        image.channels = imageData.c;
        image.data = imageData.pixels;
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
