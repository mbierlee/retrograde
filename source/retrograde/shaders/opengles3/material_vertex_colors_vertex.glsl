#version 300 es

layout(location = 0) in vec4 position;
layout(location = 1) in vec4 color;

uniform mat4 modelViewProjectionMatrix;

out vec4 vertexColor;

void main() {
  gl_Position = modelViewProjectionMatrix * position;
  vertexColor = color;
}
