local M = {}
M.__index = M

local default_angle = { 0, 0, 0 }
local default_scale = { 1, 1, 1 }
local default_albedo = { 0.96, 0.96, 0.97 }
local default_physics = { roughness = 0.5, metallic = 0.3 }

function M.new(...)
  local obj = setmetatable({}, M)
  obj:init(...)
  return obj
end

function M:init()
  self.model = {}
end

-- Params:
--  coord: { x, y, z } or { x = x, y = y, z = z }, optional. If not coord, will not try to attach instances.
--  angle: { x, y, z } or { x = x, y = y, z = z }, optional, default { 0, 0, 0 }
--  scale: { x, y, z } or { x = x, y = y, z = z } or number, optional, default { 1, 1, 1 }
--  albedo: { r, g, b, a } or { r == r, g = g, b = b, a = a }
--  physics: { roughness, metallic } or { metallic == mv, roughness = rv }, 0.0-1.0
function M:add_model(model, coord, angle, scale, albedo, physics)
  local tfs = self.model[model]
  if not tfs then tfs = {}; self.model[model] = tfs end
  if not coord then return end

  if not angle then angle = default_angle end
  if not scale then
    scale = default_scale
  elseif type(scale) == 'number' then
    scale = { scale, scale, scale }
  end
  if not albedo then albedo = default_albedo end
  if not physics then physics = default_physics end

  table.insert(tfs, {
    coord.x or coord[1], coord.y or coord[2], coord.z or coord[3],
    angle.x or angle[1], angle.y or angle[2], angle.z or angle[3],
    scale.x or scale[1], scale.y or scale[2], scale.z or scale[3],
    albedo.r or albedo[1], albedo.g or albedo[2], albedo.b or albedo[3], albedo.a or albedo[4],
    physics.roughness or physics[1], physics.metallic or physics[2],
  })
end

function M:build()
  local models = {}

  for m, tfs in pairs(self.model) do
    if #tfs > 0 then m:set_raw_instances(tfs) end
    table.insert(models, m)
  end

  return {
    model = models
  }
end

function M:clean()
  self.model = {}
end


return M
