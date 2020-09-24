#pragma language glsl3

uniform Image DepthMap;

vec4 effect(vec4 vcolor, Image tex, vec2 tex_coords, vec2 screen_coords) {
  float depth = Texel(DepthMap, tex_coords).r;
  gl_FragDepth = depth;
  return vec4(0, 0, 0, 0);
}
