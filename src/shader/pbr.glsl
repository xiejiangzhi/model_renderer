#pragma language glsl3

#define PI 3.14159265359
#define ao 1.0

const vec3 shadow_bias = vec3(0, 0, -0.004);

// ------------------------------------------------

varying vec3 modelNormal;
varying vec3 fragPos;
varying vec4 fragAlbedo;
varying vec4 fragPhysics;
varying vec3 lightProjPos;

uniform vec3 ambient_color;
uniform vec3 sun_dir;
uniform vec3 sun_color;
uniform vec3 light_pos;
uniform vec3 light_color;
uniform vec3 camera_pos;

uniform float light_far;

uniform DepthImage shadow_depth_map;
uniform bool render_shadow = true;

uniform CubeImage skybox;
uniform Image brdf_lut;
uniform float skybox_max_mipmap_lod;
uniform bool use_skybox;

//-----------------------------

float calc_shadow(vec3 spos) {
  float shadow = 0;

  if (spos.x >= 0 && spos.x <= 1 && spos.y >=0 && spos.y <= 1) {
    // PCF
    vec2 tex_scale = 1.0 / textureSize(shadow_depth_map, 0);
    for (int x = -1; x <= 1; ++x) {
      for (int y = -1; y <= 1; ++y) {
        shadow += Texel(shadow_depth_map, spos + vec3(vec2(x, y) * tex_scale, 0));
      }
    }
  }
  return shadow / 9.0;
}

// ----------------------------------------------------------------------------

float DistributionGGX(vec3 N, vec3 H, float roughness) {
  float a = roughness * roughness;
  float a2 = a * a;
  float NdotH = max(dot(N, H), 0.0);
  float NdotH2 = NdotH * NdotH;

  float nom   = a2;
  float denom = (NdotH2 * (a2 - 1.0) + 1.0);
  denom = PI * denom * denom;

  return nom / max(denom, 0.001); // prevent divide by zero for roughness=0.0 and NdotH=1.0
}

float GeometrySchlickGGX(float NdotV, float roughness) {
  float r = (roughness + 1.0);
  float k = (r*r) / 8.0;

  float nom   = NdotV;
  float denom = NdotV * (1.0 - k) + k;

  return nom / denom;
}

float GeometrySmith(vec3 N, vec3 V, vec3 L, float roughness) {
  float NdotV = max(dot(N, V), 0.0);
  float NdotL = max(dot(N, L), 0.0);
  float ggx2 = GeometrySchlickGGX(NdotV, roughness);
  float ggx1 = GeometrySchlickGGX(NdotL, roughness);

  return ggx1 * ggx2;
}

vec3 fresnelSchlick(float cosTheta, vec3 F0) {
  return F0 + (1.0 - F0) * pow(1.0 - cosTheta, 5.0);
}

vec3 fresnelSchlickRoughness(float cosTheta, vec3 F0, float roughness) {
  return F0 + (max(vec3(1.0 - roughness), F0) - F0) * pow(1.0 - cosTheta, 5.0);
}   

vec3 complute_light(
  vec3 normal, vec3 light_dir, vec3 view_dir, vec3 radiance,
  vec3 F0, vec3 albedo, float roughness, float metallic
) {
  // Cook-Torrance BRDF
  vec3 half_way_dir = normalize(light_dir + view_dir);
  float NDF = DistributionGGX(normal, half_way_dir, roughness);   
  float G = GeometrySmith(normal, view_dir, light_dir, roughness);      
  vec3 F = fresnelSchlick(clamp(dot(half_way_dir, view_dir), 0.0, 1.0), F0);

  vec3 nominator = NDF * G * F; 
  float denominator = 4 * max(dot(normal, view_dir), 0.0) * max(dot(normal, light_dir), 0.0);
  vec3 specular = nominator / max(denominator, 0.001);

  // kS is equal to Fresnel
  vec3 kS = F;
  // for energy conservation, the diffuse and specular light can't
  // be above 1.0 (unless the surface emits light); to preserve this
  // relationship the diffuse component (kD) should equal 1.0 - kS.
  vec3 kD = vec3(1.0) - kS;
  // multiply kD by the inverse metalness such that only non-metals 
  // have diffuse lighting, or a linear blend if partly metal (pure metals
  // have no diffuse light).
  kD *= 1.0 - metallic;	  

  // scale light by NdotL
  float NdotL = max(dot(normal, light_dir), 0.0);        

  // add to outgoing radiance Lo
  // note that we already multiplied the BRDF by the Fresnel (kS) so we won't multiply by kS again
  return (kD * albedo / PI + specular) * radiance * NdotL;
}

vec3 complute_skybox_ambient_light(
  vec3 normal, vec3 view_dir, vec3 F0, vec3 albedo, float roughness, float metallic
) {
  vec3 F = fresnelSchlickRoughness(max(dot(normal, view_dir), 0.0), F0, roughness);
  vec3 kS = F;
  vec3 kD = 1.0 - kS;
  kD *= 1.0 - metallic;	  

  vec3 irradiance = textureLod(skybox, normal, skybox_max_mipmap_lod).rgb;
  vec3 diffuse = irradiance * albedo;

  vec3 cute_dir = reflect(-view_dir, normal);
  vec3 reflect_color = textureLod(skybox, cute_dir, roughness * skybox_max_mipmap_lod).rgb;

  vec2 brdf = texture(brdf_lut, vec2(max(dot(normal, view_dir), 0.0), roughness)).rg;
  vec3 specular = reflect_color * (F * brdf.x + brdf.y);

  return (kD * diffuse + specular) * ao;
}

// ----------------------------------------------------------------------------

vec4 effect(vec4 color, Image tex, vec2 texture_coords, vec2 screen_coords) {
  vec4 tex_color = Texel(tex, texture_coords);
  if (tex_color.a == 0) { discard; }

  vec3 normal = normalize(modelNormal);
  vec3 view_dir = normalize(camera_pos - fragPos);
  vec3 light_dir = normalize(light_pos - fragPos);

  float roughness = fragPhysics.x;
  float metallic = fragPhysics.y;
  vec3 albedo = tex_color.rgb * tex_color.a * fragAlbedo.rgb;

  float light_dist = length(light_pos - fragPos);
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
    ambient = complute_skybox_ambient_light(normal, view_dir, F0, albedo, roughness, metallic);
  } else {
    ambient = ambient_color * albedo * ao;
  }

  // shadow
  float shadow = render_shadow ? calc_shadow(lightProjPos + shadow_bias) : 0;
  vec3 tcolor = ambient + light * (1 - shadow);

  // HDR tonemapping
  tcolor = tcolor / (tcolor + vec3(1.0));
  // gamma correct
  tcolor = pow(tcolor, vec3(1.0/2.2)); 

  return vec4(tcolor, tex_color.a * fragAlbedo.a);
}

