#pragma language glsl3

varying vec3 cubeCoords;

#ifdef VERTEX
uniform mat4 projViewMat;
uniform float y_flip = 1;

vec4 position(mat4 transform_projection, vec4 vertex_position) {
  cubeCoords = normalize(vertex_position.xyz);
  vec4 proj_pos = projViewMat * vertex_position;
  proj_pos.y *= y_flip;
  return proj_pos.xyww;
}
#endif

#ifdef PIXEL
uniform CubeImage skybox;

vec4 effect(vec4 color, Image tex, vec2 texture_coords, vec2 screen_coords) {
  return Texel(skybox, cubeCoords);
}
#endif
