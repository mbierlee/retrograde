#version 300 es

#define MAX_LIGHTS <%maxLights%>
#define MAX_SHADOW_VIEWS <%maxShadowViews%>

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

// xyz = the direction the light travels, w = 1 when the light is directional
uniform vec4 lightDirection[MAX_LIGHTS];

#if MAX_SHADOW_VIEWS > 0
// x = first shadow map this light was rendered into, or -1 when it casts none this frame.
// y = how many maps it has: one for a directional light, six for a point light.
uniform vec4 lightShadowParams[MAX_LIGHTS];

// Every shadow map of the frame, one layer each. One array rather than a sampler per light
// because a sampler array cannot be indexed by the loop variable below.
//
// The precision qualifier is not optional: this sampler type has no default in ES 3.00, and
// a shader that leaves it off does not compile.
uniform highp sampler2DArrayShadow shadowMaps;

// Where each map looks from, already carrying the conversion from clip space to the [0, 1]
// a map is sampled over.
uniform mat4 shadowViewProjection[MAX_SHADOW_VIEWS];

// How far a lookup is pushed along the surface's own normal before it is projected, which is
// what keeps a surface from shadowing itself where the light grazes it.
uniform float shadowNormalBias;
#endif
#endif

// Light arriving from everywhere, so faces turned away from every light are not pure black.
// Split sky from ground so it still varies with facing - one flat value would erase the shape
// of every unlit face. Radiance, not color: the ambient intensity dial is already folded in.
uniform vec3 ambientSkyRadiance;
uniform vec3 ambientGroundRadiance;

out vec4 outColor;

const float PI = 3.14159265359;

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

#if MAX_LIGHTS > 0 && MAX_SHADOW_VIEWS > 0
// Which of a point light's six maps covers the given direction: the one whose axis it leans
// furthest along. The order is the one the renderer renders the faces in.
int cubeFaceOf(vec3 direction) {
  vec3 extent = abs(direction);
  if (extent.x >= extent.y && extent.x >= extent.z) {
    return direction.x > 0.0 ? 0 : 1;
  }

  if (extent.y >= extent.z) {
    return direction.y > 0.0 ? 2 : 3;
  }

  return direction.z > 0.0 ? 4 : 5;
}

// How much of a light reaches this surface: 1 where nothing blocks it, 0 in full shadow, and
// in between along an edge, where the comparison filter averaged what several of the map's
// texels had to say.
float shadowFactor(int lightIndex, vec3 worldPosition, vec3 surfaceNormal, float normalDotLight) {
  int firstView = int(lightShadowParams[lightIndex].x);
  if (firstView < 0) {
    return 1.0;
  }

  int view = firstView;
  if (lightShadowParams[lightIndex].y > 1.5) {
    view += cubeFaceOf(worldPosition - lightPositionRadius[lightIndex].xyz);
  }

  // Lifted off the surface before being projected, by more the more steeply the light grazes
  // it - which is exactly where a surface otherwise shadows itself.
  vec3 samplePosition = worldPosition + surfaceNormal * (shadowNormalBias * (1.0 - normalDotLight));
  vec4 lightSpacePosition = shadowViewProjection[view] * vec4(samplePosition, 1.0);
  if (lightSpacePosition.w <= 0.0) {
    return 1.0;
  }

  // By hand: there is no projecting lookup for this kind of sampler in ES 3.00.
  vec3 mapPosition = lightSpacePosition.xyz / lightSpacePosition.w;

  // Outside the map nothing was recorded that could block this surface, so it is lit. Beyond
  // the far plane too: that is past everything the map was built to cover.
  if (mapPosition.x < 0.0 || mapPosition.x > 1.0 ||
      mapPosition.y < 0.0 || mapPosition.y > 1.0 ||
      mapPosition.z > 1.0) {
    return 1.0;
  }

  return texture(shadowMaps, vec4(mapPosition.xy, float(view), mapPosition.z));
}
#endif

// Purely diffuse by design - no specular term, and none is coming. A material that wants one
// belongs on pbrMetallicRoughness instead, whose diffuse term is normalized the same way this
// one is: the two are meant to shade identically wherever that material's metallic factor is 0
// and only its specular lobe sets them apart.
void main() {
  vec4 albedo = texture(albedoTexture, vertexTextureCoords) * baseColorFactor;
  vec3 surfaceNormal = shadingNormal(normalize(vertexWorldNormal));

  // Y-up: 1 where the surface looks straight up at the sky, 0 where it looks at the ground.
  // Deliberately not divided by PI, unlike the direct lighting below: the hemisphere is
  // already an irradiance approximation, which is what that PI came from.
  float skyFacing = surfaceNormal.y * 0.5 + 0.5;
  vec3 ambient = mix(ambientGroundRadiance, ambientSkyRadiance, skyFacing);
  vec3 color = ambient * albedo.rgb;

#if MAX_LIGHTS > 0
  for (int i = 0; i < lightCount; i++) {
    vec3 toLightDirection;
    float attenuation;

    if (lightDirection[i].w > 0.5) {
      // Parallel rays from far enough away that neither the light's position nor the distance
      // to it means anything: every surface receives the whole of what it emits.
      toLightDirection = -normalize(lightDirection[i].xyz);
      attenuation = 1.0;
    } else {
      vec3 toLight = lightPositionRadius[i].xyz - vertexWorldPosition;
      float radius = lightPositionRadius[i].w;
      float lightDistance = length(toLight);
      toLightDirection = lightDistance > 0.0 ? toLight / lightDistance : surfaceNormal;

      // Windowed to reach exactly zero at the radius: the renderer drops a light past it, and
      // an unwindowed falloff would show that cut as a seam. The +1 keeps the light finite at
      // its own position.
      float window = clamp(1.0 - pow(lightDistance / radius, 4.0), 0.0, 1.0);
      attenuation = (window * window) / (lightDistance * lightDistance + 1.0);
    }

    float lambert = max(dot(surfaceNormal, toLightDirection), 0.0);
    vec3 radiance = lightColorIntensity[i].rgb * lightColorIntensity[i].a;

#if MAX_SHADOW_VIEWS > 0
    attenuation *= shadowFactor(i, vertexWorldPosition, surfaceNormal, lambert);
#endif

    // Energy-conserving: a diffuse surface spreads what it receives over the hemisphere, so
    // it reflects albedo/PI of it per direction rather than the whole of it.
    color += (albedo.rgb / PI) * radiance * lambert * attenuation;
  }
#endif

  outColor = vec4(color, albedo.a);
}
