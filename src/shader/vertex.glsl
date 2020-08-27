#pragma language glsl3

varying vec3 modelNormal;
varying vec3 fragPos;
varying vec4 fragAlbedo;
varying vec4 fragPhysics;
varying vec3 lightProjPos;

uniform mat4 projection_view_mat;
uniform mat4 light_proj_view_mat;
uniform float y_flip = 1;

attribute vec3 VertexNormal;
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
  modelNormal = mat3(transpose(inverse(model_mat))) * VertexNormal;

  vec4 mpos = model_mat * vertex_position;
  vec4 worldPos = vec4(mpos.xyz / mpos.w + ModelPos, 1.0);
  fragPos = worldPos.xyz;
  fragAlbedo = ModelAlbedo;
  fragPhysics = ModelPhysics;

  vec4 light_proj_pos = light_proj_view_mat * worldPos;
  // -1 - 1 to 0 - 1
  lightProjPos = light_proj_pos.xyz / light_proj_pos.w * 0.5 + 0.5;

  /* return projection_view_mat * worldPos; */
  vec4 r = projection_view_mat * worldPos;
  r.y *= y_flip;
  return r;
}

