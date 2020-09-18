local M = {}
local private = {}
local Cpml = require 'cpml'
local Vec3 = Cpml.vec3

local code_dir = (...):gsub('.[^%.]+$', '')

local file_dir = code_dir:gsub('%.', '/')
local shader_dir = file_dir..'/shader'

local lfs = love.filesystem
local lg = love.graphics

local random = love.math.random
local min = math.min
local max = math.max

function M.send_uniform(shader, k, ...)
  if shader:hasUniform(k) then
    shader:send(k, ...)
  end
end

-- new_shader('pixel.glsl', 'vertex.glsl')
function M.new_shader(pixel, vertex, macros)
  local list = { pixel, vertex }
  local code = {}
  local fid = 0
  local macros_code, total_lines = private.build_macros(macros)

  for i, filename in ipairs(list) do
    local str = macros_code
    local line_no = total_lines
    for line in lfs.lines(filename) do
      line_no = line_no + 1
      local include_name = line:match('^#include_glsl%s+([a-zA-Z0-9_%.-]+)%s*$')
      if include_name then
        fid = fid + 1
        str = str..'#line 1 '..fid..'\n'
        str = str..private.read_glsl(include_name, filename)..'\n'
        str = str..'#line '..(line_no + 1)..' 0\n'
      else
        str = str..line..'\n'
      end
    end
    code[i] = str
  end

  return love.graphics.newShader(unpack(code))
end

function M.send_uniforms(shader, uniforms)
  for i, v in ipairs(uniforms) do
    M.send_uniform(shader, unpack(v))
  end
end

function M.compute_face_normal(v1, v2, v3)
  local nx = (v2[2] - v1[2]) * (v3[3] - v1[3]) - (v2[3] - v1[3]) * (v3[2] - v1[2])
  local ny = (v2[3] - v1[3]) * (v3[1] - v1[1]) - (v2[1] - v1[1]) * (v3[3] - v1[3])
  local nz = (v2[1] - v1[1]) * (v3[2] - v1[2]) - (v2[2] - v1[2]) * (v3[1] - v1[1])
  return { nx, ny, nz }
end

-- Params:
--  vs: vertices, { { x, y, z }, { x2, y2, z2 }, { x3,y3,z3 } }
--    or { { x,y,z, texture_x, texture_y }, { x,y,z, texture_x, texture_y }, { x,y,z, texture_x, texture_y } }
--  fs: faces, { { vidx1, vidx2, vidx3, ... }, ... }
--    or { { { vidx1, vn = { x, y, z } }, { vidx2, vn = normal2 }, { vidx3, vn = normal3 }, ... }, ... }
-- generate_vertices({{ x, y, z }, { x2, y2, z2 }, { x3, y3, z3 }, { x4, y4, z4 }}, {{ 1, 2, 3 }, { 2, 3, 4 }})
function M.generate_vertices(vs, fs, vertex_build_cb)
  if not fs then return vs end
  if not vertex_build_cb then vertex_build_cb = private.build_vertex end

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
        local vn = M.compute_face_normal(v1, v2, v3)
        if not vn1 then vn1 = vn end
        if not vn2 then vn2 = vn end
        if not vn3 then vn3 = vn end
      end

      table.insert(vertices, vertex_build_cb(v1, vn1))
      table.insert(vertices, vertex_build_cb(v2, vn2))
      table.insert(vertices, vertex_build_cb(v3, vn3))
      last_vi, last_vn = vi3, vn3
    end
  end

  return vertices
end

function M.generate_ssao_data()
  local size = 8
  local ssao_sample_data = love.image.newImageData(size ,size)
  ssao_sample_data:mapPixel(function()
    return random(), random(), random(), random()
  end)
  local ssao_samples = lg.newImage(ssao_sample_data)
  ssao_samples:setWrap('repeat', 'repeat')
  return ssao_samples
end

function M.generate_brdf_lut(size)
  local shader = lg.newShader(file_dir..'/shader/brdf_lut.glsl')
  local old_shader = lg.getShader()
  local old_canvas = lg.getCanvas()
  local canvas = lg.newCanvas(size, size, { type = '2d', format = 'rg16f' })

  lg.setShader(shader)
  lg.setCanvas(canvas)

  -- must flip Y when render to canvas
  local mesh = lg.newMesh({
    { 0, 0, 0, 1 }, { size, 0, 1, 1 }, { size, size, 1, 0 }, { 0, size, 0, 0 }
  }, 'fan', 'static')
  lg.draw(mesh)

  canvas:setWrap('clamp', 'clamp')

  lg.setCanvas(old_canvas)
  lg.setShader(old_shader)

  return canvas
end

function M.vertices_bbox(vertices)
  local min_v, max_v = Vec3(0), Vec3(0)

  for i, v in ipairs(vertices) do
    min_v.x = min(min_v.x, v.x)
    min_v.y = min(min_v.y, v.y)
    min_v.z = min(min_v.z, v.z)
    max_v.x = max(max_v.x, v.x)
    max_v.y = max(max_v.y, v.y)
    max_v.z = max(max_v.z, v.z)
  end

  return min_v, max_v
end

function M.vertices_center(vertices)
  local center = Vec3(0, 0, 0)
  for _, v in ipairs(vertices) do
    center = center + v
  end
  return center / #vertices
end

function M.new_depth_map(w, h, mode, format)
  local canvas = lg.newCanvas(w, h, { type = '2d', format = format or 'depth32f', readable = true })
  canvas:setDepthSampleMode(mode)
  return canvas
end

-------------------------

function private.build_vertex(v, vn)
  return {
    v[1], v[2], v[3], v[4] or 0, v[5] or 0, vn[1], vn[2], vn[3], unpack(v, 6)
  }
end

function private.read_glsl(name, filename)
  local dir = filename:gsub('/[^/]+$', '')
  local path = dir..'/'..name
  if not lfs.getInfo(path) then
    path = shader_dir..'/'..name
  end
  if not lfs.getInfo(path) then error("Not found "..name) end
  return lfs.read(path)
end

function private.build_macros(macros)
  local code, total_lines = '', 0
  if not macros then return code, total_lines end
  for k, v in ipairs(macros) do
    code = code..string.format('#define %s %s', k, v)
  end
  return code, total_lines
end

return M
