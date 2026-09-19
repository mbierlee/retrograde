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

version (MaxLights0) {
    /// Amount of dynamic forward-rendered lights a material can be lit by. Zero disables them.
    enum maxLights = 0;
    private enum maxLightsValue = "0";
} else version (MaxLights4) {
    enum maxLights = 4;
    private enum maxLightsValue = "4";
} else version (MaxLights8) {
    enum maxLights = 8;
    private enum maxLightsValue = "8";
} else version (MaxLights16) {
    enum maxLights = 16;
    private enum maxLightsValue = "16";
} else version (MaxLights32) {
    enum maxLights = 32;
    private enum maxLightsValue = "32";
} else {
    // Without an explicit choice a modest light budget is assumed, matching MaxLights8.
    enum maxLights = 8;
    private enum maxLightsValue = "8";
}

version (MaxShadowViews0) {
    private enum requestedMaxShadowViews = 0;
} else version (MaxShadowViews1) {
    private enum requestedMaxShadowViews = 1;
} else version (MaxShadowViews4) {
    private enum requestedMaxShadowViews = 4;
} else version (MaxShadowViews8) {
    private enum requestedMaxShadowViews = 8;
} else version (MaxShadowViews16) {
    private enum requestedMaxShadowViews = 16;
} else {
    // Enough for a sun and one point light, which is the scene most games start from.
    private enum requestedMaxShadowViews = 8;
}

/**
 * Shadow maps a frame can render, which is not the same as lights that can cast: a point
 * light needs six, one per cube face, while a directional or spot light needs one.
 *
 * Zero disables shadows entirely - no pass, no uniforms, no maps allocated. Lights with
 * nothing to shade are pointless, so a build without lights has no shadows either.
 */
static if (maxLights > 0) {
    enum maxShadowViews = requestedMaxShadowViews;
} else {
    enum maxShadowViews = 0;
}

private enum maxShadowViewsValue = toShaderValue!maxShadowViews;

private template toShaderValue(int value) {
    private string run() {
        if (value == 0) {
            return "0";
        }

        string digits;
        int remaining = value;
        while (remaining > 0) {
            digits = cast(char)('0' + (remaining % 10)) ~ digits;
            remaining /= 10;
        }

        return digits;
    }

    enum toShaderValue = run();
}

enum pbrVertexShader = preprocess!(
        import("opengles3/material_pbr_metallic_roughness_vertex.glsl"),
        "maxLights", maxLightsValue,
        "maxShadowViews", maxShadowViewsValue
    );

enum pbrFragmentShader = preprocess!(
        import("opengles3/material_pbr_metallic_roughness_fragment.glsl"),
        "maxLights", maxLightsValue,
        "maxShadowViews", maxShadowViewsValue
    );

MaterialShader pbrMetallicRoughnessMaterialShader = MaterialShader(
    "PbrMetallicRoughness",
    MaterialType.pbrMetallicRoughness,
    pbrVertexShader,
    pbrFragmentShader,
);

enum lambertVertexShader = preprocess!(
        import("opengles3/material_lambert_vertex.glsl"),
        "maxLights", maxLightsValue,
        "maxShadowViews", maxShadowViewsValue
    );

enum lambertFragmentShader = preprocess!(
        import("opengles3/material_lambert_fragment.glsl"),
        "maxLights", maxLightsValue,
        "maxShadowViews", maxShadowViewsValue
    );

/**
 * Purely diffuse lit material.
 *
 * There is no glTF material that maps onto this, so `rgmodelconv` never infers it: a model
 * ends up on this shader only when its material asks for it by name, through the `rg_mat`
 * property described in `docs/blender-material-guide.md`.
 */
MaterialShader lambertMaterialShader = MaterialShader(
    "Lambert",
    MaterialType.lambert,
    lambertVertexShader,
    lambertFragmentShader,
);

/**
 * Substitutes <%name%> placeholders in a shader source at compile time.
 *
 * Replacements are given as name/value pairs: preprocess!(source, "test", "1").
 */
template preprocess(string contents, replacements...) {
    private string replace(string haystack, string needle, string replacement) {
        string result;
        size_t i = 0;
        while (i < haystack.length) {
            if (i + needle.length <= haystack.length && haystack[i .. i + needle.length] == needle) {
                result ~= replacement;
                i += needle.length;
            } else {
                result ~= haystack[i];
                i++;
            }
        }

        return result;
    }

    private string run() {
        string result = contents;
        static foreach (i, r; replacements) {
            static if (i % 2 == 0) {
                result = replace(result, "<%" ~ r ~ "%>", replacements[i + 1]);
            }
        }

        return result;
    }

    enum preprocess = run();
}
