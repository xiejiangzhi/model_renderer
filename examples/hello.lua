local MR = require 'src'

-- Create model from obj file or basic shape
local ground = MR.model.new_plane(2000, 2000)
local model = MR.model.load('3d.obj')
local box = MR.model.new_box(50)
local sphere = MR.model.new_sphere(30)
local cylinder = MR.model.new_cylinder(30, 100)

local renderer, scene, camera

function love.load()
  -- Initalize render, scene and camera
  renderer = MR.renderer.new()
  renderer.light_pos = { 1000, 2000, 1000 }
  renderer.light_color = { 1, 1, 1 }
  renderer.ambient_color = { 0.6, 0.6, 0.6 }
  scene = MR.scene.new()
  camera = MR.camera.new()
end

function love.draw()
  local w, h = love.graphics.getDimensions()
  local hw, hh = w * 0.5, h * 0.5

  -- Set camera projection and view, and apply camera for renderer
  camera:orthogonal(-hw, hw, hh, -hh, -500, 2000)
  camera:look_at(0, 0, 0, math.rad(60), 0, 0)
  renderer:apply_camera(camera)

  local ts = love.timer.getTime()

  -- Add some model to scene
  -- model, coord, angle, scale, color
  scene:add_model(ground, { -1000, 0, -1000 }, nil, nil, { 0, 1, 0, 1 })
  scene:add_model(model, { 0, 0, 0 }, { 0, math.sin(ts) * math.pi * 2, 0 }, 10, { 0, 1, 0, 1 })
  scene:add_model(model,
    { math.sin(ts) * 100, 0, math.cos(ts) * 100 },
    { 0, math.rad(45), 0 }, 10, { 1, 0, 0, 1 }
  )

  local angle = { 0, ts % (math.pi * 2), 0 }
  scene:add_model(box, { -300, 25, 0 }, angle)
  scene:add_model(sphere, { -300, 100, 300 }, angle)
  scene:add_model(cylinder, { 300, 0, 300 }, angle)

  love.graphics.clear(0.5, 0.5, 0.5)
  -- Render and clean scene
  renderer:render(scene:build())
  scene:clean()
end
