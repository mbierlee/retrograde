#version 300 es

#define MAX_LIGHTS <%maxLights%>

precision highp float;

in vec2 vertexTextureCoords;
in vec3 vertexWorldPosition;
in vec3 vertexWorldNormal;
in vec4 vertexWorldTangent;

uniform sampler2D albedoTexture;
uniform vec4 baseColorFactor;

// The two dials of the BRDF below. 0 metallic is a dielectric and 1 a raw metal; 0 roughness
// is a mirror and 1 fully diffuse. RGM range-checks neither, so the shader clamps them.
uniform float metallicFactor;
uniform float roughnessFactor;

// Both dials again, this time varying across the surface. Packed the way glTF packs them -
// roughness in green, metalness in blue - so a map exported for glTF is used as-is. The
// factors above multiply what it samples. Branched on a uniform like the normal map, since
// whether a mesh has one is a per-draw property rather than a second shader variant.
uniform sampler2D metallicRoughnessTexture;
uniform bool hasMetallicRoughnessMap;

// Shadowing baked into creases and contact points, in the red channel the map above leaves
// free - so this is often that same image sampled a second time. Attenuates only the ambient
// terms below: a light shining straight into a crease should still light it, which is what
// separates a baked occlusion map from a shadow.
uniform sampler2D occlusionTexture;
uniform bool hasOcclusionMap;

// 1 is the map at full strength, 0 ignores it.
uniform float occlusionStrength;

// Only the specular lobe needs it, to work out which way the surface reflects toward the eye.
uniform vec3 cameraWorldPosition;

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

const float PI = 3.14159265359;

// GGX collapses to a delta at zero roughness, which no finite number of point lights can hit.
// The perfect mirror a roughness of 0 asks for is approximated by the smallest lobe that still
// has width.
const float minAlpha = 0.002;

// Reflectance of a dielectric seen head-on. Roughly right for everything that is not a metal,
// which is why the metallic workflow gets away with not storing it.
const vec3 dielectricF0 = vec3(0.04);

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

// Trowbridge-Reitz: the share of microfacets standing square to the half vector, which is what
// makes a smooth surface concentrate its highlight and a rough one spread it out.
float distributionGGX(float NdotH, float alpha) {
  float a2 = alpha * alpha;
  float d = NdotH * NdotH * (a2 - 1.0) + 1.0;
  return a2 / (PI * d * d);
}

// Height-correlated Smith, already divided by the BRDF's 4 * NdotV * NdotL denominator - the two
// cancel, so pairing them saves the division and the near-grazing blow-up that comes with it.
float visibilitySmithGGX(float NdotV, float NdotL, float alpha) {
  float a2 = alpha * alpha;
  float lambdaV = NdotL * sqrt(NdotV * NdotV * (1.0 - a2) + a2);
  float lambdaL = NdotV * sqrt(NdotL * NdotL * (1.0 - a2) + a2);
  return 0.5 / max(lambdaV + lambdaL, 1e-5);
}

// Reflectance climbs toward white at grazing angles, on every material.
vec3 fresnelSchlick(vec3 f0, float VdotH) {
  return f0 + (1.0 - f0) * pow(1.0 - VdotH, 5.0);
}

// Analytic fit (Karis) of the split-sum specular integral, standing in for the BRDF lookup
// table a real IBL setup would sample. Returns the scale and bias to apply to F0.
vec2 environmentBrdfApprox(float roughness, float NdotV) {
  const vec4 c0 = vec4(-1.0, -0.0275, -0.572, 0.022);
  const vec4 c1 = vec4(1.0, 0.0425, 1.04, -0.04);
  vec4 r = roughness * c0 + c1;
  float a004 = min(r.x * r.x, exp2(-9.28 * NdotV)) * r.x + r.y;
  return vec2(-1.04, 1.04) * a004 + r.zw;
}

