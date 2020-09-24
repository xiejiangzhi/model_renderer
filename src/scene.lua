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
  self.transparent_model = {}
end

-- Params:
--  coord: { x, y, z } or { x = x, y = y, z = z }, optional. If not coord, will not try to attach instances.
--  angle: { x, y, z } or { x = x, y = y, z = z }, optional, default { 0, 0, 0 }
--  scale: { x, y, z } or { x = x, y = y, z = z } or number, optional, default { 1, 1, 1 }
--  albedo: { r, g, b, a } or { r == r, g = g, b = b, a = a }
--  physics: { roughness, metallic } or { metallic == mv, roughness = rv }, 0.0-1.0
function M:add_model(model, coord, angle, scale, albedo, physics)
  local m_set = model.options.transparent and self.transparent_model or self.model

  local instances_attrs = m_set[model]
  if not instances_attrs then instances_attrs = {}; m_set[model] = instances_attrs end
  if not coord then return end

  if not angle then angle = default_angle end
  if not scale then
    scale = default_scale
  elseif type(scale) == 'number' then
    scale = { scale, scale, scale }
  end
  if not albedo then albedo = default_albedo end
  if not physics then physics = default_physics end

  table.insert(instances_attrs, {
    coord.x or coord[1], coord.y or coord[2], coord.z or coord[3],
    angle.x or angle[1], angle.y or angle[2], angle.z or angle[3],
    scale.x or scale[1], scale.y or scale[2], scale.z or scale[3],
    albedo.r or albedo[1], albedo.g or albedo[2], albedo.b or albedo[3], albedo.a or albedo[4],
    physics.roughness or physics[1], physics.metallic or physics[2],
  })
end

function M:build()
  local models = {}
  local tp_models = {}

  for m, instances_attrs in pairs(self.model) do
    if #instances_attrs > 0 then m:set_raw_instances(instances_attrs) end
    table.insert(models, m)
  end
  for m, instances_attrs in pairs(self.transparent_model) do
    if #instances_attrs > 0 then m:set_raw_instances(instances_attrs) end
    table.insert(tp_models, m)
  end

  return {
    model = models,
    transparent_model = tp_models
  }
end

function M:clean()
  self.model = {}
  self.transparent_model = {}
end


return M
