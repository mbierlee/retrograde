/**
 * rgimageconv - Common in-memory image representation.
 *
 * Authors:
 *  Mike Bierlee, m.bierlee@lostmoment.com
 * Copyright: 2014-2026 Mike Bierlee
 * License:
 *  This software is licensed under the terms of the MIT license.
 *  The full terms of the license can be found in the LICENSE.txt file.
 */

module image;

enum PixelFormat : ubyte {
    y8,
    ya8,
    rgb8,
    rgba8,
}

struct DecodedImage {
    uint width;
    uint height;
    PixelFormat format;
    ubyte[] pixels;
}

ubyte channelCount(PixelFormat f) {
    final switch (f) {
    case PixelFormat.y8:
        return 1;
    case PixelFormat.ya8:
        return 2;
    case PixelFormat.rgb8:
        return 3;
    case PixelFormat.rgba8:
        return 4;
    }
}

ubyte bytesPerChannel(PixelFormat f) {
    final switch (f) {
    case PixelFormat.y8:
        return 1;
    case PixelFormat.ya8:
        return 1;
    case PixelFormat.rgb8:
        return 1;
    case PixelFormat.rgba8:
        return 1;
    }
}

size_t bytesPerPixel(PixelFormat f) {
    return cast(size_t) channelCount(f) * cast(size_t) bytesPerChannel(f);
}
