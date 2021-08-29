#version 460

in VS_OUT {
    vec4 color;
} fsIn;

out vec4 color;

void main() {
    color = fsIn.color;
}