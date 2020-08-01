local MR = require 'src'
local Cpml = require 'cpml'

local model = MR.model.load('3d.obj')
local box = MR.model.new_box(50)
local sphere = MR.model.new_sphere(30)
local cylinder = MR.model.new_cylinder(30, 100)

local renderer

function love.load()
  renderer = MR.renderer.new()
  renderer.light_pos = { 1000, 2000, 1000 }
  renderer.light_color = { 1, 1, 1 }
  renderer.ambient_color = { 0.6, 0.6, 0.6 }
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

  renderer.projection = projection
  renderer.view = view
  renderer.camera_pos = { eye:unpack() }
  renderer.look_at = { target:unpack() }

  local ts = love.timer.getTime()

  -- pos.x, pos.y, pos.z
  -- angle.x, angle.y, angle.z
  -- scale
  -- r, g, b, a
  local instance_transforms = {
    {
      0, -10, 0,
      0, math.sin(ts) * math.pi * 2, 0,
      10,
      0, 1, 0, 1
    },
    {
      math.sin(ts) * 100, -10, math.cos(ts) * 100,
      0, math.rad(45), 0,
      10,
      1, 0, 0, 1
    }
  }

  love.graphics.clear(0.5, 0.5, 0.5)
  renderer:render({ model = {
    { model, instance_transforms },
    { box, {{ -300, 0, 0, 0, 0, 0, 1 }}},
    { sphere, {{ -300, 0, 300, 0, 0, 0, 1, 1, 1, 0 }} },
    { cylinder, {{ 300, 0, 300, 0, 0, 0, 1 }} }
  } })
end
