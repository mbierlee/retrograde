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

module retrograde.std.assets;

import retrograde.std.string : String, startsWith, s;
import retrograde.std.collections : HashMap, Array;
import retrograde.std.result : Result, OperationResult, success, failure;
import retrograde.std.memory : malloc, free, memcpy;

version (Native) {
    import retrograde.native.assets : fetchPlatformAssetAsync;
}

version (WebAssembly) {
    import retrograde.wasm.assets : fetchPlatformAssetAsync;
}

private enum AssetStatus {
    pending,
    ready,
    error,
}

/// A handle that identifies a fetched asset.
alias AssetHandle = uint;

private struct AssetEntry {
    AssetStatus status;
    ubyte[] data;
    String errorMessage;
    uint usageCount;

    this(ref return scope typeof(this) other) {
        this.status = other.status;
        this.data = other.data;
        this.errorMessage = other.errorMessage;
        this.usageCount = other.usageCount;
    }

    this(ref return scope const typeof(this) other) {
        this.status = other.status;
        this.data = cast(ubyte[]) other.data;
        this.errorMessage = other.errorMessage;
        this.usageCount = other.usageCount;
    }
}

private uint nextHandle = 1;
private HashMap!(String, String) mounts;
private HashMap!(String, uint) pathToHandle;
private HashMap!(uint, AssetEntry) assets;

/**
 * Mounts a real source path under a virtual asset path.
 * Assets under $(D virtualPath) will be resolved relative to $(D sourcePath).
 *
 * Params:
 *  sourcePath  = The real source path to mount (e.g. a filesystem path or URL).
 *  virtualPath = The virtual path prefix to map to $(D sourcePath).
 * Returns: A successful $(D OperationResult), or a failure if the virtual path is already mounted.
 */
OperationResult mountAssetsPath(String sourcePath, String virtualPath) {
    if (!mounts.tryAdd(virtualPath, sourcePath)) {
        return failure("Mount already exists for virtual path");
    }

    return success();
}

/// Ditto
OperationResult mountAssetsPath(string sourcePath, string virtualPath) {
    return mountAssetsPath(sourcePath.s, virtualPath.s);
}

/**
 * Initiates an asynchronous fetch for the asset at the given virtual path.
 * If the asset was already fetched, the existing handle is returned immediately.
 *
 * This function is not thread-safe.
 *
 * Params:
 *  virtualPath = The virtual path of the asset to fetch.
 * Returns: A $(D Result) containing the $(D AssetHandle) on success, or a failure
 *          if no mount matches the virtual path.
 */
Result!AssetHandle fetchAsset(String virtualPath) {
    uint existing;
    if (pathToHandle.tryGet(virtualPath, existing)) {
        return success(existing);
    }

    String resolvedPath;
    bool found = false;
    auto mountKeys = mounts.keys();
    foreach (ref key; mountKeys) {
        if (virtualPath.startsWith(key)) {
            auto src = mounts[key];
            resolvedPath = src;
            if (key.length < virtualPath.length) {
                auto remainder = virtualPath.substring(key.length);
                if (resolvedPath.length > 0 && resolvedPath[resolvedPath.length - 1] != '/') {
                    resolvedPath ~= '/';
                }

                resolvedPath ~= remainder;
            }

            found = true;
            break;
        }
    }

    if (!found) {
        return failure!AssetHandle("No mount matches virtual path");
    }

    uint handle = nextHandle++;
    AssetEntry entry;
    entry.status = AssetStatus.pending;
    entry.data = null;

    assets.put(handle, entry);
    pathToHandle.put(virtualPath, handle);

    if (!resolvedPath.startsWith("unittest://".s)) {
        fetchPlatformAssetAsync(handle, resolvedPath);
    }

    return success(handle);
}

/**
 * Returns: $(D true) if the asset identified by $(D handle) has finished loading successfully.
 */
bool isAssetReady(AssetHandle handle) {
    if (handle == 0) {
        return false;
    }

    AssetEntry entry;
    if (assets.tryGet(handle, entry)) {
        return entry.status == AssetStatus.ready;
    }

    return false;
}

/**
 * Returns: $(D true) if the asset identified by $(D handle) failed to load.
 */
bool isAssetError(AssetHandle handle) {
    if (handle == 0) {
        return false;
    }

    AssetEntry entry;
    if (assets.tryGet(handle, entry)) {
        return entry.status == AssetStatus.error;
    }

    return false;
}

