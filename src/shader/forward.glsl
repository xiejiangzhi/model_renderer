#pragma language glsl3

#define PI 3.14159265359
#define ao 1.0
#define gamma 2.2


// ------------------------------------------------

varying vec3 modelNormal;
varying vec3 fragPos;
varying vec4 fragAlbedo;
varying vec4 fragPhysics;
varying vec3 lightProjPos;

uniform vec3 ambientColor;
uniform vec3 sunDir;
uniform vec3 sunColor;
uniform vec3 cameraPos;

const int MAX_LIGHTS = 32;
uniform vec3 lightsPos[MAX_LIGHTS];
uniform vec3 lightsColor[MAX_LIGHTS];
uniform float lightsLinear[MAX_LIGHTS];
uniform float lightsQuadratic[MAX_LIGHTS];
uniform float lightsCount;

uniform bool render_shadow = true;
uniform float shadow_bias = -0.003;

uniform bool use_skybox;

// ----------------------------------------------------------------------------

#include_glsl calc_shadow.glsl
#include_glsl pbr_light.glsl
#include_glsl skybox_light.glsl

// ----------------------------------------------------------------------------

vec4 effect(vec4 color, Image tex, vec2 texture_coords, vec2 screen_coords) {
  vec4 tex_color = Texel(tex, texture_coords);
  if (tex_color.a == 0) { discard; }

  vec3 normal = normalize(modelNormal);
  vec3 view_dir = normalize(cameraPos - fragPos);
  /* vec3 light_dir = normalize(light_pos - fragPos); */

  float roughness = fragPhysics.x;
  float metallic = fragPhysics.y;
  vec3 albedo = tex_color.rgb * tex_color.a * fragAlbedo.rgb;

  /* float light_dist = length(light_pos - fragPos); */
  /* float attenuation = 1.0 / (1 + light_dist * light_dist); */
  /* vec3 radiance = light_color * attenuation; */

  vec3 F0 = vec3(0.04); 
  F0 = mix(F0, albedo, metallic);

  // shadow
  float shadow = render_shadow ? calc_shadow(lightProjPos + vec3(0, 0, shadow_bias)) : 0;
  vec3 light = vec3(0);
  light += complute_light(
    normal, normalize(sunDir), view_dir, sunColor,
    F0, albedo, roughness, metallic
  ) * (1 - shadow);

  for (int i = 0; i < lightsCount; i++) {
    vec3 light_dir = normalize(lightsPos[i] - fragPos);
    float light_dist = length(lightsPos[i] - fragPos);
    float dist = length(lightsPos[i] - fragPos);
    float attenuation = 1.0 / (1.0 + lightsLinear[i] * dist + lightsQuadratic[i] * dist * dist);
    vec3 radiance = lightsColor[i] * attenuation;

    light += complute_light(
      normal, light_dir, view_dir, radiance,
      F0, albedo, roughness, metallic
    );
  }
  
  vec3 ambient;
  if (use_skybox) {
    ambient = complute_skybox_ambient_light(normal, view_dir, F0, albedo, roughness, metallic);
  } else {
    ambient = ambientColor * albedo * ao;
  }
  vec3 tcolor = ambient + light;

  // HDR tonemapping
  tcolor = tcolor / (tcolor + vec3(1.0));
  // gamma correct
  tcolor = pow(tcolor, vec3(1.0 / gamma)); 

  return vec4(tcolor, tex_color.a * fragAlbedo.a);
}

