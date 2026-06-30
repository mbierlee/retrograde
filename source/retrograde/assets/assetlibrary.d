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

module retrograde.assets.assetlibrary;

import retrograde.assets.rgm : loadModel;
import retrograde.assets.rgi : loadImage;
import retrograde.assets.model : Model, TextureType;
import retrograde.assets.image : Image;

import retrograde.std.assets : AssetHandle, fetchAsset, isAssetReady, getAssetData;
import retrograde.std.result : Result, success, failure;
import retrograde.std.collections : HashMap, LinkedList, Array;
import retrograde.std.memory : SharedPtr, ResultPtr;
import retrograde.std.stdio : writeErrLn;
import retrograde.std.string : String;

// --- Library collections: the resolved handles and loaded assets that make up the library. ---

/// Maps a model's virtual path to its asset handle, so each model is fetched only once.
private HashMap!(String, AssetHandle) modelHandles;

/// Stores loaded models, keyed by their asset handle.
private HashMap!(AssetHandle, SharedPtr!Model) loadedModels;

/// Maps a texture's virtual path to its asset handle, so each texture is fetched only once.
private HashMap!(String, AssetHandle) textureHandles;

/// Stores fully loaded textures, keyed by their asset handle.
private HashMap!(AssetHandle, SharedPtr!Image) loadedTextures;

// --- Bookkeeping collections: transient state tracking in-flight loads and completion. ---

/// Success callbacks registered per model handle, invoked once the model is fully finished.
private HashMap!(AssetHandle, Array!(void function())) fetchFinishedCallbacks;

/// Model handles whose asset data is still being fetched.
private LinkedList!AssetHandle fetchingModels;

/// Number of textures a loaded model is still waiting on before it is fully finished.
/// A model only has an entry while it has outstanding textures.
private HashMap!(AssetHandle, size_t) pendingTextureCounts;

/// Maps a still-loading texture handle to the model handles waiting on it.
private HashMap!(AssetHandle, Array!AssetHandle) textureDependents;

/// Texture handles whose asset data is still being fetched.
private LinkedList!AssetHandle fetchingTextures;

version (UnitTesting) {
    private bool suppressErrorLogging = false;
}

/// Log an error to standard error. During unit tests it can be muted via
/// `suppressErrorLogging` so tests that deliberately exercise failure paths stay quiet.
private void logError(Args...)(Args args) {
    version (UnitTesting) {
        if (suppressErrorLogging) {
            return;
        }
    }

    writeErrLn(args);
}

/** 
 * Fetch a model and all its textures.
 * Params:
 *  virtualPath = The virtual path of the asset to fetch.
 * Returns: A $(D Result) containing the $(D AssetHandle) on success, or a failure
 *          if no mount matches the virtual path.
 */
Result!AssetHandle fetchModel(String virtualPath, void function() onFetchComplete = null) {
    AssetHandle handle;
    if (modelHandles.tryGet(virtualPath, handle)) {
        // The asset was already requested. If it is fully finished (model parsed and all
        // its textures loaded), invoke the callback right away; otherwise register it
        // alongside any previously registered callbacks so it fires on completion.
        if (isModelFinished(handle)) {
            if (onFetchComplete !is null) {
                onFetchComplete();
            }
        } else {
            registerFetchFinishedCallback(handle, onFetchComplete);
        }

        return success(handle);
    }

    auto fetchRes = fetchAsset(virtualPath);
    if (fetchRes.isFailure()) {
        return fetchRes;
    }

    handle = fetchRes.value;
    modelHandles.put(virtualPath, handle);
    registerFetchFinishedCallback(handle, onFetchComplete);

    // Fast-fetches (e.g. assets that resolved synchronously) may already be ready;
    // process them right away instead of waiting for the next processLibraryAssets cycle.
    if (!isAssetReady(handle) || !processReadyModel(handle)) {
        fetchingModels.add(handle);
    }

    return success(handle);
}

