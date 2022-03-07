#version 460 core

layout(location = 0) in vec4 position;
layout(location = 1) in vec4 color;

layout(location = 2) uniform mat4 modelViewProjectionMatrix;

out VS_OUT {
    vec4 color;
} vs_out;

void main() {
    gl_Position = modelViewProjectionMatrix * position;
    vs_out.color = color;
}