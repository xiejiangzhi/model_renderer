#define PI 3.14159265359

float DistributionGGX(vec3 N, vec3 H, float roughness) {
  float a = roughness * roughness;
  float a2 = a * a;
  float NdotH = max(dot(N, H), 0.0);
  float NdotH2 = NdotH * NdotH;

  float nom = a2;
  float denom = (NdotH2 * (a2 - 1.0) + 1.0);
  denom = PI * denom * denom;

  /* return nom / max(denom, 0.001); // prevent divide by zero for roughness=0.0 and NdotH=1.0 */
  return nom / denom;
}

float GeometrySchlickGGX(float NdotV, float roughness) {
  float r = (roughness + 1.0);
  float k = (r*r) / 8.0;

  float nom = NdotV;
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

