// Refs:
//  https://www.gamedev.net/tutorials/_/technical/graphics-programming-and-theory/a-simple-and-practical-approach-to-ssao-r2753/

uniform float SSAORadius = 64;
uniform float SSAOIntensity = 1;
uniform int SSAOSamplesCount = 16;
uniform float SSAOPow = 0.75;


const float SSAO_BIAS = 0.2;
const float SSAO_SCALE = 1;

const float SSAO_PI2 = 3.14159265359 * 2;
const float SSAO_GoldenAngle = 2.3999;

float hash13(vec3 p3) {
	p3  = fract(p3 * .1031);
  p3 += dot(p3, p3.yzx + 33.33);
  return fract((p3.x + p3.y) * p3.z);
}

float doAmbientOcclusion(vec2 uv, vec3 p, vec3 normal, Image depth_map) {
  float depth = Texel(depth_map, uv).r;
  vec3 diff = get_world_pos(depth, uv) - p;
  vec3 v = normalize(diff);
  float d = length(diff) * SSAO_SCALE;
  return max(0, dot(normal, v) - SSAO_BIAS) * (1 / (1 + d));
}

float calc_ssao(vec2 uv, vec3 frag_pos, vec3 normal, Image depth_map) {
  vec2 pixel2uv = 1 / love_ScreenSize.xy;

  float angle = hash13(frag_pos) * SSAO_PI2;
  float radius_step = 1 / float(SSAOSamplesCount);
  float pradius = radius_step;

  float ao = 0;
  for (float i = 0; i < SSAOSamplesCount; i++) {
    float radius = SSAORadius * pradius * pradius;
    vec2 ov = vec2(sin(angle), cos(angle)) * radius * pixel2uv;
    ao += doAmbientOcclusion(uv + ov, frag_pos, normal, depth_map);
    angle += SSAO_GoldenAngle;
    pradius += radius_step;
  }
  ao /= SSAOSamplesCount;
  return 1 - pow(ao * SSAOIntensity, SSAOPow);
}

