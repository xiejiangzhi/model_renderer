local M = {}
M.__index = M

local dir = (...):gsub('.init$', '')
local Model = require(dir..'.'..'model')
local Renderer = require(dir..'.'..'renderer')

M.model = Model
M.renderer = Renderer

function M.set_projection(mat4)
  Renderer.projection = mat4
end

function M.set_view(mat4)
  Renderer.view = mat4
end

function M.new_model(path)
  return Model.new_by_path(path)
end

function M.new_image_model(image)
  local tw, th = image:getDimensions()
  local mesh = love.graphics.newMesh(Model.mesh_format, {
    { 0, 0, 0, 0, 0 },
    { tw, 0, 0, 1, 0 },
    { tw, 0, th, 1, 1 },
    { 0, 0, th, 0, 1 },
  }, 'triangles', 'static')
  mesh:setVertexMap(1, 2, 3, 1, 3, 4)
  mesh:setTexture(image)
  return Model.new(mesh, false)
end

-- transforms: a list of transform
--  { { pos_x, pos_y, pos_z, angle_x, angle_y, angle_z, scale_x, scale_y, scale_z }, ... },
function M.draw(model, transforms)
  Renderer.draw(model, transforms)
end

function M.set_render_opts(opts)
  Renderer.set_render_opts(opts)
end

return M
