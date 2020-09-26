local MR = require 'src'
local Helper = require 'helper'

local lg = love.graphics

local model = MR.model.load('box.obj')
local light_pos = MR.model.new_box(10)
local ground = MR.model.new_box(15)
local ground_plane = MR.model.new_plane(2000, 2000)

local renderer = MR.renderer.new()
local camera = MR.camera.new()
local scene = MR.scene.new()
camera:move_to(0, 500, 800, math.rad(60), 0, 0)

local random = love.math.random

local lights_info = {}

function love.load()
  scene.sun_dir = { -0.15, 1, -0.35 }
  scene.sun_color = { 0.3, 0.3, 0.3 }
  scene.ambient_color = { 0.03, 0.03, 0.03 }

  Helper.bind(camera, renderer, 'perspective', 1, 1500)

  ground:set_opts({ instance_usage = 'static' })
  local instances = {}
  local n = 1000
  local q = math.floor(math.sqrt(n))
  local dist = 50
  for i = 1, n do
    local x, z = (i % q - q * 0.5) * dist, math.floor(i / q - q * 0.5) * dist
    table.insert(instances, {
      x, 10 + random() * 100, z,
      0, 0, 0,
      1, 0.5 + random() * 4, 1,
      0.4 + random() * 0.6, 0.4 + random() * 0.6, 0.4 + random() * 0.6, 1,
      0.3 + random() * 0.7, random(),
    })
  end
  ground:set_raw_instances(instances)

  local lm = 10000
  for i = 1, 32 do
    table.insert(lights_info, {
      center = { (random() * 2 - 1) * 500, random() * 300, (random() * 2 - 1) * 500 },
      color = { random() * lm, random() * lm, random() * lm },
    })
  end
end

function love.update(dt)
  Helper.update(dt)
end

function love.draw()
  renderer:apply_camera(camera)
  local ts = Helper.ts

  scene:add_model(ground)
  scene:add_model(ground_plane, { -1000, 0, -1000 })
  scene:add_model(model,
    { 0, 500, 0 },
    { ts, 0, ts },
    10,
    { 1, 1, 0, 1 }, { 0.2, 0.7 }
  )

  local sin, cos = math.sin, math.cos
  for i, info in ipairs(lights_info) do
    local iv = ({ math.modf(sin(i * 33.333) * 123.45693) })[2]
    local x, y, z = unpack(info.center)
    x, y, z = x + sin(ts * iv) * 200, y + cos(ts * iv) * iv * 100, z + cos(ts * iv) * 200
    scene:add_light({ x, y, z }, info.color, 0, 1)
    scene:add_model(light_pos, { x, y, z })
  end

  lg.clear(0.5, 0.5, 0.5)
  renderer:render(scene:build())
  scene:clean()

  Helper.debug()
end

