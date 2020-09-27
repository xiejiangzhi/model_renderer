// Ref https://github.com/CaffeineViking/osgw/blob/master/share/shaders/gerstner.glsl

struct GerstnerWave {
  vec2 direction;
  float amplitude;
  float steepness;
  float frequency;
  float speed;
};

vec3 gerstner_wave_normal(vec3 position, float time, GerstnerWave gw) {
  float proj = dot(position.xz, gw.direction),
  phase = time * gw.speed,
  psi = proj * gw.frequency + phase,
  Af = gw.amplitude *
  gw.frequency,
  alpha = Af * sin(psi);

  float x = gw.direction.x,
    y = gw.direction.y,
    omega = Af * cos(psi);

  return vec3(
    -x * omega,
    -gw.steepness * alpha,
    -y * omega
  );
}

vec3 gerstner_wave_position(vec2 position, float time, GerstnerWave gw) {
  float proj = dot(position, gw.direction),
    phase = time * gw.speed,
    theta = proj * gw.frequency + phase,
    height = gw.amplitude * sin(theta);

  float maximum_width = gw.steepness * gw.amplitude,
    width = maximum_width * cos(theta),
    x = gw.direction.x,
    y = gw.direction.y;

  return vec3(
    x * width,
    height,
    y * width
  );
}

vec3 gerstner_wave(vec3 pos, inout vec3 normal, float time) {
  GerstnerWave gws[] = GerstnerWave[](
    GerstnerWave(vec2(1, 0), 15, 0.5, 0.01, 5),
    GerstnerWave(vec2(0.7, 0.3), 8, 0.5, 0.03, 3),
    GerstnerWave(vec2(0, 1), 10, 0.5, 0.01, 3.5),

    GerstnerWave(vec2(-0.5, 0.7), 5, 0.2, 0.05, 2),
    GerstnerWave(vec2(0.3, 0.7), 4, 0.2, 0.1, 1.5),
    GerstnerWave(vec2(0, 1), 3, 0.1, 0.15, 1)
  );

  vec3 pos_offset = vec3(0);
  int total = gws.length();

  for (int i = 0; i < total; i++) {
    pos_offset += gerstner_wave_position(pos.xz, time, gws[i]);
  }
  pos += pos_offset;

  for (int i = 0; i < total; i++) {
    normal += gerstner_wave_normal(pos, time, gws[i]);
  }

  return pos;
}

void vertex_pass(inout vec4 world_pos, inout vec3 normal) {
  if (extPassId == 1) {
    world_pos.xyz += gerstner_wave(world_pos.xyz, normal, Time);
  }
}

