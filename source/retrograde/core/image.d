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

enum ColorDepth {
    bit8,
    bit16
}

/** 
 * Generic image data.
 */
class Image {
    public uint width;
    public uint height;
    public uint channels;
    public ColorFormat colorFormat;
    public ColorDepth colorDepth;

    /** 
     * Raw image data.
     */
    public ubyte[] data;
}

/** 
 * Interface for image loaders.
 */
interface ImageLoader {
    /** 
     * Load an image from a file.
     *
     * Params:
     *  imageFile = The file to load the image from.
     *
     * Returns:
     *  The loaded image.
     */
    public Image load(File imageFile);

    /** 
     * Load an image from raw data.
     *
     * Params:
     *  data = The raw image data.
     *
     * Returns:
     *  The loaded image.
     */
    public Image load(const ubyte[] data);
}
