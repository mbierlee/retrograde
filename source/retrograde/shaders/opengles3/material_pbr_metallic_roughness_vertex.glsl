#version 300 es

#define MAX_LIGHTS <%maxLights%>

layout(location = 0) in vec4 position;
layout(location = 1) in vec2 textureCoords;
layout(location = 2) in vec3 normal;
layout(location = 3) in vec4 tangent;

uniform mat4 modelViewProjectionMatrix;
uniform mat4 modelMatrix;

out vec2 vertexTextureCoords;
out vec3 vertexWorldPosition;
out vec3 vertexWorldNormal;
out vec4 vertexWorldTangent;

void main() {
  gl_Position = modelViewProjectionMatrix * position;
  vertexTextureCoords = textureCoords;
  vertexWorldPosition = (modelMatrix * position).xyz;

  //TODO: mat3(modelMatrix) skews normals under non-uniform scale. Upload a real normal
  //      matrix - the inverse transpose of the model matrix - as its own uniform instead.
  //      Normalized in the fragment stage, after interpolation.
  vertexWorldNormal = mat3(modelMatrix) * normal;

  // Tangents are directions along the surface, so unlike normals they transform with the
  // model matrix itself - the inverse transpose above would be wrong for them.
  vertexWorldTangent = vec4(mat3(modelMatrix) * tangent.xyz, tangent.w);
}
