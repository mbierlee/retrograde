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

module retrograde.model.gltf;

import retrograde.core.model : ModelLoader, Model, ModelParseException;
import retrograde.core.storage : File;
import retrograde.core.versioning : parseVersion;

import poodinis : Inject;

import std.json : parseJSON, JSONValue, JSONType;
import std.exception : enforce;

class GltfModelLoader : ModelLoader {
    @Inject
    private GltfJsonParser jsonParser;

    public Model load(File modelFile) {
        switch (modelFile.extension) {
        case ".gltf":
            return jsonParser.parse(modelFile);

        case ".glb":
            throw new Exception("The glTF binary format is not yet supported.");

        default:
            throw new Exception("Unrecognized glTF file extension: " ~ modelFile.extension);
        }
    }
}

private class GltfJsonParser {
    public Model parse(File modelFile) {
        auto json = parseJSON(modelFile.textData);
        assertVersionIsCompatible(json);

        throw new Exception("Work in progress");
    }

    private void assertVersionIsCompatible(JSONValue json) {
        enforce!ModelParseException("asset" in json, "The glTF file is missing the 'asset' property.");
        auto assetObject = json["asset"];

        enforce!ModelParseException(assetObject.type == JSONType.object && "version" in assetObject, "The glTF file is missing the 'version' property.");
        auto versionProperty = assetObject["version"];

        enforce!ModelParseException(versionProperty.type == JSONType.string, "The glTF file has an invalid 'version' property.");
        auto versionString = versionProperty.get!string;
        auto versionNumber = parseVersion(versionString);

        if (versionNumber.major != 2) {
            throw new ModelParseException(
                "The glTF file has an incompatible version: " ~ versionString ~ ". Only version 2 is supported.");
        }
    }
}

version (unittest) {
    import retrograde.test.util : assertThrownMsg;

    import poodinis : DependencyContainer;

    private class TestFixture {
        private shared DependencyContainer container;

        this() {
            container = new shared DependencyContainer();
            container.register!GltfJsonParser;
            container.register!GltfModelLoader;
        }

        public GltfModelLoader modelLoader() {
            return container.resolve!GltfModelLoader;
        }
    }

    @("Parsing a glTF JSON file that has no or incorrect versions should fail")
    unittest {
        auto f = new TestFixture();
        void loadJson(string json) {
            auto modelFile = new File("empty.gltf", json);
            f.modelLoader.load(modelFile);
        }

        assertThrownMsg!ModelParseException(
            "The glTF file is missing the 'asset' property.",
            loadJson("{}"));

        assertThrownMsg!ModelParseException(
            "The glTF file is missing the 'version' property.",
            loadJson(`{"asset": {}}`));

        assertThrownMsg!ModelParseException(
            "The glTF file has an invalid 'version' property.",
            loadJson(`{"asset": {"version": 2}}`)); // Version is not a string

        assertThrownMsg!ModelParseException(
            "The glTF file has an incompatible version: 1.0.0. Only version 2 is supported.",
            loadJson(`{"asset": {"version": "1.0.0"}}`));
    }

    // @("Parse a simple glTF file")
    // unittest {
    //     enum fileName = "triangle.gltf";
    //     auto modelFile = new File(fileName, import(fileName));
    //     auto model = f.modelLoader.load(modelFile);
    // }
}
