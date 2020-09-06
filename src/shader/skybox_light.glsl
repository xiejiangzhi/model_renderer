uniform CubeImage skybox;
uniform Image brdfLUT;
uniform float skybox_max_mipmap_lod;

vec3 fresnelSchlickRoughness(float cosTheta, vec3 F0, float roughness) {
  return F0 + (max(vec3(1.0 - roughness), F0) - F0) * pow(1.0 - cosTheta, 5.0);
}

vec3 complute_skybox_ambient_light(
  vec3 normal, vec3 view_dir, vec3 F0, vec3 albedo, float roughness, float metallic
) {
  float NDotV = max(dot(normal, view_dir), 0.0);
  vec3 F = fresnelSchlickRoughness(NDotV, F0, roughness);
  vec3 kS = F;
  vec3 kD = 1.0 - kS;
  kD *= 1.0 - metallic;          

  // TODO irradianceMap
  vec3 irradiance = textureLod(skybox, normal, skybox_max_mipmap_lod).rgb;
  vec3 diffuse = irradiance * albedo;

  vec3 cute_dir = reflect(-view_dir, normal);
  vec3 reflect_color = textureLod(skybox, cute_dir, roughness * skybox_max_mipmap_lod).rgb;

  vec2 brdf = texture(brdfLUT, vec2(NDotV, roughness)).rg;
  vec3 specular = reflect_color * (F * brdf.x + brdf.y);

  return kD * diffuse + specular;
}
