#pragma language glsl3

varying vec3 modelNormal;
varying vec3 fragPos;
varying vec4 fragAlbedo;
varying vec4 fragPhysics;
varying vec3 lightProjPos;

uniform Image MainTex;
/* uniform vec3 CameraPos; */

uniform DepthImage shadow_depth_map;
uniform bool render_shadow = true;
const vec3 shadow_bias = vec3(0, 0, -0.004);

// Ref: http://aras-p.info/texts/CompactNormalStorage.html#method04spheremap
vec2 encode_normal(vec3 n) {
  float p = sqrt(n.z*8+8);
  return n.xy / p + 0.5;
}

void effect() {
  vec4 tex_color = Texel(MainTex, VaryingTexCoord.xy) * VaryingColor;
  if (tex_color.a == 0) { discard; }

  love_Canvases[0] = vec4(encode_normal(normalize(modelNormal)), fragPhysics.xy);

  float alpha = tex_color.a * fragAlbedo.a;
  love_Canvases[1] = vec4(tex_color.rgb * tex_color.a * fragAlbedo.rgb, alpha);
}

