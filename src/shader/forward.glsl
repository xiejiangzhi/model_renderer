#pragma language glsl3

#include_macros

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

const int MAX_LIGHTS = 64;
uniform vec3 lightsPos[MAX_LIGHTS];
uniform vec3 lightsColor[MAX_LIGHTS];
uniform float lightsLinear[MAX_LIGHTS];
uniform float lightsQuadratic[MAX_LIGHTS];
uniform float lightsCount;

uniform bool render_shadow = true;
uniform float shadow_bias = -0.003;

uniform bool useSkybox;
uniform Image DepthMap;
uniform float Time;
uniform vec2 cameraClipDist;

uniform Image MainTex;

// ----------------------------------------------------------------------------

#include_pixel_pass

#include_glsl calc_shadow.glsl
#include_glsl pbr_light.glsl
#include_glsl skybox_light.glsl

// ----------------------------------------------------------------------------

void effect() {
  vec4 tex_color = Texel(MainTex, VaryingTexCoord.xy) * VaryingColor;
  if (tex_color.a == 0) { discard; }

  vec3 normal = normalize(modelNormal);
  float roughness = fragPhysics.x;
  float metallic = fragPhysics.y;
  vec4 albedo = fragAlbedo;
  vec3 pos = fragPos;

#ifdef PIXEL_PASS
  pixel_pass(pos, normal, albedo, roughness, metallic);
#endif

  vec3 albedo_rgb = tex_color.rgb * tex_color.a * albedo.rgb;

  vec3 view_dir = normalize(cameraPos - pos);
  vec3 F0 = vec3(0.04); 
  F0 = mix(F0, albedo_rgb, metallic);

  // shadow
  float shadow = render_shadow ? calc_shadow(lightProjPos + vec3(0, 0, shadow_bias)) : 0;

  vec3 light = vec3(0);
  light += complute_light(
    normal, normalize(sunDir), view_dir, sunColor,
    F0, albedo_rgb, roughness, metallic
  ) * (1 - shadow);

  for (int i = 0; i < lightsCount; i++) {
    vec3 light_dir = normalize(lightsPos[i] - pos);
    float light_dist = length(lightsPos[i] - pos);
    float dist = length(lightsPos[i] - pos);
    float attenuation = 1.0 / (1.0 + lightsLinear[i] * dist + lightsQuadratic[i] * dist * dist);
    vec3 radiance = lightsColor[i] * attenuation;

    light += complute_light(
      normal, light_dir, view_dir, radiance,
      F0, albedo_rgb, roughness, metallic
    );
  }
  
  vec3 ambient;
  if (useSkybox) {
    ambient = complute_skybox_ambient_light(normal, view_dir, F0, albedo_rgb, roughness, metallic);
  } else {
    ambient = ambientColor * albedo_rgb * ao;
  }
  vec3 tcolor = ambient + light;

  // HDR tonemapping
  tcolor = tcolor / (tcolor + vec3(1.0));
  // gamma correct
  tcolor = pow(tcolor, vec3(1.0 / gamma)); 

  love_Canvases[0] = vec4(tcolor, tex_color.a * albedo.a);
}

