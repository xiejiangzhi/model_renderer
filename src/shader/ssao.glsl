// Refs:
//  https://www.gamedev.net/tutorials/_/technical/graphics-programming-and-theory/a-simple-and-practical-approach-to-ssao-r2753/

uniform float SSAORadius = 64;
uniform float SSAOIntensity = 1.5;
const int SSAOSampleCount = 4;

const float SSAO_BIAS = 0.05;
const float SSAO_SCALE = 1;

const vec2 sample_ov[4] = vec2[4](
  vec2(1, 0),
  vec2(-1, 0),
  vec2(0, 1),
  vec2(0, -1)
);

vec2 hash22(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * vec3(.1031, .1030, .0973));
  p3 += dot(p3, p3.yzx+33.33);
  return fract((p3.xx+p3.yz)*p3.zy);
}

vec2 get_ssao_random_vec(vec2 uv) {
  return normalize(hash22(uv) * 2 - 1);
}

float doAmbientOcclusion(vec2 uv, vec3 p, vec3 normal, Image depth_map) {
  float depth = Texel(depth_map, uv).r;
  vec3 diff = get_world_pos(depth, uv) - p;
  vec3 v = normalize(diff);
  float d = length(diff) * SSAO_SCALE;
  return max(0, dot(normal, v) - SSAO_BIAS) * (1 / (1 + d)) * SSAOIntensity;
}

float calc_ssao(vec2 uv, vec3 frag_pos, vec3 normal, Image depth_map) {
  vec2 random_vec = get_ssao_random_vec(uv);
  float radius = SSAORadius / abs(cameraFar - cameraNear);

  float ao = 0;
  for (int i = 0; i < SSAOSampleCount; i++) {
    vec2 coord1 = reflect(sample_ov[i], random_vec) * radius;
    vec2 coord2 = vec2(coord1.x * 0.707 - coord1.y * 0.707, coord1.x * 0.707 + coord1.y * 0.707);

    ao += doAmbientOcclusion(uv + coord1 * 0.25, frag_pos, normal, depth_map);
    ao += doAmbientOcclusion(uv + coord2 * 0.50, frag_pos, normal, depth_map);
    ao += doAmbientOcclusion(uv + coord1 * 0.75, frag_pos, normal, depth_map);
    ao += doAmbientOcclusion(uv + coord2 * 1.00, frag_pos, normal, depth_map);
  }
  ao /= SSAOSampleCount;
  return 1 - ao;
}

