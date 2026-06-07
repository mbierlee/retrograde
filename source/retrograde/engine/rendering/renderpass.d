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
import retrograde.engine.graphicsapi : drawModel;
import retrograde.engine.rendering : RenderPass;

import retrograde.std.math : Matrix4;

RenderPass genericModelRenderPass = RenderPass(
    "renderpass_generic_model",
    import("opengles3/renderpass_genericmodel_vertex.glsl"),
    import("opengles3/renderpass_genericmodel_fragment.glsl"),
    ModelComponentType,
    (EntityId entity, const ref RenderPass renderPass, const ref Matrix4 viewProjectionMatrix) {
    drawModel(entity, renderPass, viewProjectionMatrix);
}
);
