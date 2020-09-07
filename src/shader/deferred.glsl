#pragma language glsl3

#define PI 3.14159265359
#define ao 1.0

// ------------------------------------------------

uniform Image NPMap;
uniform Image AlbedoMap;
uniform Image ShadowMap;
uniform Image DepthMap;

uniform vec3 ambient_color;
uniform vec3 sun_dir;
uniform vec3 sun_color;
uniform vec3 light_pos;
uniform vec3 light_color;

uniform vec3 cameraPos;
uniform float cameraNear;
uniform float cameraFar;

uniform float light_far;

uniform bool use_skybox;

uniform mat4 projViewMat;
uniform mat4 invertedProjMat;
uniform mat4 invertedViewMat;
uniform mat4 lightProjViewMat;
uniform bool render_shadow = true;
uniform float shadow_bias = -0.002;

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
  /* float shadow = Texel(ShadowMap, tex_coords).r; */
  float valid_gbuffer = step(0.0001, ad.r + ad.g + ad.b + ad.a);
  if (valid_gbuffer == 0) { discard; }
  vec3 normal = decode_normal(np.xy) * valid_gbuffer;

  vec3 view_dir = normalize(cameraPos - pos);
  vec3 light_dir = normalize(light_pos - pos);

  float roughness = np.z;
  float metallic = np.w;

  float light_dist = length(light_pos - pos);
  float attenuation = 1.0 / (1 + light_dist * light_dist);
  vec3 radiance = light_color * attenuation;

  vec3 F0 = vec3(0.04); 
  F0 = mix(F0, albedo, metallic);

  vec3 light = vec3(0);
  light += complute_light(
    normal, light_dir, view_dir, radiance,
    F0, albedo, roughness, metallic
  );
  light += complute_light(
    normal, normalize(sun_dir), view_dir, sun_color,
    F0, albedo, roughness, metallic
  );
  
  vec3 ambient;
  if (use_skybox) {
    ambient = complute_skybox_ambient_light(
      normal, view_dir, F0, albedo, roughness, metallic
    ) * valid_gbuffer;
  } else {
    ambient = ambient_color * albedo;
  }

  vec4 light_proj_pos = lightProjViewMat * vec4(pos, 1);
  light_proj_pos.xyz = light_proj_pos.xyz / light_proj_pos.w * 0.5 + 0.5;
  float shadow = render_shadow ? calc_shadow(light_proj_pos.xyz + vec3(0, 0, shadow_bias)) : 0;

  float ssao = (SSAOSampleCount > 0) ? calc_ssao(tex_coords, pos, normal, DepthMap) : 1;
  vec3 tcolor = ambient * ao * ssao + light * (1 - shadow);

  // HDR tonemapping
  tcolor = tcolor / (tcolor + vec3(1.0));
  // gamma correct
  tcolor = pow(tcolor, vec3(1.0/2.2));

  /* return vec4(vec3(ssao), 1); */
  return vec4(tcolor, alpha);
}

