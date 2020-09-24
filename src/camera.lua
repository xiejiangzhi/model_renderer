local M = {}
M.__index = M

local private = {}

local code_dir = (...):gsub('.[^%.]+$', '')
local file_dir = code_dir:gsub('%.', '/')
local Cpml = require 'cpml'
local Vec3 = Cpml.vec3
local Mat4 = Cpml.mat4

function M.new(...)
  local obj = setmetatable({}, M)
  obj:init(...)
  return obj
end

function M:init()
  self.sight_dist = 1000

  self.rotation = Vec3(0, 0, 0)
  self.offset = Vec3(0, 0, 0)

  self.pos = Vec3(0, 800, 0)
  self.focus = Vec3(0, 0, 0)

  self.near = 1
  self.far = 1000
  self.fov = nil

  self.projection = nil
  self.view = Mat4.new()

  self.cache = {}

  self.shader_2d = love.graphics.newShader(file_dir..'/shader/2d.glsl')
end

function M:perspective(fovy, aspect, near, far)
  if not near then near = self.near end
  if not far then far = self.far end
  self.near, self.far = near, far
  self.projection = Mat4.from_perspective(fovy, aspect, near, far)
  self.fov = fovy
  self.cache = {}
end

function M:orthogonal(left, right, top, bottom, near, far)
  if not near then near = self.near end
  if not far then far = self.far end
  self.near, self.far = near, far
  self.projection = Mat4.from_ortho(left, right, top, bottom, near, far)
  self.cache = {}
end

-- camera based
-- x, y, z: pos
-- rx, ry, rz: angle
function M:move_to(x, y, z, rx, ry, rz)
  local p = self.pos
  p.x, p.y, p.z = x, y, z
  local r = self.rotation
  r.x, r.y, r.z = rx, ry, rz

  self.offset = private.get_offset(self.sight_dist, rx, ry, rz)
  self.focus = p + self.offset
  self.view = private.build_view(self.view, self.pos, self.focus)
  self.cache = {}
end

-- target based
-- x, y, z: pos
-- rx, ry, rz: angle
function M:look_at(x, y, z, rx, ry, rz)
  local f = self.focus
  f.x, f.y, f.z = x, y, z
  local r = self.rotation
  r.x, r.y, r.z = rx, ry, rz

  self.offset = private.get_offset(self.sight_dist, rx, ry, rz)
  self.pos = f - self.offset
  self.view = private.build_view(self.view, self.pos, self.focus)
  self.cache = {}
end

--- point: { x, y, z} or { x = x, y = y, z = z }
function M:project(point, viewport)
  if not self.projection then error("Must set projection mat4") end
  if not self.view then error("Must set view mat4") end
  if not viewport then viewport = { -1, -1, 2, 2 } end

  local proj_view  = self:fetch_cache('proj_view')
  return private.project(point, proj_view, viewport)
end

local default_unproject_plane = {
  position = Cpml.vec3(0, 0, 0),
  normal = Cpml.vec3(0, 1, 0),
}
-- viewport: XYWH
-- plane.position vec3
-- plane.normla vec3
function M:unproject(screen_x, screen_y, viewport, plane)
  if not self.projection then error("Must set projection mat4") end
  if not self.view then error("Must set view mat4") end

  local inverted_proj_view = self:fetch_cache('inverted_proj_view')
  local point = Cpml.vec3(screen_x, screen_y, 0)
  local wp1 = private.unproject(point, inverted_proj_view, viewport)
  point.z = 1
  local wp2 = private.unproject(point, inverted_proj_view, viewport)
  if not plane then plane = default_unproject_plane end

  return Cpml.intersect.ray_plane({ position = wp1, direction = wp2 - wp1 }, plane)
end

-- plane_transform: a matrix to transform the 2d plane
function M:attach(plane_transform)
  local proj_view = self:fetch_cache('proj_view')

  if not plane_transform then
    plane_transform = Mat4.identity()
    plane_transform:rotate(plane_transform, math.pi * 0.5, Vec3.unit_x)
  end
  local tfp = Mat4.new()
  tfp:mul(proj_view, plane_transform)
  self.shader_2d:send('tfp', 'column', tfp)

  love.graphics.setShader(self.shader_2d)
  love.graphics.setDepthMode("less", true)
end

function M:detach()
  love.graphics.setShader()
  love.graphics.setDepthMode()
end

-- Params:
--  near, far: 0 - 1
-- Return:
--  {
--    left_top_near, left_top_far, right_top_near, right_top_far
--    left_bottom_near, left_bottom_far, right_bottom_near, right_bottom_far
--  }
function M:get_space_vertices(near, far)
  local vertices = {}
  local viewport = { 0, 0, 1, 1 }
  local inverted_proj_view = self:fetch_cache('inverted_proj_view')

  for y = 0, 1 do
    for x = 0, 1 do
      table.insert(vertices, private.unproject(
        Vec3(x, y, near or 0), inverted_proj_view, viewport
      ))
      table.insert(vertices, private.unproject(
        Vec3(x, y, far or 1), inverted_proj_view, viewport
      ))
    end
  end

  return vertices
end

local CacheCodes = {
  proj_view = {
    proj_view = true
  },
  inverted_proj_view = {
    proj_view = true,
    inverted_proj_view = true
  }
}
function M:fetch_cache(name)
  local desc = CacheCodes[name]
  if not desc then error("Invalid cache name '"..tostring(name).."'") end
  local cache = self.cache

  if not cache.proj_view and desc.proj_view then
    cache.proj_view = Mat4()
    Mat4.mul(cache.proj_view, self.projection, self.view)
  end

  if not cache.inverted_proj_view and desc.inverted_proj_view then
    cache.inverted_proj_view = Mat4()
    cache.inverted_proj_view:invert(cache.proj_view)
  end

  return cache[name]
end

----------------------

function private.get_offset(dist, rx, ry, rz)
  return Vec3(0, -dist, 0)
    :rotate(rz, Vec3.unit_z)
    :rotate(rx, Vec3.unit_x)
    :rotate(ry, Vec3.unit_y)
end

function private.build_view(out, eye, target)
  out:look_at(out, eye, target, Vec3.unit_y)
  return out
end

function private.project(vec3, proj_view, viewport)
	local position = { vec3.x, vec3.y, vec3.z, 1 }

	Mat4.mul_vec4(position, proj_view, position)

	position[1] = position[1] / position[4] * 0.5 + 0.5
	position[2] = position[2] / position[4] * 0.5 + 0.5
	position[3] = position[3] / position[4] * 0.5 + 0.5

	position[1] = position[1] * viewport[3] + viewport[1]
	position[2] = position[2] * viewport[4] + viewport[2]

	return vec3(position[1], viewport[4] - position[2], position[3])
end

function private.unproject(vec3, inverted_proj_view, viewport)
	local position = { vec3.x, viewport[4] - vec3.y, vec3.z, 1 }

	position[1] = (position[1] - viewport[1]) / viewport[3]
	position[2] = (position[2] - viewport[2]) / viewport[4]

	position[1] = position[1] * 2 - 1
	position[2] = position[2] * 2 - 1
	position[3] = position[3] * 2 - 1

	Mat4.mul_vec4(position, inverted_proj_view, position)

	position[1] = position[1] / position[4]
	position[2] = position[2] / position[4]
	position[3] = position[3] / position[4]

	return vec3(position[1], position[2], position[3])
end

return M
