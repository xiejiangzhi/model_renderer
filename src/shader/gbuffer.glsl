#pragma language glsl3

varying vec3 modelNormal;
varying vec3 fragPos;
varying vec4 fragAlbedo;
varying vec4 fragPhysics;
varying vec3 lightProjPos;

uniform Image MainTex;
uniform vec3 CameraPos;

uniform DepthImage shadow_depth_map;
uniform bool render_shadow = true;
const vec3 shadow_bias = vec3(0, 0, -0.004);

void effect() {
  vec4 tex_color = Texel(MainTex, VaryingTexCoord.xy) * VaryingColor;

  love_Canvases[0] = vec4(fragPos - CameraPos, 1);
  love_Canvases[1] = vec4(normalize(modelNormal), 1);

  // shadow
  float shadow = 0;
  if (render_shadow) {
    if (lightProjPos.x >= 0 && lightProjPos.x <= 1 && lightProjPos.y >= 0 && lightProjPos.y <= 1) {
      vec3 spos = lightProjPos + shadow_bias;

      // PCF
      vec2 tex_scale = 1.0 / textureSize(shadow_depth_map, 0);
      for (int x = -1; x <= 1; ++x) {
        for (int y = -1; y <= 1; ++y) {
          shadow += Texel(shadow_depth_map, spos + vec3(vec2(x, y) * tex_scale, 0));
        }
      }
      shadow /= 9.0;
    }
  }

  float alpha = tex_color.a * fragAlbedo.a;

  love_Canvases[2] = vec4(tex_color.rgb * tex_color.a * fragAlbedo.rgb, alpha);
  love_Canvases[3] = vec4(fragPhysics.xy, shadow, 1);

  gl_FragDepth = (alpha > 0) ? gl_FragCoord.z : 1;
}

