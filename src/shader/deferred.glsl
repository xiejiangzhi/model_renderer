#pragma language glsl3

#define PI 3.14159265359

// ------------------------------------------------

uniform Image NPMap;
uniform Image AlbedoMap;
uniform Image ShadowMap;
uniform Image DepthMap;

uniform vec3 ambientColor;
uniform vec3 sunDir;
uniform vec3 sunColor;

const int MAX_LIGHTS = 32;
uniform vec3 lightsPos[MAX_LIGHTS];
uniform vec3 lightsColor[MAX_LIGHTS];
uniform float lightsLinear[MAX_LIGHTS];
uniform float lightsQuadratic[MAX_LIGHTS];
uniform float lightsCount;

uniform vec3 cameraPos;
uniform float cameraNear;
uniform float cameraFar;

uniform bool use_skybox;

uniform mat4 projViewMat;
uniform mat4 invertedProjMat;
uniform mat4 invertedViewMat;
uniform mat4 sunProjViewMat;
uniform bool render_shadow = true;
uniform float shadow_bias = -0.003;

const float y_flip = -1;

//-------------------------------
// Ref: http://aras-p.info/texts/CompactNormalStorage.html#method04spheremap
vec3 decode_normal(vec2 enc) {
  vec2 fenc = enc * 4 - 2;
  float f = dot(fenc, fenc);
  float g = sqrt(1 - f / 4);
  vec3 n;
  n.xy = fenc * g;
  n.z = 1 - f / 2;
  return n;
}

// this is supposed to get the world position from the depth buffer
vec3 get_world_pos(float depth, vec2 tex_coords) {
  float z = depth * 2.0 - 1.0;

  vec4 clipSpacePosition = vec4(tex_coords * 2.0 - 1.0, z, 1.0);
  clipSpacePosition.y *= -1;
  vec4 viewSpacePosition = invertedProjMat * clipSpacePosition;

  // Perspective division
  viewSpacePosition /= viewSpacePosition.w;
  vec4 worldSpacePosition = invertedViewMat * viewSpacePosition;
  return worldSpacePosition.xyz / worldSpacePosition.w;
}


#include_glsl calc_shadow.glsl
#include_glsl ssao.glsl
#include_glsl pbr_light.glsl
#include_glsl skybox_light.glsl

// ----------------------------------------------------------------------------

vec4 effect(vec4 color, Image tex, vec2 tex_coords, vec2 screen_coords) {
  float depth = Texel(DepthMap, tex_coords).r;
  vec3 pos = get_world_pos(depth, tex_coords);
  vec4 np = Texel(NPMap, tex_coords);
  vec4 ad = Texel(AlbedoMap, tex_coords);
  vec3 albedo = ad.rgb;
  float alpha = 1;
  float valid_gbuffer = step(0.0001, ad.r + ad.g + ad.b + ad.a);
  if (valid_gbuffer == 0) { discard; }
  vec3 normal = decode_normal(np.xy) * valid_gbuffer;

  vec3 view_dir = normalize(cameraPos - pos);

  float roughness = np.z;
  float metallic = np.w;

  vec3 F0 = vec3(0.04); 
  F0 = mix(F0, albedo, metallic);

  vec3 light = vec3(0);

  vec4 light_proj_pos = sunProjViewMat * vec4(pos, 1);
  light_proj_pos.xyz = light_proj_pos.xyz / light_proj_pos.w * 0.5 + 0.5;
  float shadow = render_shadow ? calc_shadow(light_proj_pos.xyz + vec3(0, 0, shadow_bias)) : 0;
  light += complute_light(
    normal, normalize(sunDir), view_dir, sunColor,
    F0, albedo, roughness, metallic
  ) * (1 - shadow);

  for (int i = 0; i < max(lightsCount, MAX_LIGHTS - 1); i++) {
    vec3 light_dir = normalize(lightsPos[i] - pos);
    float light_dist = length(lightsPos[i] - pos);
    float dist = length(lightsPos[i] - pos);
    float attenuation = 1.0 / (1.0 + lightsLinear[i] * dist + lightsQuadratic[i] * dist * dist);
    vec3 radiance = lightsColor[i] * attenuation;

    light += complute_light(
      normal, light_dir, view_dir, radiance,
      F0, albedo, roughness, metallic
    );
  }
  
  vec3 ambient;
  if (use_skybox) {
    ambient = complute_skybox_ambient_light(
      normal, view_dir, F0, albedo, roughness, metallic
    ) * valid_gbuffer;
  } else {
    ambient = ambientColor * albedo;
  }


  float ssao = (SSAOSamplesCount > 0) ? calc_ssao(tex_coords, pos, normal, DepthMap) : 1;
  vec3 tcolor = ambient * ssao + light;

  // HDR tonemapping
  tcolor = tcolor / (tcolor + vec3(1.0));
  // gamma correct
  tcolor = pow(tcolor, vec3(1.0/2.2));

  /* return vec4(vec3(ssao), 1); */
  return vec4(tcolor, alpha);
}

