#pragma language glsl3

uniform vec2 Resolution;

#include_glsl fxaa.glsl

vec4 effect(vec4 vcolor, Image tex, vec2 tex_coords, vec2 screen_coords) {
  vec4 color = FXAA(tex, tex_coords, Resolution);
  /* vec4 color = Texel(tex, tex_coords); */
  return color * vcolor;
}