/**
 * Retrieve a loaded model by its virtual path.
 *
 * Params:
 *  virtualPath = The virtual path the model was fetched with.
 * Returns: A $(D Result) with the model's $(D SharedPtr) on success, or a failure if no model
 *          has been fetched for the path or it has not finished loading yet.
 */
Result!(SharedPtr!Model) getModel(String virtualPath) {
    AssetHandle handle;
    if (!modelHandles.tryGet(virtualPath, handle)) {
        return failure!(SharedPtr!Model)("No model has been fetched for the given path");
    }

    return getModel(handle);
}

/**
 * Retrieve a loaded model by its asset handle.
 *
 * A model is only retrievable once it is completely finished: parsed, stored, and with all of
 * its referenced textures loaded.
 *
 * Params:
 *  handle = The handle of the model to retrieve.
 * Returns: A $(D Result) with the model's $(D SharedPtr) on success, or a failure if no finished
 *          model exists for the handle (it may still be fetching its model or textures, or have
 *          failed to load).
 */
Result!(SharedPtr!Model) getModel(AssetHandle handle) {
    if (!isModelFinished(handle)) {
        return failure!(SharedPtr!Model)("No finished model exists for the given handle");
    }

    SharedPtr!Model model;
    loadedModels.tryGet(handle, model);
    return success(model);
}

/**
 * Retrieve the asset handle a model was fetched under.
 *
 * Params:
 *  virtualPath = The virtual path the model was fetched with.
 * Returns: A $(D Result) with the $(D AssetHandle) on success, or a failure if no model has
 *          been fetched for the path.
 */
Result!AssetHandle getModelHandle(String virtualPath) {
    AssetHandle handle;
    if (!modelHandles.tryGet(virtualPath, handle)) {
        return failure!AssetHandle("No model has been fetched for the given path");
    }

    return success(handle);
}

/**
 * Retrieve a loaded texture by its virtual path.
 *
 * Params:
 *  virtualPath = The virtual path the texture was referenced by.
 * Returns: A $(D Result) with the texture's $(D SharedPtr) on success, or a failure if no texture
 *          has been fetched for the path or it has not finished loading yet.
 */
Result!(SharedPtr!Image) getTexture(String virtualPath) {
    AssetHandle handle;
    if (!textureHandles.tryGet(virtualPath, handle)) {
        return failure!(SharedPtr!Image)("No texture has been fetched for the given path");
    }

    return getTexture(handle);
}

/**
 * Retrieve a loaded texture by its asset handle.
 *
 * A texture is retrievable as soon as it has finished loading, independently of whether the
 * models referencing it are finished.
 *
 * Params:
 *  handle = The handle of the texture to retrieve.
 * Returns: A $(D Result) with the texture's $(D SharedPtr) on success, or a failure if no loaded
 *          texture exists for the handle (it may still be fetching, or have failed to load).
 */
Result!(SharedPtr!Image) getTexture(AssetHandle handle) {
    SharedPtr!Image texture;
    if (!loadedTextures.tryGet(handle, texture)) {
        return failure!(SharedPtr!Image)("No loaded texture exists for the given handle");
    }

    return success(texture);
}

/**
 * Retrieve the asset handle a texture was fetched under.
 *
 * Params:
 *  virtualPath = The virtual path the texture was referenced by.
 * Returns: A $(D Result) with the $(D AssetHandle) on success, or a failure if no texture has
 *          been fetched for the path.
 */
Result!AssetHandle getTextureHandle(String virtualPath) {
    AssetHandle handle;
    if (!textureHandles.tryGet(virtualPath, handle)) {
        return failure!AssetHandle("No texture has been fetched for the given path");
    }

    return success(handle);
}

/**
 * Advance all in-flight asset loads.
 *
 * Polls models and textures that are still being fetched, parsing and storing any that have
 * become ready and invoking the fetch-finished callbacks of models whose assets are now fully
 * loaded. Call this once per frame (or update cycle) to drive asynchronous loading forward.
 */
