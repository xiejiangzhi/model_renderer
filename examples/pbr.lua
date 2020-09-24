local MR = require 'src'
local Helper = require 'helper'
local Cpml = require 'cpml'

local lg = love.graphics

local scene = MR.scene.new()
local ground = MR.model.new_plane(10000, 10000)

local renderer = MR.renderer.new()
local camera = MR.camera.new()
camera:move_to(0, 300, 600, math.pi * 0.5, 0, 0)

local m1 = MR.model.new_sphere(20, 20, 20, 25)
local m2 = MR.model.new_box(20)

local renderer_opts = {
  lights = { pos = { 250, 270, 700 }, color = { 10000, 10000, 10000 } },
  -- sun_dir = { -0.15, 1, -0.35 },
  sun_color = { 0.0, 0.0, 0.0 }
}

local plane_transform = Cpml.mat4.identity()
plane_transform:rotate(plane_transform, math.pi, Cpml.vec3.unit_x)
plane_transform:translate(plane_transform, Cpml.vec3(0, 1, 0))

function love.load()
  for k, v in pairs(renderer_opts) do
    renderer[k] = v
  end
  Helper.bind(camera, renderer, 'perspective', 1, 2000)
  renderer.skybox = lg.newCubeImage('skybox.png', { linear = true, mipmaps = true })
  renderer.render_shadow = false
end

function love.update(dt)
  Helper.update(dt)
end

function love.draw()
  renderer:apply_camera(camera)

  lg.clear(0.5, 0.5, 0.5)
  local angle = Helper.ts % (math.pi * 2)

  scene:add_model(ground, { -5000, 0, -5000 }, nil, nil, { 0, 1, 0, 1 }, { 1, 0 })
  camera:attach(plane_transform)
  for i = 0, 1, 0.1 do
    lg.print(string.format('R %.1f', i), i * 500 - 15, -630)
    for j = 0, 1, 0.1 do
      if i == 0 then
        lg.print(string.format('M %.1f', j), 550, -50 - j * 500 - 30)
      end

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
  camera:detach()
  renderer:render(scene:build())
  scene:clean()

  Helper.debug()
end

