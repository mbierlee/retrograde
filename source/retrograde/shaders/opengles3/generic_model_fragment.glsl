#version 300 es

precision highp float;

in vec4 vertexColor;

out vec4 outColor;

void main() {
  outColor = vertexColor;
}