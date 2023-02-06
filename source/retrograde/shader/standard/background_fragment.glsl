#version 460 core

out vec4 color;

layout(location = 3) uniform bool hasTexture;
layout(location = 4) uniform sampler2D albedo;
layout(location = 6) uniform bool renderDepthBuffer;
layout(location = 7) uniform bool hasDepthMap;
layout(location = 8) uniform sampler2DShadow depthMap;

in VS_OUT {
    vec4 color;
    vec2 textureCoords;
} fs_in;

void main() {
    float fragDepth = hasDepthMap ? texture(depthMap, vec3(fs_in.textureCoords.x - 1, -fs_in.textureCoords.y - 1, 1) / 2, 0) : 1.0;
    gl_FragDepth = fragDepth;

    if(renderDepthBuffer) {
        color = vec4(vec3(fragDepth), 1.0);
    } else if(hasTexture) {
        color = texture(albedo, vec2(fs_in.textureCoords.x - 1, -fs_in.textureCoords.y - 1) / 2, 0);
    } else {
        color = fs_in.color;
    }
}