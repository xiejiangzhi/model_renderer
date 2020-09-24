local MR = require 'src'
local Cpml = require 'cpml'
local Helper = require 'helper'

local lg = love.graphics
local lkb = love.keyboard

local model = MR.model.new_cylinder(10, 100)
local ground = MR.model.new_plane(2000, 2000)

local renderer = MR.renderer.new()
local camera = MR.camera.new()

local x, y = 0, 0
local rx, ry = math.rad(30), 0

local img

function love.load()
  local w, h = lg.getDimensions()
  local hw, hh = w * 0.5, h * 0.5
  camera:orthogonal(-hw, hw, hh, -hh, 1, 2000)
  camera:look_at(0, 0, 0, math.rad(60), 0, 0)
  Helper.bind(camera, renderer, 'orthogonal')

  renderer:apply_camera(camera)

  img = lg.newImage('example.png')
  model:set_instances({
    { coord = { 0, 0, 0 } },
    { coord = { hw / 2, 0, hh / 2 } },
    { coord = { hw, 0, hh } },
  })
  ground:set_instances({
    { coord = { -1000, 0, -1000 }, albedo = { 0, 0.90, 0 }, physics = { 0.5, 0.2 } }
  })
end

function love.update(dt)
  Helper.update(dt)

  local ov = 300 * dt
  local rv = math.pi * 0.5 * dt
  if lkb.isDown('a') then
    x = x - ov
  elseif lkb.isDown('d') then
    x = x + ov
  elseif lkb.isDown('w') then
    y = y - ov
  elseif lkb.isDown('s') then
    y = y + ov
  elseif lkb.isDown('z') then
    rx = rx - rv
  elseif lkb.isDown('x') then
    rx = rx + rv
  elseif lkb.isDown('q') then
    ry = ry - rv
  elseif lkb.isDown('e') then
    ry = ry + rv
  end
  camera:look_at(x, 0, y, rx, ry, 0)
end

function love.draw()
  local w, h = lg.getDimensions()
  local hw, hh = w * 0.5, h * 0.5

  local transform_mat = Cpml.mat4.identity()
  transform_mat:rotate(transform_mat, math.pi * 0.5, Cpml.vec3.unit_x)
  transform_mat:translate(transform_mat, Cpml.vec3(0, 10, 0))
  renderer:apply_camera(camera)
  renderer.write_screen_depth = true
  renderer:render({ model = { model, ground } })

  camera:attach(transform_mat)

  lg.print('Some text\nNew line', 10, 10)
  lg.line(10, 10, 100, 100, -100, 100, -150, -200)
  lg.rectangle('line', 200, 100, 200, 200)

  lg.draw(img, -100, 10, math.pi * 0.5, 0.2, 0.2)

  -- Also support the Love translate APIs
  lg.push()
  lg.scale(0.25)
  lg.translate(-100, -100)
  lg.rotate(math.pi * 0.25)
  lg.draw(img, -200, 10, math.pi * 0.5, 0.2, 0.2)

  local tf = love.math.newTransform()
  tf:scale(0.75, 1.5)
  tf:translate(-200, -500)
  tf:rotate(math.pi * 0.25)
  lg.applyTransform(tf)
  lg.draw(img, -200, -10, math.pi * 0.5, 0.2, 0.2)
  lg.pop()

  lg.setColor(1, 0, 0, 0.5)
  lg.circle('fill', 0, 0, 20)
  lg.circle('line', 0, 0, 25)

  lg.setColor(0, 1, 0, 0.5)
  lg.circle('fill', hw / 2, hh / 2, 30)
  lg.circle('line', hw / 2, hh / 2, 35)

  lg.setColor(0, 0, 1, 0.5)
  lg.circle('fill', hw, hh, 40)
  lg.circle('line', hw, hh, 45)

  lg.setColor(1, 1, 1)
  camera:detach()

  Helper.debug()
end
