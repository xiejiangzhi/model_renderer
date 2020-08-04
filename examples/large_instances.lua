local MR = require 'src'
local Cpml = require 'cpml'

local private = {}

local lg = love.graphics
local lkb = love.keyboard

local move_speed = 200
local rotate_speed = math.pi

local look_at = Cpml.vec3(0, 0, 0)
local camera_angle = Cpml.vec3(math.rad(60), 0, 0)
local view_scale = 0.2
local eye_offset = Cpml.vec3(0, 1000, 0)

local model_pos = Cpml.vec3(0, 0, 0)
local model_angle = Cpml.vec3(0, math.rad(45), 0)
local model_scale = 10
local model_alpha = 1

local near, far = 1, 3000
local camera_dist = math.sqrt(far^2 / 2)
local fov = 70

local model = MR.model.load('box.obj')
local model2 = MR.model.load('3d.obj')
local ground = MR.model.new_plane(10000, 10000)

local ts = 0
local pause = false

local renderer

function love.load()
  renderer = MR.renderer.new()
  local r = renderer
  r.light_pos = { 1000, 2000, 1000 }
  r.light_color = { 1, 1, 1 }
  r.ambient_color = { 0.5, 0.5, 0.5 }
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
    look_at = look_at + dv
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
    look_at = Cpml.vec3(0, 0, 0)
    camera_angle = Cpml.vec3(math.rad(30), 0, 0)
    eye_offset = Cpml.vec3(0, 1000, 0)
    view_scale = 1
    model_pos = Cpml.vec3(0, 0, 0)
    model_angle = Cpml.vec3(0, math.rad(45), 0)
    model_scale = 10
    model_alpha = 1
    near, far = 1, 3000
  end
end

function love.draw()
  local w, h = lg.getDimensions()

  local projection = Cpml.mat4.from_perspective(fov, w / h, near, far)
  local eye = look_at + Cpml.vec3(0, camera_dist, 0)
    :rotate(camera_angle.x, Cpml.vec3.unit_x)
    :rotate(camera_angle.y, Cpml.vec3.unit_y)
    :rotate(camera_angle.z, Cpml.vec3.unit_z)
  local view = Cpml.mat4()
  view:look_at(view, eye, look_at, Cpml.vec3(0, 1, 0))
  view:scale(view, Cpml.vec3(view_scale, view_scale, view_scale))

  renderer.projection = projection
  renderer.view = view
  renderer.camera_pos = { look_at:unpack() }
  renderer.look_at = { look_at:unpack() }

  local tfs = {
    {
      model_pos.x, model_pos.z, model_pos.y,
      model_angle.x, model_angle.y, model_angle.z,
      model_scale, model_scale, model_scale,
      1, 1, 0, model_alpha
    },
    {
      100, math.sin(ts) * 50, 100,
      math.sin(ts), math.cos(ts), model_angle.z,
      20, 20, 20,
      0, 1, 1, 0.75
    }
  }

  lg.clear(0.5, 0.5, 0.5)

  local tfs2 = {}
  local rts = ts * 0.05
  local cts = ts * 0.1
  local sts = ts * 0.2
  for i = 1, 10000 do
    local n = i * 0.1
    local size = 3 + math.sin(sts + n * 0.1) * 1
    local dist = math.sqrt(i^2 / 2, 2)
    table.insert(tfs2, {
      500 + math.cos(rts + n) * i, 250 + math.sin(rts + dist) * 200, math.sin(rts + n) * i,
      math.sin(ts), math.cos(ts), 0,
      size, size, size,
      math.abs(math.sin(i + cts)), math.abs(math.cos(i + cts)), math.abs(math.sin(i * 2 + cts)), 1
    })
  end

  renderer:render({ model = {
    { ground, { { -5000, 0, -5000, 0, 0, 0, 1, 1, 1, 1, 1, 0, 1 } } },
    { model, tfs },
    { model2, { { 100, 0, -100, 0, 0, 0, 50, 50, 50, 0.7, 0.7, 1, 1 } } },
    { model, tfs2 },
    { MR.model.new_cylinder(10, 3000), { { look_at.x, look_at.y, look_at.z, 0, 0, 0, 1, 1, 1 } } }
  }})

  private.print_debug_info(projection, view)
end

function love.keyreleased(key)
  if key == 'space' then
    pause = not pause
  end
end

function private.print_debug_info(projection, view)
  lg.setColor(1, 1, 1)
  local str = ''
  str = str..string.format('\nlook at: %.2f, %.2f %.2f', look_at:unpack())
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

  lg.print(str, 15, 0)
end