void processLibraryAssets() {
    processFetchingModels();
    processFetchingTextures();
}

/// A model is finished once it has been parsed and stored and has no textures left to load.
private bool isModelFinished(AssetHandle handle) {
    return loadedModels.contains(handle) && !pendingTextureCounts.contains(handle);
}

private void registerFetchFinishedCallback(AssetHandle handle, void function() onFetchComplete) {
    if (onFetchComplete is null) {
        return;
    }

    Array!(void function()) callbacks;
    fetchFinishedCallbacks.tryGet(handle, callbacks);
    callbacks.add(onFetchComplete);
    fetchFinishedCallbacks.put(handle, callbacks);
}

private void processFetchingModels() {
    auto it = fetchingModels.iterator();
    while (it.hasNext()) {
        AssetHandle handle = it.next().value();
        if (isAssetReady(handle) && processReadyModel(handle)) {
            it.remove();
        }
    }
}

private bool processReadyModel(AssetHandle handle) {
    auto dataRes = getAssetData(handle);
    if (dataRes.isFailure()) {
        logError("Failed to read fetched model asset data: ", dataRes.errorMessage());
        return false;
    }

    auto modelResult = loadModel(dataRes.value());
    if (modelResult.isFailure()) {
        logError("Failed to load fetched model: ", modelResult.errorMessage());
        abandonModel(handle);
        return true;
    }

    // Keep a raw view of the model to inspect its textures; ownership moves into loadedModels.
    Model* model = modelResult.ptr();
    loadedModels.put(handle, modelResult.share());

    // A model is only finished once all of its referenced textures are loaded too.
    size_t pendingTextures;
    if (!fetchModelTextures(handle, model, pendingTextures)) {
        // A texture could not be fetched; the model can never finish.
        abandonModel(handle);
        return true;
    }

    if (pendingTextures == 0) {
        finishModel(handle);
    }

    return true;
}

/**
 * Fetch every external texture referenced by a freshly loaded model, deduplicating against
 * textures that are already loaded or in flight. Records how many of them the model must
 * still wait on so it can be finished once they all arrive.
 *
 * Params:
 *  modelHandle = The handle of the model whose textures should be fetched.
 *  model       = The parsed model to inspect.
 *  pending     = Receives the number of textures the model is still waiting on.
 * Returns: true if all textures were fetched (or already available), false if a texture
 *          could not be fetched, meaning the model can never finish.
 */
private bool fetchModelTextures(AssetHandle modelHandle, Model* model, out size_t pending) {
    pending = 0;
    foreach (ref texture; model.textures) {
        if (texture.type != TextureType.reference || texture.path.length == 0) {
            continue;
        }

        AssetHandle textureHandle;
        bool alreadyRequested = textureHandles.tryGet(texture.path, textureHandle);
        if (alreadyRequested && loadedTextures.contains(textureHandle)) {
            // Already fetched and stored by an earlier model; nothing to wait for.
            continue;
        }

        if (!alreadyRequested) {
            auto fetchRes = fetchAsset(texture.path);
            if (fetchRes.isFailure()) {
                logError("Failed to fetch model texture '", texture.path, "': ", fetchRes
                        .errorMessage());
                return false;
            }

            textureHandle = fetchRes.value;
            textureHandles.put(texture.path, textureHandle);

            // Fast-fetches (e.g. assets that resolved synchronously) may already be ready.
            if (isAssetReady(textureHandle) && processReadyTexture(textureHandle)) {
                if (loadedTextures.contains(textureHandle)) {
                    // Stored synchronously; the model need not wait on it.
                    continue;
                }

                // The texture was processed but failed to load; the model can never finish.
                return false;
            }

            fetchingTextures.add(textureHandle);
        }

        // The texture is still being fetched; record that this model depends on it.
        addTextureDependent(textureHandle, modelHandle);
        pending++;
    }

    if (pending > 0) {
        pendingTextureCounts.put(modelHandle, pending);
    }

    return true;
}

