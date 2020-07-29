local MR = require 'src'
local Cpml = require 'cpml'

local private = {}

local lg = love.graphics
local lkb = love.keyboard

local move_speed = 200
local rotate_speed = 1
local camera_pos = Cpml.vec3(0, 0, 100)
local camera_angle = Cpml.vec3(math.rad(60), 0, 0)

local model_pos = Cpml.vec3(0, 0, 0)
local model_angle = Cpml.vec3(0, math.rad(45), 0)
local model_scale = 20
local model_alpha = 1

local near, far = -1000, 1000

local model = MR.new_model('box.obj')
local model2 = MR.new_model('xxx.obj')

function love.load()
  MR.set_render_opts({
    light_pos = { 1000, 2000, 1000 },
    light_color = { 1, 1, 1 },
    diffuse_strength = 0.5,
    ambient_color = { 0.5, 0.5, 0.5 },
  })
end

function love.update(dt)
  local mv = move_speed * dt
  local dv = Cpml.vec3(0, 0, 0)
  if lkb.isDown('a') then dv.x = dv.x + mv end
  if lkb.isDown('d') then dv.x = dv.x - mv end
  if lkb.isDown('w') then dv.y = dv.y - mv end
  if lkb.isDown('s') then dv.y = dv.y + mv end
  if lkb.isDown('q') then dv.z = dv.z - mv end
  if lkb.isDown('e') then dv.z = dv.z + mv end

  if lkb.isDown('lctrl') then
    model_pos = model_pos + dv
  else
    camera_pos = camera_pos + dv
  end

  local rv = rotate_speed * dt
  local av = Cpml.vec3(0, 0, 0)
  if lkb.isDown('j') then av.y = av.y - rv end
  if lkb.isDown('l') then av.y = av.y + rv end
  if lkb.isDown('i') then av.x = av.x - rv end
  if lkb.isDown('k') then av.x = av.x + rv end
  if lkb.isDown('y') then av.z = av.z - rv end
  if lkb.isDown('h') then av.z = av.z + rv end
  if lkb.isDown('lctrl') then
    model_angle = model_angle + av
  else
    camera_angle = camera_angle + av
  end

  local sv = 0
  if lkb.isDown(',') then sv = -dt end
  if lkb.isDown('.') then sv = dt end
  if sv ~= 0 then
    model_scale = model_scale + sv
  end

  if lkb.isDown('[') then near = near - mv end
  if lkb.isDown(']') then near = near + mv end
  if lkb.isDown('-') then far = far - mv end
  if lkb.isDown('=') then far = far + mv end

  if lkb.isDown('t') then camera_angle.x = camera_angle.x + math.rad(dt * 5) end
  if lkb.isDown('g') then camera_angle.x = camera_angle.x - math.rad(dt * 5) end

  if lkb.isDown('z') then model_alpha = model_alpha - dt end
  if lkb.isDown('x') then model_alpha = model_alpha + dt end

  if lkb.isDown('r') then
    camera_pos = Cpml.vec3(0, 0, 100)
    camera_angle = Cpml.vec3(math.rad(60), 0, 0)
    model_pos = Cpml.vec3(0, 0, 0)
    model_angle = Cpml.vec3(0, math.rad(45), 0)
    model_scale = 20
    model_alpha = 1
  end
end

function love.draw()
  local w, h = lg.getDimensions()
  local hw, hh = w * 0.5, h * 0.5

  local projection = Cpml.mat4.from_ortho(-hw, hw, hh, -hh, near, far)
  local view = Cpml.mat4()
  view:translate(view, camera_pos)
  -- view:rotate(view, camera_angle.z, Cpml.vec3.unit_z)
  view:rotate(view, camera_angle.x, Cpml.vec3.unit_x)
  view:rotate(view, camera_angle.y, Cpml.vec3.unit_y)

  local tfs = {}
  local time = love.timer.getTime()

  -- ground
  table.insert(tfs, {
    0, -10, 0,
    0, 0, 0,
    w, 10, h,
    0, 1, 0, 1
  })

  table.insert(tfs, {
    model_pos.x, model_pos.z, model_pos.y,
    model_angle.x, model_angle.y, model_angle.z,
    model_scale, model_scale, model_scale,
    1, 1, 0, model_alpha
  })

  table.insert(tfs, {
    100, math.sin(time) * 50, 100,
    math.sin(time), math.cos(time), model_angle.z,
    30, 30, 30,
    0, 1, 1, 0.75
  })


  lg.clear(0.5, 0.5, 0.5)
  MR.draw(projection, view, model, tfs)
  MR.draw(projection, view, model2, {
    { 100, 0, -100, 0, 0, 0, 50, 50, 50, 0.7, 0.7, 1, 1 }
  })

  tfs = {}
  local rts = time * 0.1
  local cts = time * 0.1
  for i = 1, 10000 do
    local size = math.sin(i) * 30
    table.insert(tfs, {
      500 + math.cos(rts + i) * i, math.abs(math.sin(rts + i)) * 200, math.sin(rts + i) * i,
      math.sin(time), math.cos(time), 0,
      size, size, size,
      math.abs(math.sin(i + cts)), math.abs(math.cos(i + cts)), math.abs(math.sin(i * 2 + cts)), 1
    })
  end
  MR.draw(projection, view, model, tfs)

  private.print_debug_info(projection, view)
end

function private.print_debug_info(projection, view)
  lg.setColor(1, 1, 1)
  local str = ''
  str = str..string.format('\ncamera pos: %.2f, %.2f %.2f', camera_pos.x, camera_pos.y, camera_pos.z)
  str = str..string.format('\ncamera angle: %.2f, %.2f, %.2f', camera_angle.x, camera_angle.y, camera_angle.z)

  str = str..string.format('\nmodel pos: %.2f, %.2f %.2f', model_pos.x, model_pos.y, model_pos.z)
  str = str..string.format('\nmodel angle: %.2f, %.2f, %.2f', model_angle.x, model_angle.y, model_angle.z)
  str = str..string.format('\nmodel scale: %.2f', model_scale)
  str = str..string.format('\nmodel color: %.2f', model_alpha)
  str = str..string.format('\nnear fac: %.2f, %2.f', near, far)

  str = str..string.format('\nFPS: %i', love.timer.getFPS())

  lg.print(str, 15, 0)
end
