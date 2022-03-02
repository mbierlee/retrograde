#version 460 core

layout(location = 0) in vec4 position;

layout(location = 1) uniform mat4 modelViewProjectionMatrix;

void main() {
    gl_Position = modelViewProjectionMatrix * position;
}