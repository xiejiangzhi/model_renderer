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

attribute vec3 ModelMatC1;
attribute vec3 ModelMatC2;
attribute vec3 ModelMatC3;

attribute vec4 ModelAlbedo;
attribute vec4 ModelPhysics;

vec4 position(mat4 transform_projection, vec4 vertex_position) {
  mat3 model_mat = mat3(ModelMatC1, ModelMatC2, ModelMatC3);
  modelNormal = transpose(inverse(model_mat)) * VertexNormal;

  vec4 mpos = mat4(model_mat) * vertex_position;
  vec4 worldPos = vec4(mpos.xyz / mpos.w + ModelPos, 1.0);
  fragPos = worldPos.xyz;
  fragAlbedo = ModelAlbedo;
  fragPhysics = ModelPhysics;

  vec4 light_pos = light_projection_mat * (light_view_mat * worldPos);
  // -1 - 1 to 0 - 1
  shadowPos = light_pos.xyz / light_pos.w * 0.5 + 0.5;

  return projection_mat * (view_mat * worldPos);
}

