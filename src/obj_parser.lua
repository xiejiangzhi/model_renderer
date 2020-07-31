local M = {}
local private = {}
local empty = {}


function M.parse_file(path)
	assert(path and love.filesystem.getInfo(path), "Not found model file "..tostring(path))
  local data = {
		v	= {}, vt	= {}, vn	= {}, vp	= {}, f	= {},
    mtllib = {}, usemtl = {}, o = {}, g = {},
    last_obj_idx = 0, last_group_idx = 0, last_mtl_idx = 0,
	}
	for line in love.filesystem.lines(path) do
    private.parse_line(line, data)
	end

  local dir = path:gsub('[^/]+$', '')
  for i, name in ipairs(data.mtllib) do
    private.parse_mtl_file(dir..name, data.mtllib)
  end
  return data
end

function M.parse_face(data)
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

-------------------------------------

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
  elseif ctg == 'mtllib' then
    table.insert(data[ctg], l[2])
  elseif ctg == 'usemtl' then
    local fidx = #data.f
    table.insert(data[ctg], { l[2], data.last_mtl_idx + 1, fidx })
    data.last_mtl_idx = fidx
  elseif ctg == 'o' then
    local fidx = #data.f
    table.insert(data[ctg], { l[2], data.last_obj_idx + 1, fidx })
    data.last_obj_idx = fidx
  elseif ctg == 'g' then
    local fidx = #data.f
    table.insert(data[ctg], { l[2], data.last_group_idx + 1, fidx })
    data.last_group_idx = fidx
  end
end

function private.parse_mtl_file(path, data)
	if not (path and love.filesystem.getInfo(path)) then
    print("Not found mtl file "..tostring(path))
    return
  end

  for line in love.filesystem.lines(path) do
    private.parse_mtl_line(line, data)
	end

  return data
end

local mtl_attrs = {
  Ns = 'number',
  Ka = 'number',
  Kd = 'number',
  Ks = 'number',
  Ke = 'number',
  Ni = 'number',
  d = 'number',
  illum = 'number',
  Tr = 'number',
}
function private.parse_mtl_line(line, data)
	local l = private.split(line)
  local ctg = l[1]

  local last_mtl = data.__last_mtl

  if ctg == 'newmtl' then
    last_mtl = {}
    data[l[2]] = last_mtl
    data.__last_mtl = last_mtl
  elseif ctg and ctg ~= '' and ctg ~= '#' then
    local vtype = mtl_attrs[ctg]
    if vtype then
      local r = {}
      for i = 2, #l do
        table.insert(r, tonumber(l[i]))
      end
      last_mtl[ctg] = r
    else
      last_mtl[ctg] = { unpack(l, 2) }
    end
  end
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
