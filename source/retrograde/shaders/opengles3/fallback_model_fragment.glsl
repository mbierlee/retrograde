#version 300 es

precision highp float;

out vec4 outColor;

void main() {
  vec4 colorA = vec4(0.54, 0.00, 0.47, 1.0);
  vec4 colorB = vec4(0.81, 0.19, 0.73, 1.0);

  ivec2 cell = ivec2(floor(gl_FragCoord.xy / 10.0));
  bool useAlt = ((cell.x + cell.y) & 1) == 1;
  outColor = useAlt ? colorB : colorA;
}
