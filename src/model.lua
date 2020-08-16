local M = {}
M.__index = M

local Cpml = require 'cpml'
local Vec3 = Cpml.vec3

local private = {}

local dir = (...):gsub('.[^%.]+$', '')
local ObjParser = require(dir..'.obj_parser')
local Util = require(dir..'.util')

local sin = math.sin
local cos = math.cos

local new_mesh = love.graphics.newMesh

M.mesh_format = {
  { 'VertexPosition', 'float', 3 },
  { 'VertexTexCoord', 'float', 2 },
  { 'VertexNormal', 'float', 3 },
}

M.transform_mesh_format = {
  { 'ModelPos', 'float', 3 },
  { 'ModelMatC1', 'float', 3 },
  { 'ModelMatC2', 'float', 3 },
  { 'ModelMatC3', 'float', 3 },
  { 'ModelAlbedo', 'byte', 4 },
  { 'ModelPhysics', 'byte', 4 },
}

M.default_opts = {
  write_depth = true,
  face_culling = 'back', -- 'back', 'front', 'none'
  instance_usage = 'dynamic', -- see love2d SpriteBatchUsage. dynamic, static, stream. defualt: dynamic
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

function M.new_plane(w, h)
  local vertices = private.gen_vertices({
    { 0, 0, 0, 0, 0 },
    { w, 0, 0, 1, 0 },
    { w, 0, h, 1, 1 },
    { 0, 0, h, 0, 1 },
  }, { { 4, 3, 2, 1 } })
  return M.new(vertices)
end

function M.new_circle(radius, n)
  if not n then n = 16 end
  local vs = {}
  local p = math.pi * 2 / n
  local f = {}
  for i = 1, n do
    local v = i * p
    local c, s = cos(v), sin(v)
    table.insert(vs, { c * radius, 0, s * radius, (c + 1) * 0.5, (s + 1) * 0.5 })
    table.insert(f, i)
  end

  local vertices = private.gen_vertices(vs, { f })
  return M.new(vertices)
end

-- xlen: size of x axis
-- ylen: optional, size of y axis, default equal to xlen
-- zlen: optional, size of z axis, default equal to xlen
function M.new_box(xlen, ylen, zlen)
  assert(xlen, "Invalid box size")
  local hx = xlen / 2
  local hy = ylen or xlen
  local hz = (zlen or xlen) / 2

  local vs = {
    { -hx, 0, -hz, 0, 0 }, { hx, 0, -hz, 1, 0 }, { hx, 0, hz, 1, 1 }, { -hx, 0, hz, 0, 1 },
    { -hx, hy, -hz, 0, 0 }, { hx, hy, -hz, 1, 0 }, { hx, hy, hz, 1, 1 }, { -hx, hy, hz, 0, 1 },
  }

  local fs = {
    { 1, 2, 3, 4 }, { 8, 7, 6, 5 },
    { 5, 6, 2, 1 }, { 7, 8, 4, 3 },
    { 6, 7, 3, 2 }, { 8, 5, 1, 4 },
  }

  local vertices = private.gen_vertices(vs, fs)
  return M.new(vertices, false)
end

function M.new_cylinder(radius, height, n)
  if not n then n = 16 end

  local vs, vs2 = {}, {}
  local p = math.pi * 2 / n
  local tf, bf = {}, {}
  for i = 1, n do
    local v = i * p
    local c, s = cos(v), sin(v)
    table.insert(vs, { c * radius, 0, s * radius, (c + 1) * 0.5, (s + 1) * 0.5 })
    table.insert(vs2, { c * radius, height, s * radius, (c + 1) * 0.5, (s + 1) * 0.5 })
    table.insert(bf, i)
    table.insert(tf, n + n - i + 1)
  end

  local fs = { tf, bf }
  private.link_vertices(vs, fs, vs2)

  for i = 3, #fs do
    local f = fs[i]
    for j, vi in ipairs(f) do
      local v = vs[vi]
      f[j] = { vi, vn = { Vec3(v[1], 0, v[3]):normalize():unpack() } }
    end
  end

  local vertices = private.gen_vertices(vs, fs)
  return M.new(vertices)
end


-- rx, ry, rz: radius of axis
-- n: segments of split
function M.new_sphere(rx, ry, rz, n)
  assert(rx, "Radius cannot be nil")
  if not ry then ry = rx end
  if not rz then rz = rx end
  if not n then n = 16 end

  local pr = math.pi * 2 / n
  local hpr = pr * 0.5
  local vs, fs = { {0, ry * 2, 0 } }, {}
  local last_layer = nil
  for i = 1, n - 1 do
    local tvs = {}
    local y = cos(i * hpr) * ry + ry
    for j = n, 1, - 1 do
      local s = sin(i * pr * 0.5)
      table.insert(tvs, {
        cos(j * pr) * rx * s,
        y,
        sin(j * pr) * rz * s
      })
    end
    if last_layer then
      private.link_vertices(vs, fs, tvs)
    end
    last_layer = tvs
  end

  private.link_vertices(vs, fs, {{ 0, 0, 0 }}, #last_layer)

  for i, f in ipairs(fs) do
    for j, vi in ipairs(f) do
      local v = vs[vi]
      f[j] = { vi, vn = { Vec3(v[1], v[2] - ry, v[3]):normalize():unpack() } }
    end
  end

  local vertices = private.gen_vertices(vs, fs)
  return M.new(vertices)
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

-- vertices:
-- texture
-- optsions:
--  write_depth:
--  face_culling: 'back' or 'front' or 'none'
--  instance_usage: see love2d SpriteBatchUsage. dynamic, static, stream. defualt: dynamic
function M:init(vertices, texture, opts)
  self.mesh = new_mesh(M.mesh_format, vertices, "triangles", 'static')
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

-- transforms: { { coord = vec3, rotation = vec3, scale = number or vec3, albedo = vec3 or vec4, physics = vec2 }, ... }
--  coord is required, other is optionals
function M:set_instances(transforms)
  local raw_tf = {}
  for i, tf in ipairs(transforms) do
    local x, y, z, rx, ry, rz, sx, sy, sz, ar, ag, ab, aa, pr, pm
    local coord = tf.coord
    local rotation = tf.rotation or default_rotation
    local scale = tf.scale or default_scale
    local albedo = tf.albedo or default_albedo
    local physics = tf.physics or default_physics

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

    local tfm = Util.build_model_mat4(Vec3(rx, ry, rz), Vec3(sx, sy, sz))

    table.insert(raw_tf, {
      x, y, z,
      tfm[1], tfm[2], tfm[3],
      tfm[5], tfm[6], tfm[7],
      tfm[9], tfm[10], tfm[11],
      ar, ag, ab, aa or 1,
      pr, pm
    })
  end

  self:set_raw_instances(raw_tf)
end

-- transforms: { instance1_attrs, instance2_attrs, ... }
function M:set_raw_instances(transforms)
  local tfs_mesh = self.instances_mesh
  if self.instances_mesh and self.total_instances >= #transforms then
    tfs_mesh:setVertices(transforms)
  else
    tfs_mesh = new_mesh(M.transform_mesh_format, transforms, nil, self.options.instance_usage)
    self.mesh:attachAttribute('ModelPos', tfs_mesh, 'perinstance')
    self.mesh:attachAttribute('ModelMatC1', tfs_mesh, 'perinstance')
    self.mesh:attachAttribute('ModelMatC2', tfs_mesh, 'perinstance')
    self.mesh:attachAttribute('ModelMatC3', tfs_mesh, 'perinstance')
    self.mesh:attachAttribute('ModelAlbedo', tfs_mesh, 'perinstance')
    self.mesh:attachAttribute('ModelPhysics', tfs_mesh, 'perinstance')
    self.instances_mesh = tfs_mesh
  end

  self.total_instances = #transforms
end

-----------------------

-- fs: faces, { { vidx1, vidx2, vidx3, ... }, ... }
--        or { { { vidx1, vn = { x, y, z } }, { vidx2, vn = normal2 }, { vidx3, vn = normal3 }, ... }, ... }
function private.gen_vertices(vs, fs)
  if not fs then return vs end
  local vertices = {}

  for i, face in ipairs(fs) do
    local first = face[1]
    local last = face[2]
    local first_vi, first_vn, last_vi, last_vn
    if type(first) == 'number' then
      first_vi = first
    else
      first_vi, first_vn = first[1], first.vn
    end

    if type(last) == 'number' then
      last_vi, last_vn = last, nil
    else
      last_vi, last_vn = last[1], last.vn
    end

    for j = 3, #face do
      local c = face[j]
      local vn1, vn2 = first_vn, last_vn
      local vi1, vi2 = first_vi, last_vi
      local vi3, vn3
      if type(c) == 'number' then
        vi3 = c
      else
        vi3, vn3 = c[1], c.vn
      end
      local v1, v2, v3 = vs[vi1], vs[vi2], vs[vi3]
      if not vn1 or not vn2 or not vn3 then
        local vn = private.get_normal(v1, v2, v3)
        if not vn1 then vn1 = vn end
        if not vn2 then vn2 = vn end
        if not vn3 then vn3 = vn end
      end

      table.insert(vertices, { v1[1], v1[2], v1[3], v1[4] or 0, v1[5] or 0, vn1[1], vn1[2], vn1[3] })
      table.insert(vertices, { v2[1], v2[2], v2[3], v2[4] or 0, v2[5] or 0, vn2[1], vn2[2], vn2[3] })
      table.insert(vertices, { v3[1], v3[2], v3[3], v3[4] or 0, v3[5] or 0, vn3[1], vn3[2], vn3[3] })
      last_vi, last_vn = vi3, vn3
    end
  end

  return vertices
end

function private.get_normal(v1, v2, v3)
  local nx = (v2[2] - v1[2]) * (v3[3] - v1[3]) - (v2[3] - v1[3]) * (v3[2] - v1[2])
  local ny = (v2[3] - v1[3]) * (v3[1] - v1[1]) - (v2[1] - v1[1]) * (v3[3] - v1[3])
  local nz = (v2[1] - v1[1]) * (v3[2] - v1[2]) - (v2[2] - v1[2]) * (v3[1] - v1[1])
  return { nx , ny, nz }
end

-- vs: table to out vertices.
-- fs: table to output faces.
-- new_vs: vertices to add. { { x, y, z }, { x2, y2, z2 } }
-- s_total: 1-N or N-N
function private.link_vertices(vs, fs, new_vs, s_total)
  local t_total = #new_vs
  if not s_total then s_total = math.min(#vs, t_total) end

  local eidx = #vs
  local sidx = eidx - s_total + 1

  if s_total == t_total then
    -- n - n
    local last = t_total
    for i, v in ipairs(new_vs) do
      table.insert(vs, v)
      table.insert(fs, { sidx + i - 1, sidx + last - 1, eidx + last, eidx + i })
      last = i
    end
  elseif s_total == 1 then
    -- 1 - n
    local last = t_total
    for i, v in ipairs(new_vs) do
      table.insert(vs, v)
      table.insert(fs, { sidx, sidx + last, sidx + i })
      last = i
    end
  elseif t_total == 1 then
    -- n - 1
    table.insert(vs, new_vs[1])
    local nv = #vs
    local last = eidx
    for i = 1, s_total do
      table.insert(fs, { last, nv, sidx + i - 1 })
      last = sidx + i - 1
    end
  else
    error(string.format("Invalid new vertices: s: %i t: %i", s_total, t_total))
  end

  return vs, fs
end

return M
