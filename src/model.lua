local M = {}
M.__index = M

local private = {}

local dir = (...):gsub('.[^%.]+$', '')
local ObjParser = require(dir..'.obj_parser')

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
  { 'ModelAngle', 'float', 3 },
  { 'ModelScale', 'float', 3 },
  { 'ModelAlbedo', 'byte', 4 },
  { 'ModelPhysics', 'byte', 4 },
}

M.default_opts = {
  write_depth = true,
  face_culling = 'back', -- 'back', 'front', 'none'
}
M.default_opts.__index = M.default_opts

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
  local hy = (ylen or xlen) / 2
  local hz = (zlen or xlen) / 2

  local vs = {
    { -hx, -hy, -hz, 0, 0 }, { hx, -hy, -hz, 1, 0 }, { hx, -hy, hz, 1, 1 }, { -hx, -hy, hz, 0, 1 },
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
  local vs, fs = { {0, ry, 0 } }, {}
  local last_layer = nil
  for i = 1, n - 1 do
    local tvs = {}
    local y = cos(i * hpr) * ry
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

  private.link_vertices(vs, fs, {{ 0, -ry, 0 }}, #last_layer)

  -- local vs, fs = private.link_vertices(vs1, vs2)
  -- fs[#fs + 1] = tf
  -- fs[#fs + 1] = bf

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

function M:set_instances(transforms)
  local tfs_mesh = self.instances_mesh
  if self.instances_mesh and self.total_instances >= #transforms then
    tfs_mesh:setVertices(transforms)
  else
    tfs_mesh = new_mesh(M.transform_mesh_format, transforms, nil, 'dynamic')
    self.mesh:attachAttribute('ModelPos', tfs_mesh, 'perinstance')
    self.mesh:attachAttribute('ModelAngle', tfs_mesh, 'perinstance')
    self.mesh:attachAttribute('ModelScale', tfs_mesh, 'perinstance')
    self.mesh:attachAttribute('ModelAlbedo', tfs_mesh, 'perinstance')
    self.mesh:attachAttribute('ModelPhysics', tfs_mesh, 'perinstance')
    self.instances_mesh = tfs_mesh
  end

  self.total_instances = #transforms
end

-----------------------

function private.gen_vertices(vs, fs)
  if not fs then return vs end
  local vertices = {}

  for i, face in ipairs(fs) do
    local first = face[1]
    local last = face[2]

    for j = 3, #face do
      local vi1, vi2, vi3 = first, last, face[j]
      local v1, v2, v3 = vs[vi1], vs[vi2], vs[vi3]

      local vn = private.get_normal(v1, v2, v3)

      table.insert(vertices, { v1[1], v1[2], v1[3], v1[4] or 0, v1[5] or 0, vn[1], vn[2], vn[3] })
      table.insert(vertices, { v2[1], v2[2], v2[3], v2[4] or 0, v2[5] or 0, vn[1], vn[2], vn[3] })
      table.insert(vertices, { v3[1], v3[2], v3[3], v3[4] or 0, v3[5] or 0, vn[1], vn[2], vn[3] })
      last = face[j]
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

-- sidx: start index of vs
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