/**
 * Retrieves the error message for a failed asset load.
 *
 * Params:
 *  handle = The handle of the asset in an error state.
 * Returns: A $(D Result) containing the error message string on success, or a failure
 *          if the handle is invalid or the asset is not in an error state.
 */
Result!String getAssetError(AssetHandle handle) {
    if (handle == 0) {
        return failure!String("Invalid asset handle");
    }

    AssetEntry entry;
    if (!assets.tryGet(handle, entry)) {
        return failure!String("Invalid asset handle");
    }

    if (entry.status != AssetStatus.error) {
        return failure!String("Asset is not in an error state");
    }

    return success(entry.errorMessage);
}

/**
 * Retrieves the raw data of a successfully loaded asset and increments its usage count.
 * Call $(D releaseAssetData) when the data is no longer needed.
 *
 * Params:
 *  handle = The handle of the asset to read.
 * Returns: A $(D Result) containing a slice of the asset's byte data on success, or a failure
 *          if the handle is invalid, the asset is still loading, or the asset is in an error state.
 */
Result!(const(ubyte)[]) getAssetData(AssetHandle handle) {
    if (handle == 0) {
        return failure!(const(ubyte)[])("Invalid asset handle");
    }

    AssetEntry entry;
    if (!assets.tryGet(handle, entry)) {
        return failure!(const(ubyte)[])("Invalid asset handle");
    }

    if (entry.status == AssetStatus.pending) {
        return failure!(const(ubyte)[])("Asset is still loading");
    }

    if (entry.status == AssetStatus.error) {
        return failure!(const(ubyte)[])(entry.errorMessage);
    }

    entry.usageCount++;
    assets.put(handle, entry);
    return success(cast(const(ubyte)[]) entry.data);
}

/**
 * Convenience wrapper that checks the state of an asset and dispatches to the
 * appropriate delegate.
 *
 * If the asset is ready, $(D onSuccess) is called with the asset data.
 * If the asset is in an error state, $(D onAssetError) is called with the error message.
 * If the asset is still pending, or the handle is invalid (0 or unknown), none of the delegates are called.
 *
 * Params:
 *  handle     = The asset handle to inspect.
 *  onSuccess  = Called with the asset data when the asset is ready.
 *  onError    = Called with an error message if the asset is in an error state.
 */
void withAssetData(Fn, AssetErrFn)(
    AssetHandle handle,
    scope Fn onSuccess,
    scope AssetErrFn onError
) {
    if (handle == 0) {
        return;
    }

    if (isAssetReady(handle)) {
        auto result = getAssetData(handle);
        onSuccess(result.value);
        releaseAssetData(handle);
    } else if (isAssetError(handle)) {
        auto errorResult = getAssetError(handle);
        if (errorResult.isSuccessful) {
            onError(errorResult.value);
        }
    }
}

/**
 * Directly inserts raw data as a ready asset, bypassing the async fetch mechanism.
 * The data is copied into a managed buffer. The returned handle is immediately ready
 * and can be used with $(D getAssetData) straight away.
 *
 * Params:
 *  data = The raw asset data to copy.
 * Returns: A $(D Result) containing the new $(D AssetHandle).
 */
Result!AssetHandle addAssetData(const(ubyte)[] data) {
    uint handle = nextHandle++;
    AssetEntry entry;
    entry.data = (cast(ubyte*) malloc(data.length))[0 .. data.length];
    memcpy(cast(void*) entry.data.ptr, cast(void*) data.ptr, data.length);
    entry.status = AssetStatus.ready;
    assets.put(handle, entry);
    return success(handle);
}

/**
 * Decrements the usage count for the asset identified by $(D handle).
 * The count will not go below zero.
 *
 * Params:
 *  handle = The handle of the asset to release.
 */
void releaseAssetData(AssetHandle handle) {
    if (handle == 0) {
        return;
    }

    AssetEntry entry;
    if (assets.tryGet(handle, entry) && entry.usageCount > 0) {
        entry.usageCount--;
        assets.put(handle, entry);
    }
}

/**
 * Frees memory and removes all assets whose usage count is zero and are not pending.
 * After unloading, the asset can be re-fetched via $(D fetchAsset).
 */
