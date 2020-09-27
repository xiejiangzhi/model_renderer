local M = {}
M.__index = M

local private = {}

local dir = (...):gsub('.[^%.]+$', '')
local ObjParser = require(dir..'.obj_parser')
require(dir..'.model_builder').inject(M)

local new_mesh = love.graphics.newMesh

M.mesh_format = {
  { 'VertexPosition', 'float', 3 },
  { 'VertexTexCoord', 'float', 2 },
  { 'VertexNormal', 'float', 3 },
}

M.instance_mesh_format = {
  { 'ModelPos', 'float', 3 },
  { 'ModelAngle', 'float', 3 },
  { 'ModelScale', 'float', 3 },
  { 'ModelAlbedo', 'byte', 4 },
  { 'ModelPhysics', 'byte', 4 },
}

M.default_opts = {
  write_depth = true,
  face_culling = 'back', -- 'back', 'front', 'none'
  order = -1, -- -1 don't sort, must >= 0 for sort
  instance_usage = 'dynamic', -- see love2d SpriteBatchUsage. dynamic, static, stream. defualt: dynamic
  mesh_format = M.mesh_format,
  instance_mesh_format = M.instance_mesh_format,
  ext_pass_id = 0, -- for ext pass, 0 will disable ext pass

   -- parser set_instances attrs and return a table value of instance attributes.
   -- must match the `instance_mesh_format`
  instance_attrs_parser = false,
}
M.default_opts.__index = M.default_opts

local default_rotation = { 0, 0, 0 }
local default_scale = { 1, 1, 1 }
local default_albedo = { 1, 1, 1, 1 }
local default_physics = { 0.5, 0.2 }

--------------------

function M.new(...)
  local obj = setmetatable({}, M)
  obj:init(...)
  return obj
end

function M.load(path)
	local data = ObjParser.parse_file(path)
  local vertices = ObjParser.parse_face(data)
  local m = M.new(vertices)
  m.path = path
  m.data = data
  return m
end

function M.set_default_opts(opts)
  for k, v in pairs(opts) do
    if M.default_opts[k] ~= nil then
      M.default_opts[k] = v
    else
      error("Invalid option "..k)
    end
  end
end

--------------------

-- new(vertices)
-- new(vertices, options)
-- new(vertices, texture)
-- new(vertices, texture, options)
-- vertices: { vertex1, vertex2, ..., vertex_map }
-- texture:
-- optsions:
--  write_depth:
--  face_culling: 'back' or 'front' or 'none'
--  instance_usage: see love2d SpriteBatchUsage. dynamic, static, stream. defualt: dynamic
--  mesh_format: custom the mesh format
--  instance_mesh_format: custom the instance mesh format
function M:init(vertices, texture, opts)
  if not opts and type(texture) == 'table' then
    opts, texture = texture, nil
  end

  local mesh_format = opts and opts.mesh_format or M.mesh_format
  self.vertices = vertices
  self.mesh = new_mesh(mesh_format, vertices, "triangles", 'static')
  if vertices.vertex_map then
    self.mesh:setVertexMap(vertices.vertex_map)
  end
  self.options = setmetatable({}, M.default_opts)

  if texture then self:set_texture(texture) end
  if opts then self:set_opts(opts) end
end

function M:set_opts(opts)
  for k, v in pairs(opts) do
    if M.default_opts[k] ~= nil then
      self.options[k] = v
    else
      error("Invalid option "..k)
    end
  end
end

function M:set_texture(tex)
  self.mesh:setTexture(tex)
end

-- attrs: { { coord = vec3, rotation = vec3, scale = number or vec3, albedo = vec3 or vec4, physics = vec2 }, ... }
--  coord is required, other is optionals
function M:set_instances(instances_attrs)
  if #instances_attrs == 0 then error("Instances count cannot be 0") end

  local parser = self.options.instance_attrs_parser or private.parse_instance_attrs
  local raw_attrs = {}
  for i, attrs in ipairs(instances_attrs) do
    table.insert(raw_attrs, parser(attrs))
  end

  self:set_raw_instances(raw_attrs)
end

-- attrs: { instance1_attrs, instance2_attrs, ... }
-- format: mesh format
function M:set_raw_instances(attrs)
  local tfs_mesh = self.instances_mesh
  if tfs_mesh and self.total_instances >= #attrs then
    tfs_mesh:setVertices(attrs)
  else
    local format = self.options.instance_mesh_format
    tfs_mesh = new_mesh(format, attrs, nil, self.options.instance_usage)
    for _, f in ipairs(format) do
      self.mesh:attachAttribute(f[1], tfs_mesh, 'perinstance')
    end

    self.instances_mesh = tfs_mesh
  end

  self.total_instances = #attrs
end

function M:clone()
  return M.new(self.vertices, self.mesh:getTexture(), self.options)
end

--------------------

-- attrs: { coord = vec3, rotation = vec3, scale = number or vec3, albedo = vec3 or vec4, physics = vec2 }
function private.parse_instance_attrs(attrs)
  local x, y, z, rx, ry, rz, sx, sy, sz, ar, ag, ab, aa, pr, pm
  local coord = attrs.coord
  local rotation = attrs.rotation or default_rotation
  local scale = attrs.scale or default_scale
  local albedo = attrs.albedo or default_albedo
  local physics = attrs.physics or default_physics

  if coord.x then
    x, y, z = coord.x, coord.y, coord.z
  else
    x, y, z = unpack(coord)
  end
  if rotation.x then
    rx, ry, rz = rotation.x, rotation.y, rotation.z
  else
    rx, ry, rz = unpack(rotation)
  end
  if type(scale) == 'number' then
    sx, sy, sz = scale, scale, scale
  elseif scale.x then
    sx, sy, sz = scale.x, scale.y, scale.z
  else
    sx, sy, sz = unpack(scale)
  end
  if albedo.r then
    ar, ag, ab, aa = albedo.r, albedo.g, albedo.b, albedo.a
  else
    ar, ag, ab, aa = unpack(albedo)
  end
  if physics.roughness then
    pr, pm = physics.roughness, physics.metallic
  else
    pr, pm = unpack(physics)
  end

  return {
    x, y, z,
    rx, ry, rz,
    sx, sy, sz,
    ar, ag, ab, aa or 1,
    pr, pm
  }
end

return M
