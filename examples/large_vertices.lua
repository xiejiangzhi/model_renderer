local MR = require 'src'
local Helper = require 'helper'

local lg = love.graphics

local scene = MR.scene.new()
local raw_scene

local renderer = MR.renderer.new()
local camera = MR.camera.new()
camera:move_to(0, 1000, 700, math.rad(30), 0, 0)

local ground = MR.model.new_plane(10000, 10000)
local model = MR.model.new_sphere(20, 20, 20, 100) -- 100x100 vertices

function love.load()
  local r = renderer
  r:set_lights({ { pos = { 0, 5000, 1000 }, color = { 10000000, 10000000, 10000000 } } })
  r.ambient_color = { 0.03, 0.03, 0.03 }
  Helper.bind(camera, renderer, 'perspective', 1, 2000)

  local tfs = {}
  local row = 20
  local crow = row * 0.5
  for i = 1, row * row do
    local x, y = i % row - crow, math.floor(i / row) - crow
    local dist = math.max(math.abs(x), math.abs(y))
    table.insert(tfs, {
      coord = { x * 50, 100 + math.sin(dist) * 100, y * 50 },
      albedo = { math.sin(dist), math.cos(dist), 0.5 }
    })
  end
  model:set_instances(tfs)

  scene:add_model(ground, { -5000, 0, -5000 }, nil, nil, { 0, 1, 0, 1 }, { 1, 0 })
  scene:add_model(model)
  raw_scene = scene:build()
end

function love.update(dt)
  Helper.update(dt)
end

function love.draw()
  renderer:apply_camera(camera)
  lg.clear(0.5, 0.5, 0.5)
  renderer:render(raw_scene)
  Helper.debug()
end

