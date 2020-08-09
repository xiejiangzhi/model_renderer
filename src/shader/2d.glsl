#pragma language glsl3

uniform mat4 tfp;

vec4 position(mat4 transform_projection, vec4 vertex_position) {
  return tfp * vertex_position;
}

vec4 effect(vec4 color, Image tex, vec2 texture_coords, vec2 screen_coords) {
  vec4 texturecolor = Texel(tex, texture_coords);
  return texturecolor * color;
}
