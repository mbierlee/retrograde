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

module retrograde.engine.rendering.renderpass;

import retrograde.assets.model : ModelComponentType;

import retrograde.engine.entity : EntityId;
import retrograde.engine.graphicsapi : beginShadowView, drawModel, drawModelDepth, endShadowPass,
    syncShadowMapSize;
import retrograde.engine.rendering : RenderPass, RenderView;
import retrograde.engine.rendering.materialshader : maxShadowViews;
import retrograde.engine.rendering.shadow : prepareShadowViews;

import retrograde.std.collections : Array;

RenderPass genericModelRenderPass = RenderPass(
    "renderpass_generic_model",
    import("opengles3/renderpass_genericmodel_vertex.glsl"),
    import("opengles3/renderpass_genericmodel_fragment.glsl"),
    ModelComponentType,
    (EntityId entity, const ref RenderPass renderPass, const ref RenderView view) {
    drawModel(entity, renderPass, view);
}
);

static if (maxShadowViews > 0) {
    /**
     * Renders the scene's depth as each shadow-casting light sees it, into the shadow maps the
     * lit materials then sample.
     *
     * Belongs before any pass that draws lit surfaces, since a map has to be complete before
     * anything reads it. Registering it after one still works, but those surfaces sample the
     * previous frame's maps and their shadows lag a frame behind what casts them.
     *
     * Without this pass registered nothing casts: lights keep lighting, `Light.castsShadows`
     * is read by nothing, and no maps are allocated.
     */
    RenderPass shadowMapRenderPass = RenderPass(
        "renderpass_shadow_map",
        import("opengles3/renderpass_shadow_vertex.glsl"),
        import("opengles3/renderpass_shadow_fragment.glsl"),
        ModelComponentType,
        (EntityId entity, const ref RenderPass renderPass, const ref RenderView view) {
        drawModelDepth(entity, renderPass, view);
    },
        (ref Array!RenderView views) {
        // The maps are rebuilt here rather than where they are drawn into, so that a change
        // to their size lands before the first view of the frame binds one.
        syncShadowMapSize();
        prepareShadowViews(views);
    },
        (const ref RenderView view) { beginShadowView(view); },
        () { endShadowPass(); }
    );
}
