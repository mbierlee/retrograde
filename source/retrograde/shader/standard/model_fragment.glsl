#version 460 core

out vec4 color;

layout(location = 3) uniform bool hasTexture;
layout(location = 4) uniform sampler2D albedo;
layout(location = 6) uniform bool renderDepthBuffer;

in VS_OUT {
    vec4 color;
    vec3 textureCoords;
} fs_in;

void main() {
    if(renderDepthBuffer) {
        color = vec4(vec3(gl_FragCoord.z), 1.0);
    } else if(hasTexture) {
        color = texture(albedo, vec2(fs_in.textureCoords.x, -fs_in.textureCoords.y)) * fs_in.color;
    } else {
        color = fs_in.color;
    }
}
