local MR = require 'src'
local Cpml = require 'cpml'

local model = MR.new_model('box.obj')

function love.load()
  MR.set_render_opts({
    light_pos = { 1000, 2000, 1000 },
    light_color = { 1, 1, 1 },
    diffuse_strength = 0.4,
    ambient_color = { 0.6, 0.6, 0.6 },
  })
end

function love.draw()
  local w, h = love.graphics.getDimensions()
  local hw, hh = w * 0.5, h * 0.5

  local projection = Cpml.mat4.from_ortho(-hw, hw, hh, -hh, -500, 1000)
  local view = Cpml.mat4()
  -- z is face to user
  local eye = Cpml.vec3(0, math.sin(math.rad(60)) * 200, 200)
  local target = Cpml.vec3(0, 0, 0)
  view:look_at(view, eye, target, Cpml.vec3(0, 1, 0))

  local instance_transforms = {}
  local ts = love.timer.getTime()

  -- pos.x, pos.y, pos.z
  -- angle.x, angle.y, angle.z
  -- scale.x, scale.y, scale.z
  -- r, g, b, a
  table.insert(instance_transforms, {
    0, -10, 0,
    0, math.sin(ts) * math.pi * 2, 0,
    50, 20, 50,
    0, 1, 0, 1
  })

  table.insert(instance_transforms, {
    math.sin(ts) * 100, -10, math.cos(ts) * 100,
    0, math.rad(45), 0,
    30, 30, 30,
    1, 0, 0, 1
  })

  love.graphics.clear(0.5, 0.5, 0.5)
  MR.draw(projection, view, model, instance_transforms)
end
