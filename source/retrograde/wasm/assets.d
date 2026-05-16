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

module retrograde.wasm.assets;

version (WebAssembly)  :  //

import retrograde.std.string : String;
import retrograde.std.assets : assetFetchComplete, assetFetchError;

extern (C) void startAssetFetch(char* url, size_t urlLen, uint handle);

void fetchPlatformAssetAsync(uint handle, String url) {
    startAssetFetch(cast(char*) url.dataPtr, url.length, handle);
}

export extern (C) void onAssetFetchComplete(uint handle, ubyte* dataPtr, size_t dataLen) {
    assetFetchComplete(handle, dataPtr[0 .. dataLen]);
}

export extern (C) void onAssetFetchError(uint handle, char* errPtr, size_t errLen) {
    assetFetchError(handle, String(cast(string) errPtr[0 .. errLen]));
}
