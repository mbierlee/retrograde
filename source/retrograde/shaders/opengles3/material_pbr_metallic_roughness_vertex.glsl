#version 300 es

#define MAX_LIGHTS <%maxLights%>

layout(location = 0) in vec4 position;
layout(location = 1) in vec2 textureCoords;
layout(location = 2) in vec3 normal;
layout(location = 3) in vec4 tangent;

uniform mat4 modelViewProjectionMatrix;
uniform mat4 modelMatrix;
uniform mat3 normalMatrix;

out vec2 vertexTextureCoords;
out vec3 vertexWorldPosition;
out vec3 vertexWorldNormal;
out vec4 vertexWorldTangent;

void main() {
  gl_Position = modelViewProjectionMatrix * position;
  vertexTextureCoords = textureCoords;
  vertexWorldPosition = (modelMatrix * position).xyz;

  // The model matrix would skew a normal off perpendicular under non-uniform scale; its
  // inverse transpose - the normal matrix - does not. Normalized after interpolation, in
  // the fragment stage.
  vertexWorldNormal = normalMatrix * normal;

  // Tangents run along the surface, so they take the model matrix itself - the normal
  // matrix would be wrong here.
  vertexWorldTangent = vec4(mat3(modelMatrix) * tangent.xyz, tangent.w);
}
