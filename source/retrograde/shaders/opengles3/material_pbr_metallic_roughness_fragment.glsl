#version 300 es

precision highp float;

in vec2 vertexTextureCoords;

uniform sampler2D albedoTexture;

out vec4 outColor;

void main() {
  outColor = texture(albedoTexture, vertexTextureCoords);
}
