local M = {}

local private = {}

local Cpml = require 'cpml'
local Vec3 = Cpml.vec3

local dir = (...):gsub('.[^%.]+$', '')
local Util = require(dir..'.util')

local sin = math.sin
local cos = math.cos

local Model

function M.inject(model_cls)
  Model = model_cls
  for k, v in pairs(M) do
    if k:match('^new_') and type(v) == 'function' then
      Model[k] = v
    end
  end
end

--------------------

function M.new_plane(w, h)
  local vertices = Util.generate_vertices({
    { 0, 0, 0, 0, 0 },
    { w, 0, 0, 1, 0 },
    { w, 0, h, 1, 1 },
    { 0, 0, h, 0, 1 },
  }, { { 4, 3, 2, 1 } })
  return Model.new(vertices)
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

  local vertices = Util.generate_vertices(vs, { f })
  return Model.new(vertices)
end

-- xlen: size of x axis
-- ylen: optional, size of y axis, default equal to xlen
-- zlen: optional, size of z axis, default equal to xlen
function M.new_box(xlen, ylen, zlen, y_offset)
  assert(xlen, "Invalid box size")
  local hx = xlen / 2
  local hy = ylen or xlen
  local hz = (zlen or xlen) / 2
  if not y_offset then y_offset = 0 end

  local vs = {
    { -hx, y_offset, -hz, 0, 0 }, { hx, y_offset, -hz, 1, 0 },
    { hx, y_offset, hz, 1, 1 }, { -hx, y_offset, hz, 0, 1 },

    { -hx, hy + y_offset, -hz, 0, 0 }, { hx, hy + y_offset, -hz, 1, 0 },
    { hx, hy + y_offset, hz, 1, 1 }, { -hx, hy + y_offset, hz, 0, 1 },
  }

  local fs = {
    { 1, 2, 3, 4 }, { 8, 7, 6, 5 },
    { 5, 6, 2, 1 }, { 7, 8, 4, 3 },
    { 6, 7, 3, 2 }, { 8, 5, 1, 4 },
  }

  local vertices = Util.generate_vertices(vs, fs)
  return Model.new(vertices, false)
end

function M.new_skybox()
  local m =  M.new_box(2, 2, 2, -1)
  m:set_opts({ face_culling = 'none', instance_usage = 'static' })
  return m
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

  local vertices = Util.generate_vertices(vs, fs)
  return Model.new(vertices)
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

  local vertices = Util.generate_vertices(vs, fs)
  return Model.new(vertices)
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

-----------------------

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
