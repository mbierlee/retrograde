#version 300 es

precision highp float;

// Deliberately empty: this pass renders into a framebuffer that has only a depth attachment,
// and depth is written by the fixed-function stage from gl_Position alone. Anything written
// here would have nowhere to go.
void main() {
}
