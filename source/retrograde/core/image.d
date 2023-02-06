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

module retrograde.core.image;

import retrograde.core.storage : File;

enum ColorFormat {
    grayscale,
    grayscaleAlpha,
    rgb,
    rgba
}

/** 
 * Generic image data.
 */
class Image {
    public uint width;
    public uint height;
    public uint channels;

    /** 
     * Raw image data.
     */
    public ubyte[] data;
}

/** 
 * Base interface for image loaders.
 */
interface ImageLoader {
    public Image load(File imageFile, ColorFormat colorFormat);
}
