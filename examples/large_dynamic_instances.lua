local MR = require 'src'
local Cpml = require 'cpml'
local Helper = require 'helper'
local Util = MR.util

local lg = love.graphics

local model = MR.model.load('box.obj')
local ground = MR.model.new_plane(10000, 10000)

local renderer = MR.renderer.new()
local camera = MR.camera.new()
camera:move_to(0, 1000, 0, math.rad(30), 0, 0)

local scene = MR.scene.new()
local cylinder = MR.model.new_cylinder(10, 3000)

function love.load()
  scene:add_light({ 0, 3000, 0 }, { 1000000, 1000000, 1000000 })
  scene.ambient_color = { 0.03, 0.03, 0.03 }

  Helper.bind(camera, renderer, 'perspective', 1, 2000)
end

function love.update(dt)
  Helper.update(dt)
end

function love.draw()
  local w, h = lg.getDimensions()
  renderer:apply_camera(camera)
  local camera_space_vertices = camera:get_space_vertices()
  local center = Util.vertices_center(camera_space_vertices)

  local ts = Helper.ts

  lg.clear(0.5, 0.5, 0.5)

  local rts = ts * 0.05
  local cts = ts * 0.1
  local sts = ts * 0.2
  for i = 1, 10000 do
    local n = i * 0.1
    local size = 3 + math.sin(sts + n * 0.1) * 1
    local dist = math.sqrt(i^2 / 2, 2)

    scene:add_model(model,
      { 500 + math.cos(rts + n) * i, 250 + math.sin(rts + dist) * 200, math.sin(rts + n) * i },
      { math.sin(ts), math.cos(ts), 0 },
      size,
      { math.abs(math.sin(i + cts)), math.abs(math.cos(i + cts)), math.abs(math.sin(i * 2 + cts)), 1 },
      { math.sin(i), math.cos(i) }
    )
  end

  local viewport = { 0, 0, w, h }
  local ox, oy = -300, -300
  local ix, iy = camera:project(camera.focus + Cpml.vec3(ox, 0, oy), viewport):unpack()
  local p, dist = camera:unproject(ix, iy, viewport)

  local str = ''
  if p then
    str = str..str.format('\nray plane y=0: %.2f, %.2f, %.2f, dist: %.2f', p.x, p.y, p.z, dist)
  else
    str = '\nno ray result'
  end

  scene:add_model(model, { center:unpack() }, nil, 10)
  scene:add_model(ground, { 0, 0, 0 }, nil, nil, { 1, 1, 0, 1 }, { 1, 0 })
  scene:add_model(cylinder, { camera.focus.x,  camera.focus.y, camera.focus.z })
  if p then
    scene:add_model(cylinder, { p.x, p.y, p.z }, nil, nil, { 0, 1, 0, 1 }, { 0.5, 0.5 })
  end

  renderer:render(scene:build())
  scene:clean_model()

  lg.circle('line', ix, iy, 10)
  lg.circle('line', w / 2, h / 2, 5)

  Helper.debug(str)
end

