#version 460 core

out vec4 color;

layout(location = 3) uniform bool hasTexture;
layout(location = 4) uniform sampler2D albedo;

in VS_OUT {
    vec4 color;
    vec2 textureCoordinates;
} fs_in;

void main() {
    color = hasTexture ? texture(albedo, vec2(fs_in.textureCoordinates.x - 1, -fs_in.textureCoordinates.y - 1) / 2, 0) : fs_in.color;
}