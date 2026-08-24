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

  // Normals stand perpendicular to the surface instead of running along it, so the model
  // matrix would skew them under a non-uniform scale. The normal matrix - its inverse
  // transpose - is what keeps them perpendicular. Normalized in the fragment stage, after
  // interpolation.
  vertexWorldNormal = normalMatrix * normal;

  // Tangents are directions along the surface, so unlike normals they transform with the
  // model matrix itself - the normal matrix would be wrong for them.
  vertexWorldTangent = vec4(mat3(modelMatrix) * tangent.xyz, tangent.w);
}
