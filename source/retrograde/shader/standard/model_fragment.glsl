#version 460 core
// Fragment Shader

#include "globals.glsl"
#include "common_fragment.glsl"

out vec4 color;

layout(location = 3) uniform bool hasTexture;
layout(location = 4) uniform sampler2D albedo;
layout(location = 6) uniform bool renderDepthBuffer;
layout(location = 9) uniform float near;
layout(location = 10) uniform float far;

in VS_OUT {
    vec4 color;
    vec3 textureCoords;
} fs_in;

#if USE_LINEAR_DEPTH_TESTING
float linearizeDepth(float depth) {
    float z = depth * 2.0 - 1.0;
    return (2.0 * near * far) / (far + near - z * (far - near));
}
#endif

void main() {
    #if USE_LINEAR_DEPTH_TESTING
    if(far == 0) {
        gl_FragDepth = gl_FragCoord.z;
    } else {
        gl_FragDepth = linearizeDepth(gl_FragCoord.z) / far;
    }
    #endif

    vec2 texCoords = vec2(fs_in.textureCoords.x, -fs_in.textureCoords.y);
    color = createOutputColor(renderDepthBuffer, hasTexture, gl_FragDepth, albedo, texCoords, fs_in.color);
}
