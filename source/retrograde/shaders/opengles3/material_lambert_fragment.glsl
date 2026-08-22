#version 300 es

#define MAX_LIGHTS <%maxLights%>

precision highp float;

in vec2 vertexTextureCoords;
in vec3 vertexWorldPosition;
in vec3 vertexWorldNormal;

uniform sampler2D albedoTexture;

#if MAX_LIGHTS > 0
// How many entries of the light arrays below are filled for this draw.
uniform int lightCount;

// xyz = world position, w = attenuation radius
uniform vec4 lightPositionRadius[MAX_LIGHTS];

// rgb = color, a = intensity
uniform vec4 lightColorIntensity[MAX_LIGHTS];
#endif

// Stands in for light arriving from everywhere, so faces turned away from every light are
// not pure black. Split into what arrives from above and what bounces back up from below, so
// that ambient light still varies with the way a surface faces: a single flat value lights
// every unlit face identically and erases their shape.
//
// Radiance rather than color: the ambient intensity is one dial over both, so it is already
// folded in by the time these arrive.
uniform vec3 ambientSkyRadiance;
uniform vec3 ambientGroundRadiance;

out vec4 outColor;

// Lambert diffuse: the albedo texture scaled by how squarely each light faces the surface.
// Purely diffuse by design - there is no specular term, and none is coming. A material that
// wants one belongs on pbrMetallicRoughness instead.
//
//TODO: Sample a tangent-space normal map instead of using the interpolated vertex normal
//      directly. Tangents are already in the RGM format but are neither uploaded nor used.
void main() {
  vec4 albedo = texture(albedoTexture, vertexTextureCoords);
  vec3 surfaceNormal = normalize(vertexWorldNormal);

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

    // Inverse-square falloff windowed so that it reaches exactly zero at the attenuation
    // radius: the renderer drops a light past its radius, and without the window that cut
    // would show up as a seam. The +1 keeps the light finite at its own position.
    float window = clamp(1.0 - pow(lightDistance / radius, 4.0), 0.0, 1.0);
    float attenuation = (window * window) / (lightDistance * lightDistance + 1.0);

    float lambert = max(dot(surfaceNormal, lightDirection), 0.0);
    vec3 radiance = lightColorIntensity[i].rgb * lightColorIntensity[i].a;
    color += albedo.rgb * radiance * lambert * attenuation;
  }
#endif

  outColor = vec4(color, albedo.a);
}
