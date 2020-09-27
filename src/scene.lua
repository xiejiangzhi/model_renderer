local M = {}
M.__index = M
local private = {}

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
  self.ordered_model = {}
  self.lights = {}

  self.sun_dir = { 1, 1, 1 }
  self.sun_color = { 1, 1, 1 }
  self.ambient_color = { 0.1, 0.1, 0.1 }
end

-- Params:
--  coord: { x, y, z } or { x = x, y = y, z = z }, optional. If not coord, will not try to attach instances.
--  angle: { x, y, z } or { x = x, y = y, z = z }, optional, default { 0, 0, 0 }
--  scale: { x, y, z } or { x = x, y = y, z = z } or number, optional, default { 1, 1, 1 }
--  albedo: { r, g, b, a } or { r == r, g = g, b = b, a = a }
--  physics: { roughness, metallic } or { metallic == mv, roughness = rv }, 0.0-1.0
function M:add_model(model, coord, angle, scale, albedo, physics)
  local m_set = (model.options.order or -1) >= 0 and self.ordered_model or self.model

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

-- pos: { x,y,z }
-- color: { r,g,b }
-- linear: float
-- quadratic: float
function M:add_light(pos, color, linear, quadratic)
  assert(pos, 'Light pos cannot be nil')
  assert(color, 'light color cannot be nil')
  table.insert(self.lights, { pos = pos, color = color, linear = linear or 0, quadratic = quadratic or 1 })
end

-- lights: {
--  { pos = { x,y, z}, color = { r, g, b}, linear = 0, quadratic = 1 },
--  light2, light3, ...
-- }
function M:set_lights(lights)
  self.lights = lights
end

function M:build()
  local models = {}
  local od_models = {}

  for m, instances_attrs in pairs(self.model) do
    if #instances_attrs > 0 then m:set_raw_instances(instances_attrs) end
    table.insert(models, m)
  end
  for m, instances_attrs in pairs(self.ordered_model) do
    if #instances_attrs > 0 then m:set_raw_instances(instances_attrs) end
    table.insert(od_models, m)
  end

  table.sort(od_models, private.sort_models)

  local lights = { pos = {}, color = {}, linear = {}, quadratic = {} }
  for i, light in ipairs(self.lights) do
    if not light.pos then error("light.pos cannot be nil") end
    if not light.color then error("light.color cannot be nil") end
    table.insert(lights.pos, light.pos)
    table.insert(lights.color, light.color)
    table.insert(lights.linear, light.linear or 0)
    table.insert(lights.quadratic, light.quadratic or 1)
  end

  return {
    model = models,
    ordered_model = od_models,

    lights = lights,

    sun_dir = self.sun_dir,
    sun_color = self.sun_color,
    ambient_color = self.ambient_color,
  }
end

function M:clean_model()
  self.model = {}
  self.ordered_model = {}
end

function M:clean()
  self:clean_model()
  self.lights = {}
end

----------------------

function private.sort_models(a, b)
  return a.options.order < b.options.order
end

return M
