local MR = require 'src'
local Helper = require 'helper'

local lg = love.graphics

local model = MR.model.load('box.obj')
local ground = MR.model.new_box(15)

local renderer = MR.renderer.new()
local camera = MR.camera.new()
local scene = MR.scene.new()
camera:move_to(0, 1100, 3000, math.rad(60), 0, 0)

local random = love.math.random

function love.load()
  scene.sun_dir = { -0.15, 1, -0.35 }
  scene.ambient_color = { 0.03, 0.03, 0.03 }
  scene:set_lights({ { pos = { 0, 1000, 0 }, color = { 1000000, 1000000, 1000000 } } })

  renderer.skybox = lg.newCubeImage('skybox.png', { linear = true, mipmaps = true })

  Helper.bind(camera, renderer, 'perspective', 1, 5200)

  ground:set_opts({ instance_usage = 'static' })
  local instances = {}
  local n = 100000
  local q = math.floor(math.sqrt(n))
  for i = 1, n do
    local x, z = (i % q - q * 0.5) * 15, math.floor(i / q - q * 0.5) * 15
    table.insert(instances, {
      x, 10 + random() * 100, z,
      0, 0, 0,
      1, 0.5 + random() * 4, 1,
      0.4 + random() * 0.6, 0.4 + random() * 0.6, 0.4 + random() * 0.6, 1,
      0.3 + random() * 0.7, random(),
    })
  end
  ground:set_raw_instances(instances)
end

function love.update(dt)
  Helper.update(dt)
end

function love.draw()
  renderer:apply_camera(camera)

  scene:add_model(ground)
  scene:add_model(model,
    { 0, 500, 0 },
    { Helper.ts, 0, Helper.ts },
    10,
    { 1, 1, 0, 1 }, { 0.2, 0.7 }
  )

  lg.clear(0.5, 0.5, 0.5)
  renderer:render(scene:build())
  scene:clean_model()

  Helper.debug()
end

