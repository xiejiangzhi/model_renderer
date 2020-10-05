local MR = require 'src'
local Helper = require 'helper'

local lg = love.graphics

local scene = MR.scene.new()
local ground = MR.model.new_plane(10000, 10000)

local renderer = MR.renderer.new()
local camera = MR.camera.new()
camera:move_to(0, 1000, 0, math.rad(30), 0, 0)

local models = {}

function love.load()
  scene.ambient_color = { 0.03, 0.03, 0.03 }
  Helper.bind(camera, renderer, 'perspective', 1, 2000)

  local v
  for i = 1, 1000 do
    v = love.math.random()
    if v < 0.3 then
      table.insert(models, MR.model.new_box(40))
    elseif v < 0.6 then
      table.insert(models, MR.model.new_sphere(20))
    else
      table.insert(models, MR.model.new_cylinder(20, 40))
    end
  end
end

function love.update(dt)
  Helper.update(dt)
end

function love.draw()
  renderer:apply_camera(camera)

  lg.clear(0.5, 0.5, 0.5)

  local angle = Helper.ts % (math.pi * 2)

  scene:add_model(ground, { 0, 0, 0 }, nil, nil, { 0, 1, 0, 1 }, { 1, 0 })
  for i, m in ipairs(models) do
    local dist = math.sqrt(i^2 / 2, 2) * 3
    scene:add_model(m,
      { math.cos(i) * dist, 50, math.sin(i) * dist },
      { 0, angle, 0 }, nil,
      { 0.97, 0.98, 0.98, 1 },
      { 0.5, 0.5 }
    )
    scene:add_model(m,
      { math.sin(i) * dist, 200 + math.cos(i) * 50, math.cos(i) * dist },
      { 0, -angle, 0 }, nil,
      { 0.15, 0.15, 0.15, 1 },
      { 0.5, 0.5 }
    )
  end
  renderer:render(scene:build())
  scene:clean()

  Helper.debug()
end

