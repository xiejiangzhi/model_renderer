varying vec3 sunProjCoord;
uniform DepthImage ShadowDepthMap;

float is_valid_shadow_range(vec3 pos) {
  float e1 = 0.01, e2 = 0.99;
  return step(3.5, step(e1, pos.x) + step(e1, pos.y) + step(pos.x, e2) + step(pos.y, e2));
}

float calc_shadow(vec3 ov) {
  float shadow = 0;

  // PCF
  vec2 pixel_scale = 1.0 / textureSize(ShadowDepthMap, 0);
  for (int x = -1; x <= 1; ++x) {
    for (int y = -1; y <= 1; ++y) {
      float s = 0;
      vec3 sov = ov + vec3(vec2(x, y) * pixel_scale, 0);
      vec3 spos = sunProjCoord + sov;
      shadow += Texel(ShadowDepthMap, spos) * is_valid_shadow_range(spos);
    }
  }

  return shadow / 9.0;
}

