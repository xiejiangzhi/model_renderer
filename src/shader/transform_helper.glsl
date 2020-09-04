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

