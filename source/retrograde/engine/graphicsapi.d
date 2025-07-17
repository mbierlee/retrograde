/**
 * Retrograde Engine
 *
 * A GL API is a generic interface for graphics library APIs.
 * It does NOT neccesarily mean "OpenGL".
 *
 * Authors:
 *  Mike Bierlee, m.bierlee@lostmoment.com
 * Copyright: 2014-2025 Mike Bierlee
 * License:
 *  This software is licensed under the terms of the MIT license.
 *  The full terms of the license can be found in the LICENSE.txt file.
 */

module retrograde.engine.graphicsapi;

version (OpenGLES3) {
    public import retrograde.api.opengles3;
}

version (UnitTesting) {
    import retrograde.engine.entity : EntityId, EntityManager;
    import retrograde.engine.rendering : RenderPass, Color, Viewport;

    import retrograde.std.math : Matrix4D;
    import retrograde.std.memory : SharedPtr;

    void initRenderApi() {
    }

    void initRenderPass(ref RenderPass renderPass) {
    }

    void loadEntityModel(ref EntityManager entityManager, EntityId entityId) {
    }

    void unloadEntityModel(ref EntityManager entityManager, EntityId entityId) {
    }

    void setClearColor(Color color) {
    }

    void initFrame() {
    }

    void useRenderPassShaderProgram(ref RenderPass renderPass) {
    }

    void clearShaderProgram() {
    }

    void drawModel(ref EntityManager entityManager, EntityId entityId, const ref Matrix4D viewProjectionMatrix, const ref RenderPass renderPass) {
    }

    Viewport getViewport() {
        return Viewport();
    }
}
