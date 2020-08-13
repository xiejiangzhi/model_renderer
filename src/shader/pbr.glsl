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

// ----------------------------------------------------------------------------
float DistributionGGX(vec3 N, vec3 H, float roughness) {
  float a = roughness*roughness;
  float a2 = a*a;
  float NdotH = max(dot(N, H), 0.0);
  float NdotH2 = NdotH*NdotH;

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

vec3 complute_light(
  vec3 normal, vec3 light_dir, vec3 view_dir, vec3 radiance, vec3 F0, vec3 albedo, float roughness, float metallic
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
  return (kD * albedo / PI + specular) * radiance * NdotL;  // note that we already multiplied the BRDF by the Fresnel (kS) so we won't multiply by kS again
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

  float distance = length(light_pos - fragPos) * 0.1;
  float attenuation = 1.0 / (distance * distance);
  vec3 radiance = light_color * attenuation;

  vec3 F0 = vec3(0.04); 
  F0 = mix(F0, albedo, metallic);

  light += complute_light(normal, light_dir, view_dir, radiance, F0, albedo, roughness, metallic);

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

