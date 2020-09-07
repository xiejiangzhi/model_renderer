#pragma language glsl3

uniform vec2 Resolution;
uniform bool use_fxaa;

#include_glsl fxaa.glsl

vec4 effect(vec4 vcolor, Image tex, vec2 tex_coords, vec2 screen_coords) {
  vec4 color = use_fxaa ? applyFXAA(tex, tex_coords, Resolution) : Texel(tex, tex_coords);
  return color * vcolor;
}
