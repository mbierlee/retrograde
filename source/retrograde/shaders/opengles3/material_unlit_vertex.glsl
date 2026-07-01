#version 300 es

layout(location = 0) in vec4 position;
layout(location = 1) in vec2 textureCoords;

uniform mat4 modelViewProjectionMatrix;

out vec2 vertexTextureCoords;

void main() {
  gl_Position = modelViewProjectionMatrix * position;
  vertexTextureCoords = textureCoords;
}
