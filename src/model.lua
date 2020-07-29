local M = {}
M.__index = M
local private = {}

local empty = {}

function M.new(...)
  local obj = setmetatable({}, M)
  obj:init(...)
  return obj
end

function M:init(path)
  self.path = path
	self.data = private.parse_file(self.path)
  self.mesh = private.new_mesh(self.data)
end

-----------------------

function private.parse_file(path)
	assert(path and love.filesystem.getInfo(path), "Invalid model path "..tostring(path))
  local data = {
		v	= {}, vt	= {}, vn	= {}, vp	= {}, f	= {},
    mtllib = {}, usemtl = {}, o = {}, g = {},
	}
	for line in love.filesystem.lines(path) do
    private.parse_line(line, data)
	end
  return data
end

-- https://en.wikipedia.org/wiki/Wavefront_.obj_file
function private.parse_line(line, data)
	local l = private.split(line)
  local ctg = l[1]
  if ctg == "v" then
    table.insert(data[ctg], { tonumber(l[2]), tonumber(l[3]), tonumber(l[4]), tonumber(l[5]) })
  elseif l[1] == "vt" then
    table.insert(data[ctg], { tonumber(l[2]), tonumber(l[3]), tonumber(l[4]) })
  elseif ctg == "vn" then
    table.insert(data[ctg], { tonumber(l[2]), tonumber(l[3]), tonumber(l[4]) })
  elseif ctg == "vp" then
    table.insert(data[ctg], { tonumber(l[2]), tonumber(l[3]), tonumber(l[4]) })
  elseif ctg == "f" then
    local f = {}

    for i = 2, #l do
      local fdesc = private.split(l[i], "/")
      local v = {}
      v.v = tonumber(fdesc[1])
      v.vt = tonumber(fdesc[2])
      v.vn = tonumber(fdesc[3])
      table.insert(f, v)
    end

    table.insert(data[ctg], f)
  end
end

function private.new_mesh(data)
  local vertices = private.parse_face(data)

  return love.graphics.newMesh({
    { 'VertexPosition', 'float', 3 },
    { 'VertexTexCoord', 'float', 2 },
    { 'VertexNormal', 'float', 3 },
  }, vertices, "triangles")
end

function private.parse_face(data)
  local vertices = {}
  local v, vt, vn = data.v, data.vt, data.vn

  for i, face in ipairs(data.f) do
    local first = face[1]
    local last = face[2]
    for j = 3, #face do
      local vi1, vi2, vi3 = first.v, last.v, face[j].v
      local ti1, ti2, ti3 = first.vt or -1, last.vt or -1, face[j].vt or -1
      local ni1, ni2, ni3 = first.vn or -1, last.vn or -1, face[j].vn or -1
      local v1, v2, v3 = v[vi1], v[vi2], v[vi3]
      local vt1, vt2, vt3 = vt[ti1] or empty, vt[ti2] or empty, vt[ti3] or empty
      local vn1, vn2, vn3 = vn[ni1] or empty, vn[ni2] or empty, vn[ni3] or empty
      table.insert(vertices, { v1[1], v1[2], v1[3], vt1[1] or 0, vt1[2] or 0, vn1[1], vn1[2], vn1[3] })
      table.insert(vertices, { v2[1], v2[2], v2[3], vt2[1] or 0, vt2[2] or 0, vn2[1], vn2[2], vn2[3] })
      table.insert(vertices, { v3[1], v3[2], v3[3], vt3[1] or 0, vt3[2] or 0, vn3[1], vn3[2], vn3[3] })
      last = face[j]
    end
  end

  return vertices
end

function private.split(str, seq)
	local t = {}
	local i = 0
  local match
  if seq then
    match = '(.-)('..seq..')'
  else
    seq = ' '
    match = '([%S]+)'
  end

	for sub, j in string.gmatch(str..seq, match) do
		i = i + 1
		t[i] = sub
	end
	if i == 0 then t[0] = str end

	return t
end

return M