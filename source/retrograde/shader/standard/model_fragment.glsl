#version 460 core

out vec4 color;

layout(location = 3) uniform bool hasTexture;
layout(location = 4) uniform sampler2D albedo;
layout(location = 6) uniform bool renderDepthBuffer;
layout(location = 9) uniform float near;
layout(location = 10) uniform float far;

in VS_OUT {
    vec4 color;
    vec3 textureCoords;
} fs_in;

float linearizeDepth(float depth) {
    float z = depth * 2.0 - 1.0;
    return (2.0 * near * far) / (far + near - z * (far - near));
}

void main() {
    if(far == 0) {
        gl_FragDepth = gl_FragCoord.z; //TODO: don't write to when not needed by importing from lib. For pre-Z optimization.
    } else {
        gl_FragDepth = linearizeDepth(gl_FragCoord.z) / far;
    }

    if(renderDepthBuffer) {
        color = vec4(vec3(gl_FragDepth), 1.0);
    } else if(hasTexture) {
        color = texture(albedo, vec2(fs_in.textureCoords.x, -fs_in.textureCoords.y)) * fs_in.color;
    } else {
        color = fs_in.color;
    }
}
