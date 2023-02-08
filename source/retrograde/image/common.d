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

module retrograde.image.common;

import retrograde.core.image : ImageLoader, Image, ColorFormat, ColorDepth;
import retrograde.core.storage : File;

import retrograde.image.png : PngImageLoader;

import poodinis : Autowire;

/** 
 * Loads images based on their extension.
 *
 * Throws: Exception when extension is not recognized.
 */
class CommonImageLoader : ImageLoader {
    @Autowire public PngImageLoader pngImageLoader;

    public Image load(File imageFile) {
        switch (imageFile.extension) {
        case ".png":
            return pngImageLoader.load(imageFile);

        default:
            throw new Exception(
                "Model with extension " ~ imageFile.extension ~ " is unknown. Try to use a specific loader instead.");
        }
    }
}

version (unittest) {
    import std.exception : assertThrown;
    import poodinis : DependencyContainer, existingInstance;

    private class StubLoader(T : ImageLoader) : T {
        public bool loadWasCalled = false;
        public Image image;

        public override Image load(File imageFile) {
            loadWasCalled = true;
            return image;
        }
    }

    private void registerStub(T : ImageLoader)(shared DependencyContainer dependencies) {
        auto stub = new StubLoader!T();
        dependencies.register!T.existingInstance(stub);
    }

    private class Fixture {
        public PngImageLoader pngImageLoader;
        public CommonImageLoader commonImageLoader;

        this() {
            auto dependencies = new shared DependencyContainer();
            dependencies.registerStub!PngImageLoader;
            dependencies.register!CommonImageLoader;

            pngImageLoader = dependencies.resolve!PngImageLoader;
            commonImageLoader = dependencies.resolve!CommonImageLoader;
        }
    }

    private StubLoader!T stub(T : ImageLoader)(T loader) {
        return cast(StubLoader!T) loader;
    }

    @("Fails to load a file for which the extension is unknown")
    unittest {
        auto loader = new CommonImageLoader();
        auto file = new File("cube.notanimage");
        assertThrown!Exception(loader.load(file));
    }

    @("Load PNG image")
    unittest {
        auto f = new Fixture();
        auto image = new Image();
        f.pngImageLoader.stub.image = image;

        assert(f.commonImageLoader.load(new File("cat.png")) is image);
        assert(f.pngImageLoader.stub.loadWasCalled);
    }
}
