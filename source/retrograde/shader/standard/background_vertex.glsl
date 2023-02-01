#version 460 core

layout(location = 0) in vec4 position;
layout(location = 1) in vec4 color;

out VS_OUT {
    vec4 color;
    vec2 textureCoords;
} vs_out;

void main() {
    gl_Position = position;
    vs_out.color = color;
    vs_out.textureCoords = position.xy;
}