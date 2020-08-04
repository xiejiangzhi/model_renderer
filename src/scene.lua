local M = {}
M.__index = M

local ARR0 = { 0, 0, 0, 0 }
local ARR1 = { 1, 1, 1, 1 }

function M.new(...)
  local obj = setmetatable({}, M)
  obj:init(...)
  return obj
end

function M:init()
  self.model = {}
end

-- Params:
--  coord: { x, y, z } or { x = x, y = y, z = z }, required
--  angle: { x, y, z } or { x = x, y = y, z = z }, optional, default { 0, 0, 0 }
--  scale: { x, y, z } or { x = x, y = y, z = z } or number, optional, default { 1, 1, 1 }
--  color: { r, g, b, a } or { r == r, g = g, b = b, a = a }, optional, default { 1, 1, 1, 1 }
function M:add_model(model, coord, angle, scale, color)
  assert(coord, "Coord cannot be nil")

  local tfs = self.model[model]
  if not tfs then tfs = {}; self.model[model] = tfs end

  if not angle then angle = ARR0 end
  if not scale then
    scale = ARR1
  elseif type(scale) == 'number' then
    scale = { scale, scale, scale }
  end
  if not color then color = ARR1 end

  table.insert(tfs, {
    coord[1] or coord.x, coord[2] or coord.y, coord[3] or coord.z,
    angle[1] or angle.x, angle[2] or angle.y, angle[3] or angle.z,
    scale[1] or scale.x, scale[2] or scale.y, scale[3] or scale.z,
    color[1] or color.r, color[2] or color.g, color[3] or color.b, color[4] or color.a or 1
  })
end

function M:build()
  local model = {}

  for m, tfs in pairs(self.model) do
    table.insert(model, { m, tfs })
  end

  return {
    model = model
  }
end

function M:clean()
  self.model = {}
end


return M
