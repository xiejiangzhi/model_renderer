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
--  coord: { x, y, z } or { x = x, y = y, z = z }, required
--  angle: { x, y, z } or { x = x, y = y, z = z }, optional, default { 0, 0, 0 }
--  scale: { x, y, z } or { x = x, y = y, z = z } or number, optional, default { 1, 1, 1 }
--  albedo: { r, g, b, a } or { r == r, g = g, b = b, a = a }
--  physics: { roughness, metallic } or { metallic == mv, roughness = rv }, 0.0-1.0
function M:add_model(model, coord, angle, scale, albedo, physics)
  assert(coord, "Coord cannot be nil")

  local tfs = self.model[model]
  if not tfs then tfs = {}; self.model[model] = tfs end

  if not angle then angle = default_angle end
  if not scale then
    scale = default_scale
  elseif type(scale) == 'number' then
    scale = { scale, scale, scale }
  end
  if not albedo then albedo = default_albedo end
  if not physics then physics = default_physics end

  table.insert(tfs, {
    coord[1] or coord.x, coord[2] or coord.y, coord[3] or coord.z,
    angle[1] or angle.x, angle[2] or angle.y, angle[3] or angle.z,
    scale[1] or scale.x, scale[2] or scale.y, scale[3] or scale.z,
    albedo[1] or albedo.r, albedo[2] or albedo.g, albedo[3] or albedo.b, albedo[4] or albedo.a,
    physics[1] or physics.roughness, physics[2] or physics.metallic
  })
end

function M:build()
  local model = {}

  for m, tfs in pairs(self.model) do
    m:set_instances(tfs)
    table.insert(model, m)
  end

  return {
    model = model
  }
end

function M:clean()
  self.model = {}
end


return M
