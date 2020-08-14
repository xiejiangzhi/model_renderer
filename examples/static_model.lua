local MR = require 'src'
local Cpml = require 'cpml'

local private = {}

local lg = love.graphics
local lkb = love.keyboard

local move_speed = 200
local rotate_speed = math.pi

local camera_pos = Cpml.vec3(0, 500, 0)
local camera_angle = Cpml.vec3(math.rad(30), 0, 0)
local view_scale = 1
local eye_offset = Cpml.vec3(0, 1000, 0)

local model_pos = Cpml.vec3(0, 300, 0)
local model_angle = Cpml.vec3(0, math.rad(45), 0)
local model_scale = 10
local model_alpha = 1

local near, far = 1, 3000
local camera_dist = math.sqrt(far^2 / 2)
local fov = 70

local model = MR.model.load('box.obj')
local ground = MR.model.new_box(10)

local ts = 0
local pause = false

local renderer
local camera = MR.camera.new()
local scene = MR.scene.new()

local random = love.math.random

function love.load()
  renderer = MR.renderer.new()
  love.renderer = renderer
  local r = renderer
  r.light_pos = { 0, 2000, 0 }
  r.light_color = { 1000000, 1000000, 1000000 }
  r.ambient_color = { 0.03, 0.03, 0.03 }

  ground:set_opts({ instance_usage = 'static' })
  local instances = {}
  local n = 100000
  local q = math.floor(math.sqrt(n))
  for i = 1, n do
    local x, z = (i % q - q * 0.5) * 15, math.floor(i / q - q * 0.5) * 15
    table.insert(instances, {
      x, 10 + random() * 100, z,
      0, 0, 0,
      1, 0.2 + random() * 2, 1,
      0.4 + random() * 0.6, 0.4 + random() * 0.6, 0.4 + random() * 0.6, 1,
      0.3 + random() * 0.7, random(),
    })
  end
  ground:set_instances(instances)
end

function love.update(dt)
  if not pause then ts = ts + dt end

  local mv = move_speed * dt
  local dv = Cpml.vec3(0, 0, 0)
  if lkb.isDown('a') then dv.x = dv.x - mv end
  if lkb.isDown('d') then dv.x = dv.x + mv end
  if lkb.isDown('w') then dv.z = dv.z - mv end
  if lkb.isDown('s') then dv.z = dv.z + mv end
  if lkb.isDown('q') then dv.y = dv.y - mv end
  if lkb.isDown('e') then dv.y = dv.y + mv end

  if lkb.isDown('lctrl') then
    model_pos = model_pos + dv
  elseif lkb.isDown('lshift') then
    eye_offset = eye_offset + dv
  else
    camera_pos = camera_pos + dv
  end

  local rv = rotate_speed * dt
  local av = Cpml.vec3(0, 0, 0)
  if lkb.isDown('j') then av.y = av.y - rv end
  if lkb.isDown('l') then av.y = av.y + rv end
  if lkb.isDown('i') then av.x = av.x - rv end
  if lkb.isDown('k') then av.x = av.x + rv end
  if lkb.isDown('u') then av.z = av.z - rv end
  if lkb.isDown('o') then av.z = av.z + rv end
  if lkb.isDown('lctrl') then
    model_angle = model_angle + av
  else
    camera_angle = camera_angle + av
  end

  local sv = 0
  if lkb.isDown(',') then sv = -dt end
  if lkb.isDown('.') then sv = dt end
  if lkb.isDown('lctrl') then
    model_scale = model_scale + sv
  else
    view_scale = view_scale + sv
  end

  if lkb.isDown('[') then near = near - mv end
  if lkb.isDown(']') then near = near + mv end
  if lkb.isDown('-') then far = far - mv end
  if lkb.isDown('=') then far = far + mv end

  if lkb.isDown('t') then fov = fov + dt * 10 end
  if lkb.isDown('g') then fov = fov - dt * 10 end

  if lkb.isDown('z') then model_alpha = model_alpha - dt end
  if lkb.isDown('x') then model_alpha = model_alpha + dt end

  if lkb.isDown('r') then
    camera_pos = Cpml.vec3(0, 500, 0)
    camera_angle = Cpml.vec3(math.rad(30), 0, 0)
    eye_offset = Cpml.vec3(0, 1000, 0)
    view_scale = 1
    model_pos = Cpml.vec3(0, 300, 0)
    model_angle = Cpml.vec3(0, math.rad(45), 0)
    model_scale = 10
    model_alpha = 1
    near, far = 1, 3000
  end
end

function love.draw()
  local w, h = lg.getDimensions()

  camera:perspective(fov, w / h, near, far)
  camera.sight_dist = camera_dist
  camera:move_to(camera_pos.x, camera_pos.y, camera_pos.z, camera_angle:unpack())
  renderer:apply_camera(camera)

  scene:add_model(ground)
  scene:add_model(model,
    model_pos,
    model_angle,
    model_scale,
    { 1, 1, 0, model_alpha }, { 0.2, 0.7 }
  )

  lg.clear(0.5, 0.5, 0.5)
  renderer:render(scene:build())
  scene:clean()

  private.print_debug_info()
end

function love.keyreleased(key)
  if key == 'space' then
    pause = not pause
  end
end

function private.print_debug_info(ext_str)
  lg.setColor(1, 1, 1)
  local str = ''
  str = str..string.format('\ncamera pos: %.2f, %.2f %.2f', camera_pos:unpack())
  str = str..string.format('\ncamera angle: %.2f, %.2f, %.2f', camera_angle:unpack())
  str = str..string.format('\neye offset: %.2f, %.2f, %.2f', eye_offset:unpack())
  str = str..string.format('\nview scale: %.2f', view_scale)

  str = str..string.format('\nmodel pos: %.2f, %.2f %.2f', model_pos.x, model_pos.y, model_pos.z)
  str = str..string.format('\nmodel angle: %.2f, %.2f, %.2f', model_angle.x, model_angle.y, model_angle.z)
  str = str..string.format('\nmodel scale: %.2f', model_scale)
  str = str..string.format('\nmodel color: %.2f', model_alpha)
  str = str..string.format('\nnear fac: %.2f, %2.f', near, far)
  str = str..string.format('\nfov: %.2f', fov)

  str = str..string.format('\nFPS: %i', love.timer.getFPS())
  str = str..'\n'..(ext_str or '')

  lg.print(str, 15, 0)
end
