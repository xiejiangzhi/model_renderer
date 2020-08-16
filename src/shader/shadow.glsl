#pragma language glsl3

#ifdef VERTEX

uniform mat4 projection_mat;
uniform mat4 view_mat;
uniform mat4 model_mat;

attribute vec3 ModelPos;
attribute vec3 ModelMatC1;
attribute vec3 ModelMatC2;
attribute vec3 ModelMatC3;

vec4 position(mat4 transform_projection, vec4 vertex_position) {
  mat4 model_mat = mat4(mat3(ModelMatC1, ModelMatC2, ModelMatC3));
  vec4 pos = model_mat * vertex_position;
  pos.xyz += ModelPos;
  return projection_mat * (view_mat * pos);
}
#endif

#ifdef PIXEL
uniform Image MainTex;

void effect() {
  float a = Texel(MainTex, VaryingTexCoord.xy).a;
  gl_FragDepth = (a > 0) ? gl_FragCoord.z : 1;
}
#endif
