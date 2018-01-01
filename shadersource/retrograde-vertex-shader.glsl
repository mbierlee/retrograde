#version 450 core
//VERTEX SHADER

/* Retrograde Engine
 * Copyright 2014-2018 Mike Bierlee
 * This software is licensed under the terms of the MIT license.
 * The full terms of the license can be found in the LICENSE.txt file.
 */

layout (location = 0) in vec4 position;
layout (location = 1) in vec4 color;
layout (location = 2) in vec2 uvCoordinate;

uniform RetrogradeModelstate {
    mat4 modelViewProjection;
    bool isTextured;
} modelState;

out VS_OUT {
    vec2 uvCoordinate;
    vec4 color;
} vs_out;

void main(void) {
    gl_Position = modelState.modelViewProjection * position;
    vs_out.uvCoordinate = uvCoordinate;
    vs_out.color = color;
}
