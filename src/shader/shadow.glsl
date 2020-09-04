#pragma language glsl3

#ifdef VERTEX

uniform mat4 projViewMat;

attribute vec3 ModelPos;
attribute vec3 ModelAngle;
attribute vec3 ModelScale;

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
  vec4 pos = model_mat * vertex_position;
  pos = vec4((pos.xyz / pos.w) + ModelPos, 1);
  return projViewMat * pos;
}
#endif

#ifdef PIXEL
uniform Image MainTex;
uniform vec3 sun_dir;

void effect() {
  float a = Texel(MainTex, VaryingTexCoord.xy).a;
  if (a == 0) { discard; }
}
#endif
