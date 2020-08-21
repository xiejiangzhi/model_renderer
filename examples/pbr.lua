local MR = require 'src'
local Helper = require 'helper'

local lg = love.graphics

local scene = MR.scene.new()
local ground = MR.model.new_plane(10000, 10000)

local renderer = MR.renderer.new()
local camera = MR.camera.new()
camera:move_to(0, 300, 600, math.pi * 0.5, 0, 0)

local m1 = MR.model.new_sphere(20)
local m2 = MR.model.new_box(20)

local renderer_opts = {
  light_pos = { 0, 1000, 10000 },
  light_color = { 100000, 100000, 100000 },
  ambient_color = { 0.03, 0.03, 0.03 },
  sun_color = { 0, 0, 0 },
}

function love.load()
  for k, v in pairs(renderer_opts) do
    renderer[k] = v
  end
  Helper.bind(camera, renderer, 'perspective')
  renderer.skybox = lg.newCubeImage('skybox.png', { linear = true, mipmaps = true })
end

function love.update(dt)
  Helper.update(dt)
end

function love.draw()
  renderer:apply_camera(camera)

  lg.clear(0.5, 0.5, 0.5)
  local angle = Helper.ts % (math.pi * 2)

  scene:add_model(ground, { -5000, 0, -5000 }, nil, nil, { 0, 1, 0, 1 }, { 1, 0 })
  for i = 0, 1, 0.1 do
    for j = 0, 1, 0.1 do
      scene:add_model(m1,
        { i * 500, 50 + j * 500, 0 },
        { 0, 0, 0 }, nil,
        { 0.97, 0.98, 0.98, 1 },
        { i, j }
      )
      scene:add_model(m2,
        { -i * 500 - 100, 50 + j * 500, 0 },
        { 0, angle, 0 }, nil,
        { 0.15, 0.15, 0.15, 1 },
        { i, j }
      )
    end
  end
  renderer:render(scene:build())
  scene:clean()

  Helper.debug()
end

