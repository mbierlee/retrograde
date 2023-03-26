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

module retrograde.model.common;

import retrograde.core.model : ModelLoader, Model;
import retrograde.core.storage : File;
import retrograde.model.stanfordply : StanfordPlyLoader;
import retrograde.model.wavefrontobj : WavefrontObjLoader;

import poodinis : Inject;

/** 
 * Loads models based on their file extension.
 *
 * Throws: Exception when extension is not recognized.
 */
class CommonModelLoader : ModelLoader {
    private @Inject StanfordPlyLoader stanfordPlyLoader;
    private @Inject WavefrontObjLoader wavefrontObjLoader;

    public Model load(File modelFile) {
        switch (modelFile.extension) {
        case ".ply":
            return stanfordPlyLoader.load(modelFile);

        case ".obj":
            return wavefrontObjLoader.load(modelFile);

        default:
            throw new Exception(
                "Model with extension " ~ modelFile.extension ~ " is unknown. Try to use a specific loader instead.");
        }
    }
}

version (unittest) {
    import std.exception : assertThrown;
    import poodinis : DependencyContainer, existingInstance;

    private class StubLoader(T : ModelLoader) : T {
        public bool loadWasCalled = false;
        public Model model;

        public override Model load(File modelFile) {
            loadWasCalled = true;
            return model;
        }
    }

    private void registerStub(T : ModelLoader)(shared DependencyContainer dependencies) {
        auto stub = new StubLoader!T();
        dependencies.register!T.existingInstance(stub);
    }

    private class Fixture {
        public StanfordPlyLoader stanfordPlyLoader;
        public WavefrontObjLoader wavefrontObjLoader;
        public CommonModelLoader commonModelLoader;

        this() {
            auto dependencies = new shared DependencyContainer();
            dependencies.registerStub!StanfordPlyLoader;
            dependencies.registerStub!WavefrontObjLoader;
            dependencies.register!CommonModelLoader;

            stanfordPlyLoader = dependencies.resolve!StanfordPlyLoader;
            wavefrontObjLoader = dependencies.resolve!WavefrontObjLoader;
            commonModelLoader = dependencies.resolve!CommonModelLoader;
        }
    }

    private StubLoader!T stub(T : ModelLoader)(T loader) {
        return cast(StubLoader!T) loader;
    }

    @("Fails to load a file for which the extension is unknown")
    unittest {
        auto loader = new CommonModelLoader();
        auto file = new File("cube.supermodel");
        assertThrown!Exception(loader.load(file));
    }

    @("Load Stanford PLY models")
    unittest {
        auto f = new Fixture();
        auto model = new Model([]);
        f.stanfordPlyLoader.stub.model = model;

        assert(f.commonModelLoader.load(new File("model.ply")) is model);
        assert(f.stanfordPlyLoader.stub.loadWasCalled);
        assert(!f.wavefrontObjLoader.stub.loadWasCalled);
    }

    @("Load Wavefront OBJ models")
    unittest {
        auto f = new Fixture();
        auto model = new Model([]);
        f.wavefrontObjLoader.stub.model = model;

        assert(f.commonModelLoader.load(new File("model.obj")) is model);
        assert(!f.stanfordPlyLoader.stub.loadWasCalled);
        assert(f.wavefrontObjLoader.stub.loadWasCalled);
    }
}
