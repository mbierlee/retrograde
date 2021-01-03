#version 450 core
//FRAGMENT SHADER

/* Retrograde Engine
 * Copyright 2014-2021 Mike Bierlee
 * This software is licensed under the terms of the MIT license.
 * The full terms of the license can be found in the LICENSE.txt file.
 */

layout (binding = 0) uniform sampler2D textureSampler;

uniform RetrogradeModelstate {
    mat4 modelViewProjection;
    bool isTextured;
} modelState;

in VS_OUT {
    vec2 uvCoordinate;
    vec4 color;
} fs_in;

out vec4 color;

void main(void) {
    color = modelState.isTextured ? texture(textureSampler, fs_in.uvCoordinate) : fs_in.color;
}
