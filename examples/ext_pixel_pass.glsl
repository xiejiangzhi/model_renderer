float depth_to_linear(float depth) {
  float z = depth * 2 - 1;
  float near = cameraClipDist.x, far = cameraClipDist.y;
  return (2.0 * near * far) / (far + near - z * (far - near));
}

void pixel_pass(
  inout vec3 world_pos, inout vec3 normal, inout vec4 albedo,
  inout float roughness, inout float metallic
) {
  if (extPassId == 1) {
    vec2 uv = gl_FragCoord.xy / love_ScreenSize.xy;
    float bg_depth = Texel(DepthMap, uv).r;
    float dist = abs(depth_to_linear(bg_depth) - depth_to_linear(gl_FragCoord.z));

    float depth_dist = 200.0;
    float foam_dist = 20.0;

    albedo.a += dist / depth_dist;

    float foam = smoothstep(0, 1, 1 - dist / foam_dist);
    float non_foam = 1 - foam;
    albedo = albedo * non_foam + vec4(1) * foam;
  }
}
