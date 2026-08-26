#version 300 es

#define MAX_LIGHTS <%maxLights%>

precision highp float;

in vec2 vertexTextureCoords;
in vec3 vertexWorldPosition;
in vec3 vertexWorldNormal;
in vec4 vertexWorldTangent;

uniform sampler2D albedoTexture;
uniform vec4 baseColorFactor;

// A uniform branch rather than a second shader variant. Whether a mesh has a usable map
// depends on its tangents as well as its material, so the renderer decides per draw.
uniform sampler2D normalTexture;
uniform bool hasNormalMap;

// 1 is the map at full strength, 0 leaves the surface flat.
uniform float normalTextureScale;

#if MAX_LIGHTS > 0
// Entries filled in the arrays below; anything past it is stale.
uniform int lightCount;

// xyz = world position, w = attenuation radius
uniform vec4 lightPositionRadius[MAX_LIGHTS];

// rgb = color, a = intensity
uniform vec4 lightColorIntensity[MAX_LIGHTS];
#endif

// Light arriving from everywhere, so faces turned away from every light are not pure black.
// Split sky from ground so it still varies with facing - one flat value would erase the shape
// of every unlit face. Radiance, not color: the ambient intensity dial is already folded in.
uniform vec3 ambientSkyRadiance;
uniform vec3 ambientGroundRadiance;

out vec4 outColor;

// Interpolation leaves the tangent neither unit-length nor square to the normal, so it is
// re-orthogonalized first. The bitangent follows from the normal and tangent, so only its
// handedness is stored - which is what keeps mirrored UV islands shading correctly.
vec3 shadingNormal(vec3 interpolatedNormal) {
  if (!hasNormalMap) {
    return interpolatedNormal;
  }

  vec3 interpolatedTangent = vertexWorldTangent.xyz;
  vec3 tangent = normalize(interpolatedTangent - interpolatedNormal * dot(interpolatedNormal, interpolatedTangent));
  vec3 bitangent = cross(interpolatedNormal, tangent) * vertexWorldTangent.w;

  // Maps are stored with the [-1, 1] components biased into the [0, 1] the texture can hold.
  vec3 tangentSpaceNormal = texture(normalTexture, vertexTextureCoords).xyz * 2.0 - 1.0;

  // Scaling only the components along the surface tilts the normal back toward the geometric
  // one without changing which way it leans.
  tangentSpaceNormal *= vec3(normalTextureScale, normalTextureScale, 1.0);

  return normalize(mat3(tangent, bitangent, interpolatedNormal) * tangentSpaceNormal);
}

//TODO: The diffuse term below is plain Lambert, standing in for the metallic-roughness BRDF
//      this material is named after. Still to do:
//      - Cook-Torrance instead: GGX, Smith, Schlick Fresnel. Needs a view vector, so the
//        camera's world position has to come in as its own uniform.
//      - Metallic and roughness from uniforms, once an RGM material carries them.
//      - Full IBL instead of the hemisphere: SH irradiance, prefiltered radiance and a BRDF
//        lookup. The sky/ground pair is the first two bands of that expansion, so the
//        coefficients grow around it rather than replacing it.
void main() {
  vec4 albedo = texture(albedoTexture, vertexTextureCoords) * baseColorFactor;
  vec3 surfaceNormal = shadingNormal(normalize(vertexWorldNormal));

  // Y-up: 1 where the surface looks straight up at the sky, 0 where it looks at the ground.
  float skyFacing = surfaceNormal.y * 0.5 + 0.5;
  vec3 ambient = mix(ambientGroundRadiance, ambientSkyRadiance, skyFacing);
  vec3 color = ambient * albedo.rgb;

#if MAX_LIGHTS > 0
  for (int i = 0; i < lightCount; i++) {
    vec3 toLight = lightPositionRadius[i].xyz - vertexWorldPosition;
    float radius = lightPositionRadius[i].w;
    float lightDistance = length(toLight);
    vec3 lightDirection = lightDistance > 0.0 ? toLight / lightDistance : surfaceNormal;

    // Windowed to reach exactly zero at the radius: the renderer drops a light past it, and
    // an unwindowed falloff would show that cut as a seam. The +1 keeps the light finite at
    // its own position.
    float window = clamp(1.0 - pow(lightDistance / radius, 4.0), 0.0, 1.0);
    float attenuation = (window * window) / (lightDistance * lightDistance + 1.0);

    float lambert = max(dot(surfaceNormal, lightDirection), 0.0);
    vec3 radiance = lightColorIntensity[i].rgb * lightColorIntensity[i].a;
    color += albedo.rgb * radiance * lambert * attenuation;
  }
#endif

  outColor = vec4(color, albedo.a);
}
