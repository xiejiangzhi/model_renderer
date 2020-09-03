#pragma language glsl3

/* varying vec3 fragPos; */
varying vec4 fragAlbedo;

// ----------------------------------------------------------------------------

#ifdef VERTEX
uniform mat4 projection_view_mat;

attribute vec3 ModelPos;
attribute vec3 ModelAngle;
attribute vec3 ModelScale;
attribute vec4 ModelAlbedo;
attribute vec4 ModelPhysics;

mat3 rotate_mat(vec3 angle) {
  float c1 = cos(angle.z), s1 = sin(angle.z);
  float c2 = cos(angle.x), s2 = sin(angle.x);
  float c3 = cos(angle.y), s3 = sin(angle.y);

  return mat3(
    c1 * c3 - s1 * s2 * s3, c3 * s1 + c1 * s2 * s3, -c2 * s3,
    -c2 * s1, c1 * c2, s2,
    c1 * s3 + c3 * s1 * s2, s1 * s3 - c1 * c3 * s2, c2 * c3
  );
}

mat4 transform_mat(vec3 angle, vec3 scale) {
  mat3 m = rotate_mat(angle) * mat3(
    scale.x, 0, 0,
    0, scale.y, 0,
    0, 0, scale.z
  );
  return mat4(m);
}

vec4 position(mat4 transform_projection, vec4 vertex_position) {
  mat4 model_mat = transform_mat(ModelAngle, ModelScale);

  vec4 mpos = model_mat * vertex_position;
  vec4 worldPos = vec4(mpos.xyz / mpos.w + ModelPos, 1.0);
  fragAlbedo = ModelAlbedo;

  return projection_view_mat * worldPos;
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
