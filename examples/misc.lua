local MR = require 'src'
local Cpml = require 'cpml'
local Helper = require 'helper'

local lg = love.graphics

local model = MR.model.load('box.obj')
local image_model = MR.model.new_plane(80, 30)

local renderer = MR.renderer.new()
local scene = MR.scene.new()
local ground = MR.model.new_plane(2000, 2000)
local cylinder = MR.model.new_cylinder(100, 300)
local sphere = MR.model.new_sphere(150)
local box = MR.model.new_box(150)

local custom_mesh_format = {
  { 'VertexPosition', 'float', 3 },
  { 'VertexNormal', 'float', 3 },
  { 'ModelAlbedo', 'byte', 4 },
}
local custom_attrs_format = {
  { 'ModelPos', 'float', 3 },
  { 'ModelAngle', 'float', 3 },
  { 'ModelScale', 'float', 3 },
  { 'ModelPhysics', 'byte', 4 },
}
local vertices = {
  { 0,0,0, 0,1,0, 1,0,0,1 },
  { 0,30,300, 0,1,0, 0,0,1,1 },
  { 300,0,0, 0,1,0, 0,1,0,1 },
}
local custom_model = MR.model.new(vertices, nil, {
  mesh_format = custom_mesh_format,
  instance_mesh_format = custom_attrs_format
})
custom_model:set_raw_instances({{ 200, 200, -300, 0, 0, 0, 1, 1, 1, 0.2, 0.9 }})

function love.load()
  local r = renderer
  r.light_pos = { 1000, 2000, 1000 }
  r.light_color = { 0, 1000000, 1000000 }
  r.ambient_color = { 0.1, 0.1, 0.1 }

  local tex = lg.newCanvas(80, 30)
  tex:renderTo(function()
    lg.setColor(1, 1, 1)
    lg.print('Hello World!', 0, 0)
  end)
  image_model:set_texture(tex)

  Helper.bind(nil, renderer)
end

function love.update(dt)
  Helper.update(dt)
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

  local ts = Helper.ts
  scene:add_model(ground, { -1000, 0, -1000 }, nil, nil, { 0, 1, 0, 1 }, { 1, 0 })
  scene:add_model(model,
    { 0, 100, 0 }, { 0, math.sin(ts) * math.pi * 2, 0 }
  , 10, { 1, 1, 1, 1 }, { 0.3, 0.9 })
  scene:add_model(model,
    { math.sin(ts) * 200, -10, math.cos(ts) * 200 },
    { 0, math.rad(45), 0 },
    { 10, 10, 10 },
    { 1, 1, 1, 0.5 },
    { 0.3, 0.5 }
  )

  scene:add_model(cylinder, { -300, 0, -200 })
  scene:add_model(sphere,
    { -300, 100, 300 },
    { math.sin(ts) * math.pi, math.rad(45), math.cos(ts) * math.pi },
    nil, nil, { 0.3, 0.9 }
  )

  scene:add_model(box,
    { 300, 200, 300 },
    { math.sin(ts) * math.pi, math.rad(45), math.cos(ts) * math.pi }, nil, nil, { 0.3, 0.9 }
  )
  scene:add_model(image_model, { 100, 100, 100 }, nil, 2)
  scene:add_model(image_model,
    { 100, 10, 100 },
    { 0, math.sin(ts * 0.3) * math.pi * 2, 0 },
    2, { 1, 1, 1, 1 }, { 0.3, 0.9 }
  )
  scene:add_model(custom_model)

  renderer:render(scene:build())
  scene:clean()

  Helper.debug()
end

