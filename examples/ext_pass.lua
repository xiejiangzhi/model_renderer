local MR = require 'src'
-- local Cpml = require 'cpml'
local Helper = require 'helper'

local lg = love.graphics

local model = MR.model.load('box.obj')
local tp_model = model:clone()
tp_model:set_opts({ order = 2 })

local lfs = love.filesystem

local renderer = MR.renderer.new({
  pixel_code = lfs.read('examples/ext_pixel_pass.glsl'),
  vertex_code = lfs.read('examples/ext_vertex_pass.glsl'),
})
local scene = MR.scene.new()
local cylinder = MR.model.new_cylinder(100, 300)
local sphere = MR.model.new_sphere(150)

local cell_size = 8
local cells = {}
for y = -1000, 1000, cell_size do
  local row = {}
  for x = -1000, 1000, cell_size do
    row[#row + 1] = { x = x, y = y }
  end
  cells[#cells + 1] = row
end

-- build vertices from cells
local vs, vmap = {}, {}
for i, row in ipairs(cells) do
  local w = #row
  for j, cell in ipairs(row) do
    table.insert(vs, { cell.x,0,cell.y, 0,0, 0,1,0 })
    if i > 1 and j > 1 then
      local idx = (i - 1) * w + j
      local lt, lb, rt, rb = idx - w - 1, idx - 1, idx - w, idx
      local vidx = #vmap
      vmap[vidx + 1], vmap[vidx + 2], vmap[vidx + 3] = lt, lb, rb
      vmap[vidx + 4], vmap[vidx + 5], vmap[vidx + 6] = lt, rb, rt
    end
  end
end
vs.vertex_map = vmap

local custom_model = MR.model.new(vs, nil, {
  order = 1,
  ext_pass_id = 1,
  face_culling = 'none',
})
custom_model:set_instances({ {
  coord = { 0, 20, 0 }, albedo = { 0.15, 0.15, 0.15, 0.7 }, physics = { 0.7, 0.5 }
}})

local camera = MR.camera.new()
camera:look_at(0, 0, 0, math.rad(60), 0, 0)

function love.load()
  scene.ambient_color = { 0.2, 0.2, 0.2 }

  Helper.bind(camera, renderer, 'perspective', 1, 3000, 70)
  renderer.skybox = lg.newCubeImage('skybox.png', { linear = true, mipmaps = true })

  scene:add_light({ 1000, 1000, -1000 }, { 1000000, 1000000, 1000000 })
  scene:add_light({ 0, 300, 0 }, { 1000, 1000, 1000 })
  scene:add_light({ 0, 300, -500 }, { 10000, 10000, 10000 })
  scene.sun_dir = { -0.3, 1, -0.2 }

end

function love.update(dt)
  Helper.update(dt)
end

function love.draw()
  renderer:apply_camera(camera)

  lg.clear(0.1, 0.1, 0.1)

  local ts = Helper.ts
  scene:add_model(model,
    { 0, 100, 0 }, { 0, math.sin(ts) * math.pi * 2, 0 }
  , 10, { 1, 1, 1, 1 }, { 0.3, 0.9 })
  scene:add_model(tp_model,
    { math.sin(ts) * 200, 10, math.cos(ts) * 200 },
    { 0, math.rad(45), 0 },
    { 10, 10, 10 },
    { 1, 1, 1, 0.5 },
    { 0.3, 0.5 }
  )

  scene:add_model(cylinder, { -300, 0, -200 })
  scene:add_model(sphere,
    { -300, -100, 300 },
    { 0, 0, 0 },
    nil, nil, { 0.3, 0.9 }
  )

  for i, l in ipairs(scene.lights) do
    scene:add_model(model, l.pos)
  end

  scene:add_model(custom_model)

  renderer:render(scene:build(), ts)
  scene:clean_model()

  Helper.debug()
end

