local M = {}
M.__index = M

local dir = (...):gsub('.init$', '')
local Model = require(dir..'.'..'model')
local Renderer = require(dir..'.'..'renderer')

function M.new_model(path)
  return Model.new(path)
end

-- transforms: a list of transform
--  { { pos_x, pos_y, pos_z, angle_x, angle_y, angle_z, scale_x, scale_y, scale_z }, ... },
function M.draw(projection, view, model, transforms)
  Renderer.draw(projection, view, model, transforms)
end

function M.set_render_opts(opts)
  Renderer.set_render_opts(opts)
end

return M
