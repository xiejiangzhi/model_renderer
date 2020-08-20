#pragma language glsl3

varying vec3 cubeCoords;

#ifdef VERTEX
uniform mat4 projection_view_mat;

vec4 position(mat4 transform_projection, vec4 vertex_position) {
  cubeCoords = normalize(vertex_position.xyz);
  vec4 proj_pos = projection_view_mat * vertex_position;
  return proj_pos.xyww;
}
#endif

#ifdef PIXEL
uniform CubeImage skybox;

vec4 effect(vec4 color, Image tex, vec2 texture_coords, vec2 screen_coords) {
  return Texel(skybox, cubeCoords);
}
#endif