void unloadUnusedAssets() {
    Array!uint toUnload;
    foreach (ref h, ref entry; assets) {
        if (entry.usageCount == 0 && entry.status != AssetStatus.pending) {
            if (entry.data !is null) {
                free(entry.data.ptr);
            }

            toUnload.add(h);
        }
    }

    foreach (ref h; toUnload) {
        assets.remove(h);

        foreach (ref p, ref storedHandle; pathToHandle) {
            if (storedHandle == h) {
                pathToHandle.remove(p);
                break;
            }
        }
    }
}

/**
 * Called by the platform layer to signal that an async asset fetch completed successfully.
 * Copies $(D data) into a managed buffer and marks the asset as ready.
 *
 * Params:
 *  handle = The handle of the asset that finished loading.
 *  data   = Slice of the loaded data to copy.
 */
void assetFetchComplete(uint handle, ubyte[] data) {
    AssetEntry e;
    if (assets.tryGet(handle, e)) {
        e.data = (cast(ubyte*) malloc(data.length))[0 .. data.length];
        memcpy(cast(void*) e.data.ptr, cast(void*) data.ptr, data.length);
        e.status = AssetStatus.ready;
        assets.put(handle, e);
    }
}

/**
 * Called by the platform layer to signal that an async asset fetch failed.
 * Marks the asset as being in an error state and stores the error message.
 *
 * Params:
 *  handle  = The handle of the asset that failed to load.
 *  message = A description of the error.
 */
void assetFetchError(uint handle, String message) {
    AssetEntry e;
    if (assets.tryGet(handle, e)) {
        e.status = AssetStatus.error;
        e.errorMessage = message;
        assets.put(handle, e);
    }
}

version (UnitTesting)  :  ///

/// Resets all module-level asset state. Test-only; also used by dependent modules' tests.
void resetState() {
    mounts.clear();
    pathToHandle.clear();
    assets.clear();

    nextHandle = 1;
}

