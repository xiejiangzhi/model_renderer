void pixel_pass(
  inout vec3 world_pos, inout vec3 normal, inout vec4 albedo,
  inout float roughness, inout float metallic
) {
  if (extPassId == 1) {
    albedo.b = sin(Time) * 0.5;
  }
}
