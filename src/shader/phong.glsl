#pragma language glsl3

#define PI 3.14159265359

varying vec3 modelNormal;
varying vec3 fragPos;
varying vec4 fragAlbedo;
varying vec4 fragPhysics;
varying vec3 shadowPos;

uniform vec3 ambient_color;
uniform vec3 light_pos;
uniform vec3 light_color;
uniform vec3 camera_pos;

#define ao 1.0

uniform DepthImage shadow_depth_map;

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

// ----------------------------------------------------------------------------

vec4 effect(vec4 color, Image tex, vec2 texture_coords, vec2 screen_coords) {
  vec4 tex_color = Texel(tex, texture_coords);

  vec3 light = vec3(0);
  vec3 normal = normalize(modelNormal);
  vec3 light_dir = normalize(light_pos - fragPos);
  vec3 view_dir = normalize(camera_pos - fragPos);

  float roughness = fragPhysics.x;
  float metallic = fragPhysics.y;
  vec3 albedo = tex_color.rgb * tex_color.a * fragAlbedo.rgb;

  light += complute_light(normal, light_dir, view_dir, normalize(light_color), albedo, roughness, metallic);

  // shadow
  float shadow = 0;
  if (shadowPos.x >= 0 && shadowPos.x <= 1 && shadowPos.y >= 0 && shadowPos.y <= 1) {
    vec3 shadow_bias = vec3(0, 0, -0.003);

    // PCF
    vec2 tex_size = 1.0 / textureSize(shadow_depth_map, 0);
    for (int x = -1; x <= 1; ++x) {
      for (int y = -1; y <= 1; ++y) {
        shadow += texture(shadow_depth_map, shadowPos + vec3(vec2(x, y) * tex_size, 0) + shadow_bias);
      }
    }
    shadow /= 9.0;
  }

  vec3 ambient = ambient_color * albedo * ao;
  vec3 tcolor = ambient + light * (1 - shadow);

  // HDR tonemapping
  tcolor = tcolor / (tcolor + vec3(1.0));
  // gamma correct
  tcolor = pow(tcolor, vec3(1.0/2.2)); 

  gl_FragDepth = (tex_color.a > 0) ? gl_FragCoord.z : 1;
  return vec4(tcolor, tex_color.a * fragAlbedo.a);
}

