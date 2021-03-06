local MR = require 'src'

-- Create model from obj file or basic shape
local ground = MR.model.new_plane(2000, 2000)
local model = MR.model.load('3d.obj')
local box = MR.model.new_box(50)
local sphere = MR.model.new_sphere(30)
local cylinder = MR.model.new_cylinder(30, 100)
local complex = MR.model.new_complex({
  { 'cylinder', 10, 300 },
  { 'sphere', 50, 40, 50, 16, 0, -50, 0 },
  { 'sphere', 50, 40, 50, 16, 0, 50, 0 },
  { 'sphere', 50, 40, 50, 16, 0, 150, 0 },
})

local renderer, scene, camera

function love.load()
  -- Initalize render, scene and camera
  renderer = MR.renderer.new()
  scene = MR.scene.new()
  camera = MR.camera.new()
  local pos = { 1000, 2000, 1000 }
  local color = { 500000, 500000, 500000 }
  local linear, quadratic = 0, 1
  scene:add_light(pos, color, linear, quadratic)
  scene.ambient_color = { 0.05, 0.05, 0.05 }

  ground:set_opts({ instance_usage = 'static' })
  ground:set_instances({
    { coord = { 0, 0, 0 }, albedo = { 0, 0.9, 0 }, physics = { roughness = 1, metallic = 0 } }
  })
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
  scene:add_model(ground) -- static model
  -- dynamic model instances: coord, angle, scale, albedo, physics attributes { roughness, metallic }
  scene:add_model(model, { 0, 100, 0 }, { 0, math.sin(ts) * math.pi * 2, 0 }, 10, { 0, 1, 0, 1 }, { 0.5, 0.5 })
  scene:add_model(model,
    { math.sin(ts) * 100, 0, math.cos(ts) * 100 },
    { 0, math.rad(45), 0 }, 10, { 1, 0, 0, 1 }, { 0.5, 0.5 }
  )

  local angle = { 0, ts % (math.pi * 2), 0 }
  scene:add_model(box, { -300, 25, 0 }, angle)
  scene:add_model(sphere, { -300, 30, 300 }, angle)
  scene:add_model(cylinder, { 300, 50, 300 }, angle)
  scene:add_model(complex, { 0, 150, -150 }, angle)

  love.graphics.clear(0.5, 0.5, 0.5)
  -- Render and clean scene models
  renderer:render(scene:build())
  scene:clean_model()
end
