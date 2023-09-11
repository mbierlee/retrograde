/**
 * Retrograde Engine
 *
 * A GL API is a generic interface for graphics library APIs.
 * It does NOT neccesarily mean "OpenGL".
 *
 * Authors:
 *  Mike Bierlee, m.bierlee@lostmoment.com
 * Copyright: 2014-2023 Mike Bierlee
 * License:
 *  This software is licensed under the terms of the MIT license.
 *  The full terms of the license can be found in the LICENSE.txt file.
 */

module retrograde.engine.glapi;

version (OpenGLES3) {
    public import retrograde.engine.opengles3;
}

version (UnitTesting) {
    import retrograde.engine.entity : Entity;
    import retrograde.engine.rendering : RenderPass, Color;

    import retrograde.std.memory : SharedPtr;

    uint compileShaderProgram(string name, string vertexShader, string fragmentShader) {
        return 0;
    }

    void loadEntityModel(SharedPtr!Entity entity) {
    }

    void unloadEntityModel(SharedPtr!Entity entity) {
    }

    void setClearColor(Color color) {
    }

    void initFrame() {
    }

    void drawModel(SharedPtr!Entity entity, const ref RenderPass renderPass) {
    }
}

//TODO: implement for other platforms
