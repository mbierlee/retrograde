/**
 * Retrograde Engine
 *
 * Authors:
 *  Mike Bierlee, m.bierlee@lostmoment.com
 * Copyright: 2014-2026 Mike Bierlee
 * License:
 *  This software is licensed under the terms of the MIT license.
 *  The full terms of the license can be found in the LICENSE.txt file.
 */

module retrograde.native.assets;

version (Native)  :  //

import core.stdc.stdio : fopen, fclose, fread, fseek, ftell, SEEK_END, SEEK_SET, FILE;

import retrograde.std.memory : malloc, free;
import retrograde.std.string : String, s;
import retrograde.std.assets : assetFetchComplete, assetFetchError;

// TODO: make truely async some day
void fetchPlatformAssetAsync(uint handle, String absolutePath) {
    auto cPath = absolutePath.cString();
    FILE* file = fopen(cPath.ptr, "rb");
    if (file is null) {
        assetFetchError(handle, "Failed to open file".s);
        return;
    }
    
    scope (exit) fclose(file);

    if (fseek(file, 0, SEEK_END) != 0) {
        assetFetchError(handle, "Failed to seek to end of file".s);
        return;
    }

    auto size = ftell(file);
    if (size < 0) {
        assetFetchError(handle, "Failed to determine file size".s);
        return;
    }

    if (size == 0) {
        assetFetchError(handle, "File is empty".s);
        return;
    }

    if (fseek(file, 0, SEEK_SET) != 0) {
        assetFetchError(handle, "Failed to seek to beginning of file".s);
        return;
    }

    auto dataSize = cast(size_t) size;
    ubyte* buffer = cast(ubyte*) malloc(dataSize);
    if (buffer is null) {
        assetFetchError(handle, "Failed to allocate memory for asset".s);
        return;
    }

    scope (exit) free(buffer);

    auto bytesRead = fread(buffer, 1, dataSize, file);
    if (bytesRead != dataSize) {
        assetFetchError(handle, "Failed to read complete file".s);
        return;
    }

    assetFetchComplete(handle, buffer[0 .. dataSize]);
}
