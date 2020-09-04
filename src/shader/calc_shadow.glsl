uniform DepthImage ShadowDepthMap;

float calc_shadow(vec3 spos) {
  float shadow = 0;

  if (spos.x >= 0 && spos.x <= 1 && spos.y >=0 && spos.y <= 1) {
    // PCF
    vec2 tex_scale = 1.0 / textureSize(ShadowDepthMap, 0);
    for (int x = -1; x <= 1; ++x) {
      for (int y = -1; y <= 1; ++y) {
        shadow += Texel(ShadowDepthMap, spos + vec3(vec2(x, y) * tex_scale, 0));
      }
    }
  }
  return shadow / 9.0;
}

