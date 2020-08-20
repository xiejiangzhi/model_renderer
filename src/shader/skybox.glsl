#pragma language glsl3

varying vec3 modelNormal;
varying vec4 fragColor;

#ifdef VERTEX
uniform mat4 projection_view_mat;

attribute vec3 ModelPos;
attribute vec3 ModelScale;
attribute vec4 ModelAlbedo;

vec4 position(mat4 transform_projection, vec4 vertex_position) {
  fragColor = ModelAlbedo;

  mat4 model_mat = mat4(
    ModelScale.x, 0, 0, 0,
    0, ModelScale.y, 0, 0,
    0, 0, ModelScale.z, 0,
    0, 0, 0, 1
  );
  vec4 world_pos = model_mat * vertex_position;
  world_pos = vec4(world_pos.xyz / world_pos.w + ModelPos, 0);
  vec4 proj_pos = projection_view_mat * world_pos;

  return proj_pos.xyww;
}
#endif

#ifdef PIXEL
vec4 effect(vec4 color, Image tex, vec2 texture_coords, vec2 screen_coords) {
  return Texel(tex, texture_coords) * color * fragColor;
}
#endif
