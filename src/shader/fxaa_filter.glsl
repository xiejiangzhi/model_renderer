#pragma language glsl3

uniform vec2 Resolution;

// 1 - 5
#define FXAA_PRESET 3

#include_glsl fxaa.glsl

vec4 effect(vec4 vcolor, Image tex, vec2 tex_coords, vec2 screen_coords) {
  float alpha = Texel(tex, tex_coords).a;
  return vec4(applyFXAA(tex, tex_coords, Resolution), alpha) * vcolor;
}
