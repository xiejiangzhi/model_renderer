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
  if not n then n = 10 end
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
  if not ylen then ylen = xlen end
  if not zlen then zlen = xlen end

  local vs = {
    { 0, 0, 0, 0, 0 }, { xlen, 0, 0, 1, 0 }, { xlen, 0, zlen, 1, 1 }, { 0, 0, zlen, 0, 1 },
    { 0, ylen, 0, 0, 0 }, { xlen, ylen, 0, 1, 0 }, { xlen, ylen, zlen, 1, 1 }, { 0, ylen, zlen, 0, 1 },
  }

  local fs = {
    { 1, 2, 3, 4 }, { 8, 7, 6, 5 },
    { 5, 6, 2, 1 }, { 7, 8, 4, 3 },
    { 6, 7, 3, 2 }, { 8, 5, 1, 4 },
  }

  local vertices = private.gen_vertices(vs, fs)
  return M.new(vertices, false)
end

-- density: 3 - n, how many parts for each axis
-- rx, ry, rz: radius of axis
-- function M.new_sphere(density, rx, ry, rz)
--   if not density then density = 10 end
--   assert(density > 2, "Density must >= 3")
--   assert(rx, "radius cannot be nil")
--   if not ry then ry = rx end
--   if not rz then rz = rx end

--   for i = 1, density do
--     for j = 1, density do
--     end
--   end
-- end

--------------------

local valid_opts = {
  write_depth = true
}

-- vertices:
-- texture
-- optsions:
--  write_depth:
function M:init(vertices, texture, opts)
  self.mesh = new_mesh(M.mesh_format, vertices, "triangles", 'static')
  self.options = {}

  if texture then self:set_texture(texture) end
  if opts then self:set_opts(opts) end
end

function M:set_opts(opts)
  for k, v in pairs(opts) do
    if valid_opts[k] then
      self.options[k] = v
    else
      error("Invalid option "..k)
    end
  end
end

function M:set_texture(tex)
  self.mesh:setTexture(tex)
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

return M
