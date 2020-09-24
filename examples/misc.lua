local MR = require 'src'
-- local Cpml = require 'cpml'
local Helper = require 'helper'

local lg = love.graphics

local model = MR.model.load('box.obj')
local tp_model = model:clone()
tp_model:set_opts({ transparent = true })
local image_model = MR.model.new_plane(80, 30)
image_model:set_opts({ transparent = true })

local renderer = MR.renderer.new()
local scene = MR.scene.new()
local cylinder = MR.model.new_cylinder(100, 300)
local sphere = MR.model.new_sphere(150)
local box = MR.model.new_box(150)

local custom_mesh_format = {
  { 'VertexPosition', 'float', 3 },
  { 'VertexNormal', 'float', 3 },
  { 'ModelAlbedo', 'byte', 4 },
  { 'ModelPhysics', 'byte', 4 },
}
local custom_attrs_format = {
  { 'ModelPos', 'float', 3 },
  { 'ModelAngle', 'float', 3 },
  { 'ModelScale', 'float', 3 },
}
local custom_attrs_parser = function(attrs)
  return { attrs[1], attrs[2], attrs[3], 0,0,0, 1,1,1, 0.2,0.9 }
end

-- generate random ground cells
local cell_size = 64
local cell_hsize = cell_size / 2
local random = love.math.random
local cells = {}
for y = -1000, 1000, cell_size do
  local row = {}
  for x = -1000, 1000, cell_size do
    row[#row + 1] = {
      x = x, y = y,
      cx = #row + 1, cy = #cells + 1,
      height = random() * 100 - 50,
      r = 0.5 + random() * 0.5,
      g = 0.5 + random() * 0.5,
      b = 0.5 + random() * 0.5,
      roughness = 0.2 + random() * 0.8,
      metallic = 0.2 + random() * 0.8,
    }
  end
  cells[#cells + 1] = row
end

-- build vertices from cells
local edge_cell = { height = 0, r = 0, g = 0, b = 0 }
local vs, fs = {}, {}
for _, row in ipairs(cells) do
  for _, cell in ipairs(row) do
    local sidx = #vs + 1
    local neighbors = {}
    for oy = -1, 1 do
      neighbors[oy] = {}
      for ox = -1, 1 do
        if ox ~= 0 or oy ~= 0 then
          neighbors[oy][ox] = (cells[cell.cy + oy] or {})[cell.cx + ox] or edge_cell
        end
      end
    end

    for oy = 0, 1 do
      for ox = 0, 1 do
        local nx, ny = ((ox - 0.5) > 0) and 1 or -1, ((oy - 0.5) > 0) and 1 or -1
        local n1, n2, n3 = neighbors[ny][nx], neighbors[ny][0], neighbors[0][nx]
        local r = (cell.r + n1.r + n2.r + n3.r) / 4
        local g = (cell.g + n1.g + n2.g + n3.g) / 4
        local b = (cell.b + n1.b + n2.b + n3.b) / 4
        local h = (cell.height + n1.height + n2.height + n3.height) / 4
        table.insert(vs, {
          cell.x + ox * cell_size,h,cell.y + oy * cell_size, r,g,b,1, cell.roughness, cell.metallic
        })
      end
    end

    table.insert(vs, { cell.x + cell_hsize,cell.height,cell.y + cell_hsize, cell.r,cell.g,cell.b,1 })
    local lt, rt, lb, rb, c = sidx, sidx + 1, sidx + 2, sidx + 3, sidx + 4
    table.insert(fs, { c, lt, lb })
    table.insert(fs, { c, lb, rb })
    table.insert(fs, { c, rb, rt })
    table.insert(fs, { c, rt, lt })
  end
end
local vertices = MR.util.generate_vertices(vs, fs, function(vertex, normal)
  return { vertex[1], vertex[2], vertex[3], normal[1], normal[2], normal[3], unpack(vertex, 4) }
end)

local custom_model = MR.model.new(vertices, nil, {
  mesh_format = custom_mesh_format,
  instance_mesh_format = custom_attrs_format,
  instance_attrs_parser = custom_attrs_parser,
})
custom_model:set_instances({{ 0, 0, 0 }})

local camera = MR.camera.new()
camera:look_at(0, 0, 0, math.rad(60), 0, 0)

function love.load()
  local r = renderer
  r:set_lights({ { pos = { 1000, 2000, 1000 }, color = { 0, 1000000, 1000000 } } })
  r.ambient_color = { 0.2, 0.2, 0.2 }

  local tex = lg.newCanvas(80, 30)
  tex:renderTo(function()
    lg.setColor(1, 1, 1)
    lg.print('Hello World!', 0, 0)
  end)
  image_model:set_texture(tex)

  local w, h = lg.getDimensions()
  local hw, hh = w * 0.5, h * 0.5
  camera:orthogonal(-hw, hw, hh, -hh, 1, 2000)

  Helper.bind(camera, renderer, 'orthogonal')
end

function love.update(dt)
  Helper.update(dt)
end

function love.draw()
  renderer:apply_camera(camera)

  lg.clear(0.5, 0.5, 0.5)

  local ts = Helper.ts
  scene:add_model(model,
    { 0, 100, 0 }, { 0, math.sin(ts) * math.pi * 2, 0 }
  , 10, { 1, 1, 1, 1 }, { 0.3, 0.9 })
  scene:add_model(tp_model,
    { math.sin(ts) * 200, -10, math.cos(ts) * 200 },
    { 0, math.rad(45), 0 },
    { 10, 10, 10 },
    { 1, 1, 1, 0.5 },
    { 0.3, 0.5 }
  )

  scene:add_model(cylinder, { -300, 0, -200 })
  scene:add_model(sphere,
    { -300, 100, 300 },
    { math.sin(ts) * math.pi, math.rad(45), math.cos(ts) * math.pi },
    nil, nil, { 0.3, 0.9 }
  )

  scene:add_model(box,
    { 400, 200, 400 },
    { math.sin(ts) * math.pi, math.rad(45), math.cos(ts) * math.pi }, nil, nil, { 0.3, 0.9 }
  )

  scene:add_model(box, { 300, 0, -300 })
  scene:add_model(image_model, { 100, 100, 100 }, nil, 2)
  scene:add_model(image_model,
    { 100, 10, 100 },
    { 0, math.sin(ts * 0.3) * math.pi * 2, 0 },
    2, { 1, 1, 1, 1 }, { 0.3, 0.9 }
  )
  scene:add_model(custom_model)

  local s = scene:build()
  renderer:render(s)
  scene:clean()

  Helper.debug()
end

