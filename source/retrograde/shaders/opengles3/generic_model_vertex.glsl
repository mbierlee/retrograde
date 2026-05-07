#version 300 es

layout(location = 0) in vec4 position;
layout(location = 1) in vec4 color;
layout(location = 2) in vec2 texCoord0;

uniform mat4 modelViewProjectionMatrix;

out vec4 vertexColor;
out vec2 fragTexCoord0;

void main() {
  gl_Position = modelViewProjectionMatrix * position;
  vertexColor = color;
  fragTexCoord0 = texCoord0;
}