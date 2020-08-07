local MR = require 'src'
local Cpml = require 'cpml'

local lg = love.graphics

local model = MR.model.load('box.obj')
local ts = 0
local pause = false

local image_model = MR.model.new_plane(80, 30)

local renderer = MR.renderer.new()

function love.load()
  local r = renderer
  r.light_pos = { 1000, 2000, 1000 }
  r.light_color = { 0, 1, 1 }
  r.ambient_color = { 0.3, 0.3, 0.3 }

  local tex = lg.newCanvas(80, 30)
  tex:renderTo(function()
    lg.setColor(1, 1, 1)
    lg.print('Hello World!', 0, 0)
  end)
  image_model:set_texture(tex)
end

function love.update(dt)
  if not pause then ts = ts + dt end
end

function love.draw()
  local w, h = lg.getDimensions()
  local hw, hh = w * 0.5, h * 0.5

  local projection = Cpml.mat4.from_ortho(-hw, hw, hh, -hh, 1, 1500)
  local view = Cpml.mat4()
  -- z is face to user
  local eye = Cpml.vec3(0, math.sin(math.rad(60)) * 700, 500)
  local target = Cpml.vec3(0, 0, 0)
  view:look_at(view, eye, target, Cpml.vec3(0, 1, 0))

  renderer.projection = projection
  renderer.view = view
  renderer.camera_pos = { eye:unpack() }
  renderer.look_at = { target:unpack() }

  lg.clear(0.5, 0.5, 0.5)

  local ground = MR.model.new_plane(2000, 2000)
  ground:set_opts({
    specular_strength = 0.1,
    specular_shininess = 2
  })

  renderer:render({
    model = {
      { ground, { {
          -1000, 0, -1000,
          0, 0, 0,
          1, 1, 1,
          0, 1, 0, 1
      } } },

      { model, {
        {
          0, 100, 0,
          0, math.sin(ts) * math.pi * 2, 0,
          10, 10, 10,
          1, 1, 1, 1
        },
        {
          math.sin(ts) * 200, -10, math.cos(ts) * 200,
          0, math.rad(45), 0,
          10, 10, 10,
          1, 1, 1, 0.5
        }
      } },

      { MR.model.new_cylinder(100, 300), { {
          -300, 0, -200,
          0, 0, 0,
          1, 1, 1,
          1, 1, 1, 1
      } } },

      { MR.model.new_sphere(150), { {
          -300, -10, 300,
          math.sin(ts) * math.pi, math.rad(45), math.cos(ts) * math.pi,
          1, 1, 1,
          1, 1, 1, 1
      } } },
      { MR.model.new_box(150), {{
        300, 200, 300,
        math.sin(ts) * math.pi, math.rad(45), math.cos(ts) * math.pi,
        1, 1, 1,
        1, 1, 1, 1
      } } },
      { image_model, {
        { 100, 100, 100,  0, 0, 0,  2, 2, 2,  1, 1, 1, 1 },
        { 100, 10, 100,  0, math.sin(ts * 0.3) * math.pi * 2, 0,  2, 2, 2,  1, 1, 1, 1 },
      } }
    }
  })
end

function love.keyreleased(key)
  if key == 'space' then
    pause = not pause
  end
end
