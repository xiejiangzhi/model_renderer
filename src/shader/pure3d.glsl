#pragma language glsl3

#define PI 3.14159265359

varying vec3 fragPos;
varying vec4 fragAlbedo;

uniform vec3 ambient_color;
uniform vec3 light_pos;
uniform vec3 light_color;
uniform vec3 camera_pos;

#define ao 1.0

uniform DepthImage shadow_depth_map;

// ----------------------------------------------------------------------------

vec4 effect(vec4 color, Image tex, vec2 texture_coords, vec2 screen_coords) {
  vec4 tex_color = Texel(tex, texture_coords);
  vec4 tcolor = tex_color * fragAlbedo;
  light_pos;
  light_color;
  camera_pos;
  ambient_color;

  gl_FragDepth = (tcolor.a > 0) ? gl_FragCoord.z : 1;
  return tcolor;
}

