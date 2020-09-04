uniform CubeImage skybox;
uniform Image brdf_lut;
uniform float skybox_max_mipmap_lod;

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
