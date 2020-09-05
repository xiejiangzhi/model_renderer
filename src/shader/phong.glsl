#pragma language glsl3

#define PI 3.14159265359
#define ao 1.0

varying vec3 modelNormal;
varying vec3 fragPos;
varying vec4 fragAlbedo;
varying vec4 fragPhysics;
varying vec3 lightProjPos;

uniform vec3 ambient_color;
uniform vec3 light_pos;
uniform vec3 light_color;
uniform vec3 cameraPos;

vec3 shadow_bias = vec3(0, 0, -0.003);

vec3 complute_light(
  vec3 normal, vec3 light_dir, vec3 view_dir, vec3 radiance,
  vec3 albedo, float roughness, float metallic
) {
  float diff = max(dot(light_dir, normal), 0.0) * (1 - metallic);
  vec3 diffuse = diff * radiance;

  vec3 halfway_dir = normalize(light_dir + view_dir);  
  float spec = pow(max(dot(normal, halfway_dir), 0.0), 32.0) * (1 - roughness);
  vec3 specular = radiance * albedo * spec; // assuming bright white light color

  return diffuse + specular;
}

#include_glsl calc_shadow.glsl

// ----------------------------------------------------------------------------

vec4 effect(vec4 color, Image tex, vec2 texture_coords, vec2 screen_coords) {
  vec4 tex_color = Texel(tex, texture_coords);
  if (tex_color.a == 0) { discard; }

  vec3 light = vec3(0);
  vec3 normal = normalize(modelNormal);
  vec3 light_dir = normalize(light_pos - fragPos);
  vec3 view_dir = normalize(cameraPos - fragPos);

  float roughness = fragPhysics.x;
  float metallic = fragPhysics.y;
  vec3 albedo = tex_color.rgb * tex_color.a * fragAlbedo.rgb;

  float distance = length(light_pos - fragPos) * 0.1;
  float attenuation = 1.0 / (distance * distance);
  vec3 radiance = light_color * attenuation;

  light += complute_light(
    normal, light_dir, view_dir, radiance / (radiance + vec3(1.0)), albedo, roughness, metallic
  );

  // shadow
  float shadow = calc_shadow(lightProjPos + shadow_bias);

  vec3 ambient = ambient_color * albedo * ao;
  vec3 tcolor = ambient + light * (1 - shadow);

  return vec4(tcolor, tex_color.a * fragAlbedo.a);
}

