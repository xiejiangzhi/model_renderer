#pragma language glsl3

varying vec3 normal;
varying vec3 fragPos;
varying vec4 modelColor;

uniform vec3 ambient_color;
uniform vec3 light_pos;
uniform vec3 light_color;
uniform float diffuse_strength;
/* uniform float specular_strength; */
/* uniform vec3 view_pos; */

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

attribute vec3 VertexNormal;
attribute vec3 ModelPos;
attribute vec3 ModelAngle;
attribute float ModelScale;
attribute vec4 ModelColor;

vec4 position(mat4 transform_projection, vec4 vertex_position) {
  mat4 model_mat = transform_mat(ModelAngle, ModelScale);
  normal = mat3(transpose(inverse(model_mat))) * VertexNormal;

  vec4 pos = model_mat * vertex_position;
  pos.xyz += ModelPos;
  fragPos = vec3(pos);
  pos = view_mat * pos;
  modelColor = ModelColor;

  return projection_mat * pos;
}
#endif

/* const float specularStrength = 0.5; */
/* const vec3 specularColor = light_color * specularStrength; */

#ifdef PIXEL
vec4 effect(vec4 color, Image tex, vec2 texture_coords, vec2 screen_coords) {
  vec4 tcolor = Texel(tex, texture_coords) * modelColor;

  vec3 norm = normalize(normal);

  vec3 light_dir = normalize(light_pos - fragPos);
  float diff = max(dot(norm, light_dir), 1 - tcolor.a);
  vec3 diffuse = diff * light_color * diffuse_strength;

  /* vec3 view_dir = normalize(view_pos - fragPos); */
  /* vec3 reflect_dir = reflect(-light_dir, norm); */
  /* float spec = pow(max(dot(view_dir, reflect_dir), 0.0), 8 + 8 * tcolor.a); */
  /* vec3 specular = spec * light_color * specular_strength * tcolor.a; */

  tcolor.rgb *= ambient_color + diffuse;

  return tcolor * color;
}
#endif
