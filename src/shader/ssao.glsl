uniform float SSAORadius = 32;
uniform vec3 SSAOSamples[64];
uniform int TotalSSAOSamples = 32;

float rand(vec2 p) {
	return fract(sin(dot(p.xy, vec2(12.9898, 78.233))) * 43758.5453);
}

vec3 get_rand_offset(vec2 p) {
  return vec3(
    rand(p + 0.234) * 2 - 1,
    rand(p + 0.567) * 2 - 1,
    0
  );
}

float lerp(float a, float b, float f) {
  return a + f * (b - a);
}

vec3 get_rand_sample(vec2 p, float i) {
  vec3 v = vec3(
    rand(p + 0.346) * 2 - 1,
    rand(p + 0.567) * 2 - 1,
    rand(p + 0.789)
  );
  v = normalize(v) * rand(p + 0.753);
  float scale = lerp(0.1, 1.0, i * i);
  return v * scale;
}

float calc_ssao(vec2 uv, vec3 frag_pos, vec3 normal, Image depth_map) {
  vec3 random_vec = get_rand_offset(uv);
  vec3 tangent = normalize(random_vec - normal * dot(random_vec, normal));
  vec3 bitangent = cross(normal, tangent);
  mat3 TBN = mat3(tangent, bitangent, normal);

  vec2 tex_size = textureSize(depth_map, 0);

  float occlusion = 0.0;
  for(int i = 0; i < TotalSSAOSamples; ++i) {
    vec3 sample_pos = frag_pos + TBN * SSAOSamples[i] * SSAORadius;
    /* vec3 sample_pos = frag_pos + SSAOSamples[i] * SSAORadius; */
    vec4 sfrag_pos = projViewMat * vec4(sample_pos, 1);
    sfrag_pos.xyz /= sfrag_pos.w;
    sfrag_pos.y *= y_flip;
    sfrag_pos = sfrag_pos * 0.5 + 0.5;

    float sdepth = Texel(DepthMap, sfrag_pos.xy).r;

    float range_check = smoothstep(0.0, 1.0, SSAORadius / abs(sfrag_pos.z - sdepth));
    occlusion += step(sfrag_pos.z, sdepth) * range_check;
  }

  return occlusion / TotalSSAOSamples;
}