private void addTextureDependent(AssetHandle textureHandle, AssetHandle modelHandle) {
    Array!AssetHandle dependents;
    textureDependents.tryGet(textureHandle, dependents);
    dependents.add(modelHandle);
    textureDependents.put(textureHandle, dependents);
}

private void processFetchingTextures() {
    auto it = fetchingTextures.iterator();
    while (it.hasNext()) {
        AssetHandle handle = it.next().value();
        if (isAssetReady(handle) && processReadyTexture(handle)) {
            it.remove();
        }
    }
}

private bool processReadyTexture(AssetHandle handle) {
    auto dataRes = getAssetData(handle);
    if (dataRes.isFailure()) {
        logError("Failed to read fetched texture asset data: ", dataRes.errorMessage());
        return false;
    }

    auto imageResult = loadImage(dataRes.value());
    if (imageResult.isFailure()) {
        logError("Failed to load fetched texture: ", imageResult.errorMessage());
        failTexture(handle);
        return true;
    }

    loadedTextures.put(handle, imageResult.share());
    notifyTextureLoaded(handle);
    return true;
}

/**
 * Notify every model waiting on the given texture that it has loaded, finishing any model
 * whose last outstanding texture this was.
 */
private void notifyTextureLoaded(AssetHandle textureHandle) {
    Array!AssetHandle dependents;
    if (!textureDependents.tryGet(textureHandle, dependents)) {
        return;
    }

    foreach (modelHandle; dependents) {
        size_t pending;
        if (!pendingTextureCounts.tryGet(modelHandle, pending)) {
            continue;
        }

        pending--;
        if (pending == 0) {
            pendingTextureCounts.remove(modelHandle);
            finishModel(modelHandle);
        } else {
            pendingTextureCounts.put(modelHandle, pending);
        }
    }

    textureDependents.remove(textureHandle);
}

/// Invoke and clear the success callbacks registered for a fully finished model.
private void finishModel(AssetHandle handle) {
    Array!(void function()) callbacks;
    if (fetchFinishedCallbacks.tryGet(handle, callbacks)) {
        foreach (callback; callbacks) {
            callback();
        }

        fetchFinishedCallbacks.remove(handle);
    }
}

/**
 * Drop all bookkeeping for a model that can never finish loading. Its registered success
 * callbacks are intentionally discarded without being invoked.
 */
private void abandonModel(AssetHandle handle) {
    pendingTextureCounts.remove(handle);
    fetchFinishedCallbacks.remove(handle);
    loadedModels.remove(handle);
    removeHandleByValue(modelHandles, handle);
}

/**
 * Drop all bookkeeping for a texture that failed to load and abandon every model that was
 * waiting on it, since those models can no longer finish.
 */
private void failTexture(AssetHandle handle) {
    removeHandleByValue(textureHandles, handle);

    Array!AssetHandle dependents;
    if (textureDependents.tryGet(handle, dependents)) {
        foreach (modelHandle; dependents) {
            abandonModel(modelHandle);
        }

        textureDependents.remove(handle);
    }
}

/// Remove the first entry mapping a virtual path to the given handle, if any.
private void removeHandleByValue(ref HashMap!(String, AssetHandle) map, AssetHandle handle) {
    foreach (ref path, ref storedHandle; map) {
        if (storedHandle == handle) {
            map.remove(path);
            break;
        }
    }
}

version (UnitTesting)  :  ///

import retrograde.std.assets : mountAssetsPath, assetFetchComplete, resetAssetState = resetState;
import retrograde.std.string : s;

private bool testCallbackFired;
private int testCallbackCount;

private void markCallbackFired() {
    testCallbackFired = true;
}

private void countCallback() {
    testCallbackCount++;
}

