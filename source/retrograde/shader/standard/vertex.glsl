#version 460 core
layout(location = 0) in vec4 offset;
layout(location = 1) in vec4 color;

out VS_OUT {
    vec4 color;
} vsOut;

void main() {
    const vec4 vertices[3] = vec4[3] (vec4(0.25, 0.25, 0.5, 1.0), vec4(-0.25, -0.25, 0.5, 1.0), vec4(0.25, -0.25, 0.5, 1.0));
    const vec4 colors[3] = vec4[3] (vec4(1.0, 0.0, 0.0, 1.0), vec4(0.0, 1.0, 0.0, 1.0), vec4(0.0, 0.0, 1.0, 1.0));

    gl_Position = vertices[gl_VertexID] + offset;
    vsOut.color = colors[gl_VertexID];
}