void runAssetsTests() {
    import retrograde.std.test : test, writeSection;

    writeSection("-- Assets tests --");

    test("mountAssetsPath succeeds for new mount", () {
        resetState();

        auto result = mountAssetsPath("unittest://data/textures".s, "textures/".s);
        assert(result.isSuccessful);
    });

    test("mountAssetsPath fails for duplicate mount", () {
        resetState();

        mountAssetsPath("unittest://data/textures".s, "textures/".s);
        auto result = mountAssetsPath("unittest://other".s, "textures/".s);
        assert(result.isFailure);
    });

    test("fetchAsset fails when no mount matches", () {
        resetState();

        auto result = fetchAsset("textures/wood.png".s);
        assert(result.isFailure);
    });

    test("fetchAsset returns handle on matching mount", () {
        resetState();

        mountAssetsPath("unittest://data/".s, "assets/".s);
        auto result = fetchAsset("assets/model.rgm".s);
        assert(result.isSuccessful);
        assert(result.value == 1);
    });

    test("fetchAsset returns same handle for same path", () {
        resetState();

        mountAssetsPath("unittest://data/".s, "assets/".s);
        auto first = fetchAsset("assets/model.rgm".s);
        auto second = fetchAsset("assets/model.rgm".s);
        assert(first.value == second.value);
    });

    test("isAssetReady returns false for unknown handle", () {
        resetState();

        assert(!isAssetReady(999));
    });

    test("isAssetError returns false for unknown handle", () {
        resetState();

        assert(!isAssetError(999));
    });

    test("getAssetData fails for invalid handle", () {
        resetState();

        auto result = getAssetData(999);
        assert(result.isFailure);
    });

    test("getAssetError fails for invalid handle", () {
        resetState();

        auto result = getAssetError(999);
        assert(result.isFailure);
    });

    test("getAssetError fails when asset is not in error state", () {
        resetState();

        mountAssetsPath("unittest://data/".s, "assets/".s);
        auto fetchResult = fetchAsset("assets/model.rgm".s);
        auto handle = fetchResult.value;
        assetFetchComplete(handle, null);

        auto result = getAssetError(handle);
        assert(result.isFailure);
    });

    test("getAssetError returns error message when asset is in error state", () {
        resetState();

        mountAssetsPath("unittest://data/".s, "assets/".s);
        auto fetchResult = fetchAsset("assets/model.rgm".s);
        auto handle = fetchResult.value;
        assetFetchError(handle, "file not found".s);

        auto result = getAssetError(handle);
        assert(result.isSuccessful);
        assert(result.value == "file not found".s);
    });

    test("getAssetData increments usage count on success", () {
        resetState();

        mountAssetsPath("unittest://data/".s, "assets/".s);
        auto fetchResult = fetchAsset("assets/model.rgm".s);
        auto handle = fetchResult.value;
        assetFetchComplete(handle, null);

        getAssetData(handle);
        getAssetData(handle);

        AssetEntry entry;
        assets.tryGet(handle, entry);
        assert(entry.usageCount == 2);
    });

    test("releaseAssetData decrements usage count", () {
        resetState();

        mountAssetsPath("unittest://data/".s, "assets/".s);
        auto fetchResult = fetchAsset("assets/model.rgm".s);
        auto handle = fetchResult.value;
        assetFetchComplete(handle, null);

        getAssetData(handle);
        getAssetData(handle);
        releaseAssetData(handle);

        AssetEntry entry;
        assets.tryGet(handle, entry);
        assert(entry.usageCount == 1);
    });

    test("releaseAssetData does not decrement below zero", () {
        resetState();

        mountAssetsPath("unittest://data/".s, "assets/".s);
        auto fetchResult = fetchAsset("assets/model.rgm".s);
        auto handle = fetchResult.value;
        assetFetchComplete(handle, null);

        releaseAssetData(handle);
        releaseAssetData(handle);

        AssetEntry entry;
        assets.tryGet(handle, entry);
        assert(entry.usageCount == 0);
    });

    test("unloadUnusedAssets removes assets with zero usage count", () {
        resetState();

        mountAssetsPath("unittest://data/".s, "assets/".s);
        auto fetchResult = fetchAsset("assets/model.rgm".s);
        auto handle = fetchResult.value;
        assetFetchComplete(handle, null);

        unloadUnusedAssets();

        assert(!isAssetReady(handle));
        auto refetchResult = fetchAsset("assets/model.rgm".s);
        assert(refetchResult.value != handle);
    });

    test("unloadUnusedAssets keeps assets that are still pending", () {
        resetState();

        mountAssetsPath("unittest://data/".s, "assets/".s);
        auto fetchResult = fetchAsset("assets/model.rgm".s);
        auto handle = fetchResult.value;

        unloadUnusedAssets();

        AssetEntry entry;
        assert(assets.tryGet(handle, entry));
        assert(entry.status == AssetStatus.pending);
    });

    test("unloadUnusedAssets keeps assets with nonzero usage count", () {
        resetState();

        mountAssetsPath("unittest://data/".s, "assets/".s);
        auto fetchResult = fetchAsset("assets/model.rgm".s);
        auto handle = fetchResult.value;
        assetFetchComplete(handle, null);
        getAssetData(handle);

        unloadUnusedAssets();

        assert(isAssetReady(handle));
    });

    test("addAssetData returns an immediately ready handle", () {
        resetState();

        ubyte[4] data = [1, 2, 3, 4];
        auto result = addAssetData(data[]);
        assert(result.isSuccessful);
        assert(isAssetReady(result.value));
    });

    test("addAssetData data can be retrieved via getAssetData", () {
        resetState();

        ubyte[3] data = [10, 20, 30];
        auto addResult = addAssetData(data[]);
        auto dataResult = getAssetData(addResult.value);
        assert(dataResult.isSuccessful);
        assert(dataResult.value.length == 3);
        assert(dataResult.value[0] == 10);
        assert(dataResult.value[1] == 20);
        assert(dataResult.value[2] == 30);
    });

    writeSection("-- withAssetData tests --");

    test("withAssetData calls onSuccess when asset is ready", () {
        resetState();

        ubyte[3] data = [1, 2, 3];
        auto handle = addAssetData(data[]).value;

        bool called = false;
        withAssetData(handle, (const(ubyte)[] d) {
            called = true;
            assert(d.length == 3);
        }, (String e) {});

        assert(called);
    });

    test("withAssetData calls onAssetError when asset is in an error state", () {
        resetState();

        mountAssetsPath("unittest://data/".s, "assets/".s);
        auto handle = fetchAsset("assets/model.rgm".s).value;
        assetFetchError(handle, "fetch failed".s);

        String received;
        withAssetData(handle, (const(ubyte)[] d) {}, (String e) { received = e; });

        assert(received == "fetch failed");
    });

    test("withAssetData calls none of the delegates when asset is pending", () {
        resetState();

        mountAssetsPath("unittest://data/".s, "assets/".s);
        auto handle = fetchAsset("assets/model.rgm".s).value;

        bool called = false;
        withAssetData(handle, (const(ubyte)[] d) { called = true; }, (String e) {
            called = true;
        });

        assert(!called);
    });
}