// Minimal valid RGM: header only, no meshes, materials or textures.
private immutable ubyte[18] emptyModelRgm = [
    0x52, 0x47, 0x4D, 0x20, // Magic
    0x01, 0x00, // Version
    0x00, 0x00, 0x00, 0x00, // Meshes (0)
    0x00, 0x00, 0x00, 0x00, // Materials (0)
    0x00, 0x00, 0x00, 0x00, // Textures (0)
];

// RGM referencing a single texture at "lib/a.rgi".
private immutable ubyte[34] oneTextureRgm = [
    0x52, 0x47, 0x4D, 0x20, // Magic
    0x01, 0x00, // Version
    0x00, 0x00, 0x00, 0x00, // Meshes (0)
    0x00, 0x00, 0x00, 0x00, // Materials (0)
    0x01, 0x00, 0x00, 0x00, // Textures (1)
    // Texture 1
    0x01, 0x00, 0x00, 0x00, // Index (1)
    0x00, // Type (reference)
    0x09, 0x00, // Path length (9)
    'l', 'i', 'b', '/', 'a', '.', 'r', 'g', 'i',
];

// RGM referencing two textures at "lib/a.rgi" and "lib/b.rgi".
private immutable ubyte[50] twoTextureRgm = [
    0x52, 0x47, 0x4D, 0x20, // Magic
    0x01, 0x00, // Version
    0x00, 0x00, 0x00, 0x00, // Meshes (0)
    0x00, 0x00, 0x00, 0x00, // Materials (0)
    0x02, 0x00, 0x00, 0x00, // Textures (2)
    // Texture 1
    0x01, 0x00, 0x00, 0x00, 0x00, 0x09, 0x00, 'l', 'i', 'b', '/', 'a', '.', 'r',
    'g', 'i',
    // Texture 2
    0x02, 0x00, 0x00, 0x00, 0x00, 0x09, 0x00, 'l', 'i', 'b', '/', 'b', '.', 'r',
    'g', 'i',
];

// Minimal valid RGI: 1x1, single channel, u8, direct color.
private immutable ubyte[20] imageRgi = [
    0x52, 0x47, 0x49, 0x20, // Magic
    0x01, 0x00, // Version
    0x00, // Compression (none)
    0x00, // Color mode (direct)
    0x00, // Index format (unused)
    0x01, 0x00, 0x00, 0x00, // Width (1)
    0x01, 0x00, 0x00, 0x00, // Height (1)
    0x01, // Channel count (1)
    0x00, // Channel format (u8)
    0xFF, // Pixel
];

private ubyte[] bytes(const(ubyte)[] data) {
    return cast(ubyte[]) data;
}

private void resetState() {
    version (WasmMemTest) {
        // The WasmMemTest harness wipes the heap before each test, so these module-level
        // collections already hold dangling pointers. Reset them to their init state without
        // freeing: clear() would walk the freed nodes (LinkedList.clear in particular faults
        // on the corrupted chain) instead of harmlessly dropping them.
        import retrograde.std.memory : memset;

        memset(&modelHandles, 0, modelHandles.sizeof);
        memset(&loadedModels, 0, loadedModels.sizeof);
        memset(&textureHandles, 0, textureHandles.sizeof);
        memset(&loadedTextures, 0, loadedTextures.sizeof);
        memset(&fetchFinishedCallbacks, 0, fetchFinishedCallbacks.sizeof);
        memset(&fetchingModels, 0, fetchingModels.sizeof);
        memset(&pendingTextureCounts, 0, pendingTextureCounts.sizeof);
        memset(&textureDependents, 0, textureDependents.sizeof);
        memset(&fetchingTextures, 0, fetchingTextures.sizeof);
    } else {
        modelHandles.clear();
        loadedModels.clear();
        textureHandles.clear();
        loadedTextures.clear();
        fetchFinishedCallbacks.clear();
        fetchingModels.clear();
        pendingTextureCounts.clear();
        textureDependents.clear();
        fetchingTextures.clear();
    }

    testCallbackFired = false;
    testCallbackCount = 0;
    suppressErrorLogging = false;
    resetAssetState();
}

