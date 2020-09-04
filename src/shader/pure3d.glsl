#pragma language glsl3

/* varying vec3 fragPos; */
varying vec4 fragAlbedo;

// ----------------------------------------------------------------------------

#ifdef VERTEX
uniform mat4 projViewMat;

attribute vec3 ModelPos;
attribute vec3 ModelAngle;
attribute vec3 ModelScale;
attribute vec4 ModelAlbedo;
attribute vec4 ModelPhysics;

#include_glsl transform_helper.glsl

vec4 position(mat4 transform_projection, vec4 vertex_position) {
  mat4 model_mat = transform_mat(ModelAngle, ModelScale);

  vec4 mpos = model_mat * vertex_position;
  vec4 worldPos = vec4(mpos.xyz / mpos.w + ModelPos, 1.0);
  fragAlbedo = ModelAlbedo;

  return projViewMat * worldPos;
}
#endif


#ifdef PIXEL

vec4 effect(vec4 color, Image tex, vec2 texture_coords, vec2 screen_coords) {
  vec4 tex_color = Texel(tex, texture_coords);
  vec4 tcolor = tex_color * fragAlbedo;
  if (tcolor.a == 0) { discard; }

  return tcolor;
}

#endif
