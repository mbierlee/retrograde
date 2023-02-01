#version 460 core

out vec4 color;

layout(location = 3) uniform bool hasTexture;
layout(location = 4) uniform sampler2D albedo;

in VS_OUT {
    vec4 color;
    vec3 textureCoords;
} fs_in;

void main() {
    color = hasTexture ? texture(albedo, vec2(fs_in.textureCoords.x, -fs_in.textureCoords.y)) : fs_in.color;
}