void runAssetLibraryTests() {
    import retrograde.std.test : test, writeSection;

    writeSection("-- Asset library tests --");

    test("fetchModel fails when no mount matches the path", () {
        resetState();

        auto result = fetchModel("lib/model.rgm".s);
        assert(result.isFailure);
    });

    test("fetchModel returns a handle for a mounted path", () {
        resetState();
        mountAssetsPath("unittest://lib/".s, "lib/".s);

        auto result = fetchModel("lib/model.rgm".s);
        assert(result.isSuccessful);
    });

    test("fetchModel returns the same handle for repeated fetches of a path", () {
        resetState();
        mountAssetsPath("unittest://lib/".s, "lib/".s);

        auto first = fetchModel("lib/model.rgm".s);
        auto second = fetchModel("lib/model.rgm".s);
        assert(first.value == second.value);
    });

    writeSection("-- Asset library: model retrieval --");

    test("getModelHandle fails for an unfetched path", () {
        resetState();
        mountAssetsPath("unittest://lib/".s, "lib/".s);

        auto result = getModelHandle("lib/model.rgm".s);
        assert(result.isFailure);
    });

    test("getModelHandle returns the handle after fetching", () {
        resetState();
        mountAssetsPath("unittest://lib/".s, "lib/".s);

        auto handle = fetchModel("lib/model.rgm".s).value;
        auto result = getModelHandle("lib/model.rgm".s);
        assert(result.isSuccessful);
        assert(result.value == handle);
    });

    test("getModel fails while the model is still being fetched", () {
        resetState();
        mountAssetsPath("unittest://lib/".s, "lib/".s);

        auto handle = fetchModel("lib/model.rgm".s).value;
        assert(getModel("lib/model.rgm".s).isFailure);
        assert(getModel(handle).isFailure);
    });

    test("getModel fails for an unknown handle", () {
        resetState();

        assert(getModel(999u).isFailure);
    });

    test("processLibraryAssets finishes a textureless model", () {
        resetState();
        mountAssetsPath("unittest://lib/".s, "lib/".s);

        auto handle = fetchModel("lib/model.rgm".s, &markCallbackFired).value;
        assetFetchComplete(handle, bytes(emptyModelRgm));
        processLibraryAssets();

        assert(testCallbackFired);
        assert(getModel("lib/model.rgm".s).isSuccessful);
        assert(getModel(handle).isSuccessful);
    });

    writeSection("-- Asset library: texture loading --");

    test("a model with a texture finishes only once the texture is loaded", () {
        resetState();
        mountAssetsPath("unittest://lib/".s, "lib/".s);

        auto modelHandle = fetchModel("lib/model.rgm".s, &markCallbackFired).value;
        assetFetchComplete(modelHandle, bytes(oneTextureRgm));
        processLibraryAssets();

        // Model is parsed but waits on its texture.
        assert(!testCallbackFired);
        assert(getModel(modelHandle).isFailure);

        auto textureHandle = getTextureHandle("lib/a.rgi".s);
        assert(textureHandle.isSuccessful);
        assert(getTexture(textureHandle.value).isFailure);

        assetFetchComplete(textureHandle.value, bytes(imageRgi));
        processLibraryAssets();

        assert(testCallbackFired);
        assert(getModel(modelHandle).isSuccessful);
        assert(getTexture("lib/a.rgi".s).isSuccessful);
    });

    test("a texture is retrievable before its model is finished", () {
        resetState();
        mountAssetsPath("unittest://lib/".s, "lib/".s);

        auto modelHandle = fetchModel("lib/model.rgm".s).value;
        assetFetchComplete(modelHandle, bytes(twoTextureRgm));
        processLibraryAssets();

        // Complete only the first of the two textures.
        auto textureA = getTextureHandle("lib/a.rgi".s).value;
        assetFetchComplete(textureA, bytes(imageRgi));
        processLibraryAssets();

        // That texture is available, but the model still waits on the second one.
        assert(getTexture("lib/a.rgi".s).isSuccessful);
        assert(getModel(modelHandle).isFailure);
    });

    test("a texture shared by two models is fetched once and finishes both", () {
        resetState();
        mountAssetsPath("unittest://lib/".s, "lib/".s);

        auto firstModel = fetchModel("lib/first.rgm".s).value;
        auto secondModel = fetchModel("lib/second.rgm".s).value;
        assetFetchComplete(firstModel, bytes(oneTextureRgm));
        assetFetchComplete(secondModel, bytes(oneTextureRgm));
        processLibraryAssets();

        // Both models reference "lib/a.rgi"; completing it once finishes both.
        auto textureHandle = getTextureHandle("lib/a.rgi".s).value;
        assetFetchComplete(textureHandle, bytes(imageRgi));
        processLibraryAssets();

        assert(getModel(firstModel).isSuccessful);
        assert(getModel(secondModel).isSuccessful);
    });

    test("getTexture fails for unknown paths and handles", () {
        resetState();

        assert(getTexture("lib/missing.rgi".s).isFailure);
        assert(getTexture(999u).isFailure);
        assert(getTextureHandle("lib/missing.rgi".s).isFailure);
    });

    writeSection("-- Asset library: callbacks --");

    test("all registered callbacks fire when a model finishes", () {
        resetState();
        mountAssetsPath("unittest://lib/".s, "lib/".s);

        auto handle = fetchModel("lib/model.rgm".s, &countCallback).value;
        // A second fetch of the same path registers another callback on the same model.
        fetchModel("lib/model.rgm".s, &countCallback);

        assetFetchComplete(handle, bytes(emptyModelRgm));
        processLibraryAssets();

        assert(testCallbackCount == 2);
    });

    test("a callback for an already finished model fires immediately", () {
        resetState();
        mountAssetsPath("unittest://lib/".s, "lib/".s);

        auto handle = fetchModel("lib/model.rgm".s).value;
        assetFetchComplete(handle, bytes(emptyModelRgm));
        processLibraryAssets();

        // The model is finished; a later fetch invokes the callback right away.
        fetchModel("lib/model.rgm".s, &markCallbackFired);
        assert(testCallbackFired);
    });

    writeSection("-- Asset library: failure handling --");

    test("a model that fails to parse is abandoned and cleaned up", () {
        resetState();
        suppressErrorLogging = true;
        mountAssetsPath("unittest://lib/".s, "lib/".s);

        ubyte[4] garbage = [0x00, 0x00, 0x00, 0x00];
        auto handle = fetchModel("lib/model.rgm".s, &markCallbackFired).value;
        assetFetchComplete(handle, garbage[]);
        processLibraryAssets();

        assert(!testCallbackFired);
        assert(getModel(handle).isFailure);
        // Bookkeeping is cleaned up: the path no longer resolves to a handle.
        assert(getModelHandle("lib/model.rgm".s).isFailure);
    });

    test("a model whose texture fails to load is abandoned", () {
        resetState();
        suppressErrorLogging = true;
        mountAssetsPath("unittest://lib/".s, "lib/".s);

        ubyte[4] garbage = [0x00, 0x00, 0x00, 0x00];
        auto modelHandle = fetchModel("lib/model.rgm".s, &markCallbackFired).value;
        assetFetchComplete(modelHandle, bytes(oneTextureRgm));
        processLibraryAssets();

        auto textureHandle = getTextureHandle("lib/a.rgi".s).value;
        assetFetchComplete(textureHandle, garbage[]);
        processLibraryAssets();

        assert(!testCallbackFired);
        assert(getModel(modelHandle).isFailure);
        assert(getTexture(textureHandle).isFailure);
    });
}
