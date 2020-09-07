// https://www.shadertoy.com/view/MdyyRt

#define Strength 10.

float getLumi(vec3 col){
  return dot(col,vec3(0.299, 0.587, 0.114));
}

vec4 FXAA(Image Tex, vec2 uv) {
  vec3 e = vec3(1. / resolution, 0.);

  float reducemul = 0.125;// 1. / 8.;
  float reducemin = 0.0078125;// 1. / 128.;

  vec4 Or = texture(Tex, uv); //P
  vec4 LD = texture(Tex, uv - e.xy); //左下
  vec4 RD = texture(Tex, uv + vec2( e.x,-e.y)); //右下
  vec4 LT = texture(Tex, uv + vec2(-e.x, e.y)); //左上
  vec4 RT = texture(Tex, uv + e.xy); // 右上

  float Or_Lum = getLumi(Or.rgb);
  float LD_Lum = getLumi(LD.rgb);
  float RD_Lum = getLumi(RD.rgb);
  float LT_Lum = getLumi(LT.rgb);
  float RT_Lum = getLumi(RT.rgb);

  float min_Lum = min(Or_Lum,min(min(LD_Lum,RD_Lum),min(LT_Lum,RT_Lum)));
  float max_Lum = max(Or_Lum,max(max(LD_Lum,RD_Lum),max(LT_Lum,RT_Lum)));

  //x direction,-y direction
  vec2 dir = vec2((LT_Lum+RT_Lum)-(LD_Lum+RD_Lum),(LD_Lum+LT_Lum)-(RD_Lum+RT_Lum));
  float dir_reduce = max((LD_Lum+RD_Lum+LT_Lum+RT_Lum)*reducemul*0.25,reducemin);
  float dir_min = 1./(min(abs(dir.x),abs(dir.y))+dir_reduce);
  dir = min(vec2(Strength),max(-vec2(Strength),dir*dir_min)) * e.xy;

  //------
  vec4 resultA = 0.5*(texture(Tex,uv-0.166667*dir)+texture(Tex,uv+0.166667*dir));
  vec4 resultB = resultA*0.5+0.25*(texture(Tex,uv-0.5*dir)+texture(Tex,uv+0.5*dir));
  float B_Lum = getLumi(resultB.rgb);

  if(B_Lum < min_Lum || B_Lum > max_Lum) {
    return resultA;
  } else {
    return resultB;
  }
}
