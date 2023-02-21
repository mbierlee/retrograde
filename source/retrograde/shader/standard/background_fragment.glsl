#version 460 core
// Fragment Shader

#include "common_fragment.glsl"

out vec4 fragColor;

layout(location = 3) uniform bool hasTexture;
layout(location = 4) uniform sampler2D albedo;
layout(location = 6) uniform bool renderDepthBuffer;
layout(location = 7) uniform bool hasDepthMap;
layout(location = 8) uniform sampler2DShadow depthMap;
layout(location = 11) uniform float defaultFragDepth;

in VS_OUT {
    vec4 color;
    vec2 textureCoords;
} fs_in;

void main() {
    float fragDepth = hasDepthMap ? texture(depthMap, vec3(fs_in.textureCoords.x - 1, -fs_in.textureCoords.y - 1, 1) / 2, 0) : defaultFragDepth;
    gl_FragDepth = fragDepth;

    vec2 texCoords = vec2(fs_in.textureCoords.x - 1, -fs_in.textureCoords.y - 1) / 2;
    vec4 color = createOutputColor(renderDepthBuffer, hasTexture, gl_FragDepth, albedo, texCoords, fs_in.color);
    if (color.a == 0) {
        discard;
    }

    fragColor = color;
}