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

module retrograde.engine.rendering.materialshader;

import retrograde.engine.rendering : MaterialShader;
import retrograde.assets.model : MaterialType;

MaterialShader vertexColorsMaterialShader = MaterialShader(
    "VertexColors",
    MaterialType.vertexColors,
    import("opengles3/material_vertex_colors_vertex.glsl"),
    import("opengles3/material_vertex_colors_fragment.glsl"),
);

MaterialShader unlitMaterialShader = MaterialShader(
    "Unlit",
    MaterialType.unlit,
    import("opengles3/material_unlit_vertex.glsl"),
    import("opengles3/material_unlit_fragment.glsl"),
);

MaterialShader pbrMetallicRoughnessMaterialShader = MaterialShader(
    "PbrMetallicRoughness",
    MaterialType.pbrMetallicRoughness,
    import("opengles3/material_pbr_metallic_roughness_vertex.glsl"),
    import("opengles3/material_pbr_metallic_roughness_fragment.glsl"),
);
