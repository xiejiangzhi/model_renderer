local MR = require 'src'
local Cpml = require 'cpml'

local lg = love.graphics

local model = MR.new_model('box.obj')
local ts = 0
local pause = false

function love.load()
  MR.set_render_opts({
    light_pos = { 1000, 2000, 1000 },
    light_color = { 0, 1, 1 },
    diffuse_strength = 0.5,
    ambient_color = { 0.3, 0.3, 0.3 },
  })
end

function love.update(dt)
  if not pause then ts = ts + dt end
end

function love.draw()
  local w, h = lg.getDimensions()
  local hw, hh = w * 0.5, h * 0.5

  local projection = Cpml.mat4.from_ortho(-hw, hw, hh, -hh, -500, 1000)
  local view = Cpml.mat4()
  -- z is face to user
  local eye = Cpml.vec3(0, math.sin(math.rad(60)) * 200, 200)
  local target = Cpml.vec3(0, 0, 0)
  view:look_at(view, eye, target, Cpml.vec3(0, 1, 0))

  MR.set_projection(projection)
  MR.set_view(view)

  local instance_transforms = {}

  -- pos.x, pos.y, pos.z
  -- angle.x, angle.y, angle.z
  -- scale.x, scale.y, scale.z
  -- r, g, b, a
  table.insert(instance_transforms, {
    0, -10, 0,
    0, math.sin(ts) * math.pi * 2, 0,
    5, 2, 5,
    1, 1, 1, 1
  })

  table.insert(instance_transforms, {
    math.sin(ts) * 200, -10, math.cos(ts) * 200,
    0, math.rad(45), 0,
    5, 5, 5,
    1, 1, 1, 1
  })

  lg.clear(0.5, 0.5, 0.5)
  MR.draw(model, instance_transforms)

  local tex = lg.newCanvas(80, 30)
  tex:renderTo(function()
    lg.setColor(1, 1, 1)
    lg.print('Hello World!', 0, 0)
  end)
  local img_model = MR.new_image_model(tex)
  img_model.write_depth = false
  MR.draw(img_model, {
    { 100, 100, 100, 0, 0, 0, 2, 2, 2, 1, 1, 1, 1 },
    { 100, 0, 100, 0, math.sin(ts * 0.3) * math.pi * 2, 0, 2, 2, 2, 1, 1, 1, 1 },
  })
end

function love.keyreleased(key)
  if key == 'space' then
    pause = not pause
  end
end
