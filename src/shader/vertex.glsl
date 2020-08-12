#pragma language glsl3

varying vec3 modelNormal;
varying vec3 fragPos;
varying vec4 fragAlbedo;
varying vec4 fragPhysics;
varying vec3 shadowPos;

uniform mat4 projection_mat;
uniform mat4 view_mat;

uniform mat4 light_projection_mat;
uniform mat4 light_view_mat;

attribute vec3 VertexNormal;
attribute vec3 ModelPos;
attribute vec3 ModelAngle;
attribute vec3 ModelScale;
attribute vec4 ModelAlbedo;
attribute vec4 ModelPhysics;

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

mat4 transform_mat(vec3 angle, vec3 scale) {
  mat4 r = rotate_mat(angle.x, vec3(1, 0, 0))
    * rotate_mat(angle.y, vec3(0, 1, 0))
    * rotate_mat(angle.z, vec3(0, 0, 1));
  mat4 s = mat4(
    scale.x, 0, 0, 0,
    0, scale.y, 0, 0,
    0, 0, scale.z, 0,
    0, 0, 0, 1
  );

  return s * r;
}

vec4 position(mat4 transform_projection, vec4 vertex_position) {
  mat4 model_mat = transform_mat(ModelAngle, ModelScale);
  modelNormal = mat3(transpose(inverse(model_mat))) * VertexNormal;

  vec4 mpos = model_mat * vertex_position;
  vec4 worldPos = vec4(mpos.xyz / mpos.w + ModelPos, 1.0);
  fragPos = worldPos.xyz;
  /* fragColor = ModelColor; */
  fragAlbedo = ModelAlbedo;
  fragPhysics = ModelPhysics;

  vec4 light_pos = light_projection_mat * (light_view_mat * worldPos);
  // -1 - 1 to 0 - 1
  shadowPos = light_pos.xyz / light_pos.w * 0.5 + 0.5;

  return projection_mat * (view_mat * worldPos);
}

