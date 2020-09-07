// Refs:
//  https://www.shadertoy.com/view/MdyyRt
//  https://catlikecoding.com/unity/tutorials/advanced-rendering/fxaa/

const float fxaa_span_max = 8;
const float fxaa_reducemul = 1 / 8;
const float fxaa_reducemin = 1 / 128;
const vec3 fxaa_luma = vec3(0.299, 0.587, 0.114);

float fxaa_sample_luma(Image tex, vec2 uv) {
  return dot(texture(tex, uv).rgb, fxaa_luma);
}

vec4 FXAA(Image tex, vec2 uv, vec2 resolution) {
  vec3 pixel_size = vec3(1. / resolution, 0.);

  float l_m = fxaa_sample_luma(tex, uv);
  float l_lb = fxaa_sample_luma(tex, uv - pixel_size.xy);
  float l_rt = fxaa_sample_luma(tex, uv + pixel_size.xy);
  float l_lt = fxaa_sample_luma(tex, uv + pixel_size.xy * vec2(-1, 1));
  float l_rb = fxaa_sample_luma(tex, uv + pixel_size.xy * vec2(1, -1));

  float min_luma = min(l_m, min(min(l_lb, l_rb), min(l_lt, l_rt)));
  float max_luma = max(l_m, max(max(l_lb, l_rb), max(l_lt, l_rt)));

  vec2 dir = vec2((l_lt + l_rt) - (l_lb + l_rb), (l_lb + l_lt) - (l_rb + l_rt));
  float dir_reduce = max((l_lb + l_rb + l_lt + l_rt) * fxaa_reducemul * 0.25, fxaa_reducemin);
  float rcp_dir_min = 1. / (min(abs(dir.x), abs(dir.y)) + dir_reduce);
  dir = min(
    vec2(fxaa_span_max),
    max(-vec2(fxaa_span_max), dir * rcp_dir_min)
  ) * pixel_size.xy;

  vec4 result_a = 0.5 * (texture(tex, uv - 0.166667 * dir) + texture(tex,uv + 0.166667 * dir));
  vec4 result_b = result_a * 0.5 + 0.25 * (texture(tex, uv - 0.5 * dir) + texture(tex, uv + 0.5 * dir));
  float luma_b = dot(result_b.rgb, fxaa_luma);

  if(luma_b < min_luma || luma_b > max_luma) {
    return result_a;
  } else {
    return result_b;
  }
}
