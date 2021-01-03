/**
 * Retrograde Engine
 *
 * Authors:
 *  Mike Bierlee, m.bierlee@lostmoment.com
 * Copyright: 2014-2021 Mike Bierlee
 * License:
 *  This software is licensed under the terms of the MIT license.
 *  The full terms of the license can be found in the LICENSE.txt file.
 */

module retrograde.model;

import retrograde.entity;

import std.exception;

interface Model {
    void loadIntoVram();
    void unloadFromVram();
    bool isLoadedIntoVram();
    void draw();
}

class ModelLoadException : Exception {
    mixin basicExceptionCtors;
}

class ModelComponent : EntityComponent {
    mixin EntityComponentIdentity!"ModelComponent";

    private Model _model;

    public @property Model model() {
        return _model;
    }

    this(Model model) {
        _model = model;
    }
}

class RenderableModelComponent : EntityComponent {
    mixin EntityComponentIdentity!"RenderableModelComponent";
}