//TODO: The ambient half of this shader still fakes its environment. Still to do:
//      - Environment mapping: a reflection probe or cubemap to sample along the reflection
//        vector, instead of the two-color hemisphere below. As it stands a mirror-smooth
//        surface reflects a sky/ground gradient rather than the scene around it.
//      - Full IBL on top of that: SH irradiance, prefiltered radiance and a real BRDF lookup
//        replacing environmentBrdfApprox. The sky/ground pair is the first two bands of that
//        expansion, so the coefficients grow around it rather than replacing it.
void main() {
  vec4 albedo = texture(albedoTexture, vertexTextureCoords) * baseColorFactor;
  vec3 surfaceNormal = shadingNormal(normalize(vertexWorldNormal));

  // The map varies the pair across the surface and the factors scale what it holds, so a
  // material with a map still answers to its sliders. Without one the factors describe the
  // whole surface on their own.
  vec2 metallicRoughness = vec2(metallicFactor, roughnessFactor);
  if (hasMetallicRoughnessMap) {
    vec4 sampledMetallicRoughness = texture(metallicRoughnessTexture, vertexTextureCoords);
    metallicRoughness *= vec2(sampledMetallicRoughness.b, sampledMetallicRoughness.g);
  }

  float metallic = clamp(metallicRoughness.x, 0.0, 1.0);
  float roughness = clamp(metallicRoughness.y, 0.0, 1.0);
  float alpha = max(roughness * roughness, minAlpha);

  vec3 viewDirection = normalize(cameraWorldPosition - vertexWorldPosition);

  // Never quite zero: every term below divides by it somewhere.
  float NdotV = max(dot(surfaceNormal, viewDirection), 1e-4);

  // The metallic workflow in one pair of lines: a metal has no diffuse response and tints its
  // reflection with the base color, a dielectric keeps its diffuse and reflects a flat 4%.
  vec3 diffuseColor = albedo.rgb * (1.0 - metallic);
  vec3 f0 = mix(dielectricF0, albedo.rgb, metallic);

  // Interpolated toward 1 rather than scaled, so the strength dials the map out to an
  // unoccluded surface instead of down to a black one. This is glTF's formula.
  float occlusion = 1.0;
  if (hasOcclusionMap) {
    float sampledOcclusion = texture(occlusionTexture, vertexTextureCoords).r;
    occlusion = 1.0 + occlusionStrength * (sampledOcclusion - 1.0);
  }

  // Y-up: 1 where the surface looks straight up at the sky, 0 where it looks at the ground.
  // Deliberately not divided by PI, unlike the direct lighting below: the hemisphere is
  // already an irradiance approximation, which is what that PI came from.
  float skyFacing = surfaceNormal.y * 0.5 + 0.5;
  vec3 color = mix(ambientGroundRadiance, ambientSkyRadiance, skyFacing) * diffuseColor
               * occlusion;

  // The specular half of the same ambient. Sampled along the reflection rather than the
  // normal, so a smooth surface still picks a side of the hemisphere and a metal lit by
  // nothing else is not simply black.
  vec3 reflected = reflect(-viewDirection, surfaceNormal);
  vec3 ambientRadiance = mix(ambientGroundRadiance, ambientSkyRadiance, reflected.y * 0.5 + 0.5);
  vec2 environmentBrdf = environmentBrdfApprox(roughness, NdotV);
  color += ambientRadiance * (f0 * environmentBrdf.x + environmentBrdf.y) * occlusion;

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

    float NdotL = max(dot(surfaceNormal, lightDirection), 0.0);
    vec3 halfVector = normalize(lightDirection + viewDirection);
    float NdotH = max(dot(surfaceNormal, halfVector), 0.0);
    float VdotH = max(dot(viewDirection, halfVector), 0.0);

    // Cook-Torrance. What Fresnel reflects cannot also scatter diffusely, so the diffuse
    // term takes what is left of it - that is what keeps the surface from gaining energy at
    // grazing angles, where the reflection approaches white.
    vec3 fresnel = fresnelSchlick(f0, VdotH);
    vec3 specular = fresnel * distributionGGX(NdotH, alpha)
                    * visibilitySmithGGX(NdotV, NdotL, alpha);
    vec3 diffuse = (1.0 - fresnel) * diffuseColor / PI;

    vec3 radiance = lightColorIntensity[i].rgb * lightColorIntensity[i].a;
    color += (diffuse + specular) * radiance * NdotL * attenuation;
  }
#endif

  outColor = vec4(color, albedo.a);
}
