/**
 * Retrograde Engine
 *
 * A GL API is a generic interface for graphics library APIs.
 * It does NOT neccesarily mean "OpenGL".
 *
 * Authors:
 *  Mike Bierlee, m.bierlee@lostmoment.com
 * Copyright: 2014-2026 Mike Bierlee
 * License:
 *  This software is licensed under the terms of the MIT license.
 *  The full terms of the license can be found in the LICENSE.txt file.
 */

module retrograde.engine.graphicsapi;

version (OpenGLES3) {
    public import retrograde.api.opengles3;
}

version (NoGraphicsApi) {
    import retrograde.engine.entity : EntityId;
    import retrograde.engine.rendering : RenderPass, Color, Viewport, MaterialShader;

    import retrograde.std.math : Matrix4;

    void initRenderApi() {
    }

    void initRenderPass(ref RenderPass renderPass) {
    }

    void initMaterialShader(ref MaterialShader materialShader) {
    }

    void loadEntityModel(EntityId entity) {
    }

    void unloadEntityModel(EntityId entity) {
    }

    void setClearColor(Color color) {
    }

    void initFrame() {
    }

    void useRenderPassShaderProgram(ref RenderPass renderPass) {
    }

    void clearShaderProgram() {
    }

    void drawModel(EntityId entity, const ref RenderPass renderPass, const ref Matrix4 viewProjectionMatrix) {
    }

    Viewport getViewport() {
        return Viewport();
    }
}
