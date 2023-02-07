vec4 createOutputColor(bool renderDepthBuffer, bool hasTexture, float fragDepth, sampler2D albedo, vec2 texCoords, vec4 vertexColor) {
    if(renderDepthBuffer) {
        return vec4(vec3(fragDepth), 1.0);
    } else if(hasTexture) {
        return texture(albedo, texCoords, 0) * vertexColor;
    } else {
        return vertexColor;
    }
}
