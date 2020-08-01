#pragma language glsl3

mat4 rotate_mat(float angle, vec3 axis) {
  float l = length(axis);
	float x = axis.x / l, y = axis.y / l, z = axis.z / l;
	float c = cos(angle);
	float s = sin(angle);

  return mat4(
    x * x * (1 - c) + c, y * x * (1 - c) + z * s, x * z * (1 - c) - y * s, 0,
    x * y * (1 - c) - z * s, y * y * (1 - c) + c, y * z * (1 - c) + x * s, 0,
    x * z * (1 - c) + y * s, y * z * (1 - c) - x * s, z * z * (1 - c) + c, 0,
    0, 0, 0, 1
  );
}

mat4 transform_mat(vec3 angle, float scale) {
  mat4 r = rotate_mat(angle.x, vec3(1, 0, 0))
    * rotate_mat(angle.y, vec3(0, 1, 0))
    * rotate_mat(angle.z, vec3(0, 0, 1));
  mat4 s = mat4(
    scale, 0, 0, 0,
    0, scale, 0, 0,
    0, 0, scale, 0,
    0, 0, 0, 1
  );

  return s * r;
}


#ifdef VERTEX
uniform mat4 projection_mat;
uniform mat4 view_mat;
uniform mat4 model_mat;

attribute vec3 ModelPos;
attribute vec3 ModelAngle;
attribute float ModelScale;

vec4 position(mat4 transform_projection, vec4 vertex_position) {
  mat4 model_mat = transform_mat(ModelAngle, ModelScale);
  vec4 pos = model_mat * vertex_position;
  pos.xyz += ModelPos;
  return projection_mat * (view_mat * pos);
}
#endif

#ifdef PIXEL
void effect() {
  /* gl_FragDepth = gl_FragCoord.z; */
}
#endif
