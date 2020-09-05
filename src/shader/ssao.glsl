#define SSAONoiseSize 16

uniform Image SSAONoise;
uniform float SSAORadius = 20;
uniform int SSAOSampleCount = 10;

vec3 get_ssao_random_vec(vec2 uv) {
  vec2 v = Texel(SSAONoise, uv / SSAONoiseSize).wy;
  return vec3(v * 2 - 1, 0);
}

float lerp(float a, float b, float s) {
  return a + s * s * (b - a);
}

vec3 get_ssao_sample_offset(float i, vec2 uv) {
  vec4 sp = Texel(SSAONoise, uv / SSAONoiseSize + vec2(i * 0.3456, i * 0.7893));
  vec3 sample_offset = vec3(sp.xy * 2 - 1, sp.z);
  float scale = lerp(0.1, 1, sp[int(mod(i, 4))]);
  /* float scale = lerp(0.1, 1, sp.w); */
  return sample_offset * scale;
}

float calc_ssao(vec2 uv, vec3 frag_pos, vec3 normal, Image depth_map) {
  vec2 noise_uv = uv * 1234.34567;
  vec3 random_vec = get_ssao_random_vec(noise_uv + uv);
  vec3 tangent = normalize(random_vec - normal * dot(random_vec, normal));
  vec3 bitangent = cross(normal, tangent);
  mat3 TBN = mat3(tangent, bitangent, normal);

  float depth_radius = SSAORadius / abs(cameraFar - cameraNear);

  float occlusion = 0.0;
  for (int i = 0; i < SSAOSampleCount; ++i) {
    vec3 sample_offset = get_ssao_sample_offset(i, noise_uv);
    vec3 sample_pos = frag_pos + TBN * sample_offset * SSAORadius;
    vec4 sample_uv = projViewMat * vec4(sample_pos, 1);
    sample_uv.xyz /= sample_uv.w;
    sample_uv.y *= y_flip;
    sample_uv = sample_uv * 0.5 + 0.5;

    float sdepth = Texel(DepthMap, sample_uv.xy).r;

    float range_check = smoothstep(0.0, 1.0, depth_radius / abs(sample_uv.z - sdepth));
    occlusion += step(sdepth, sample_uv.z) * range_check;
  }

  return 1 - occlusion / SSAOSampleCount;
}
