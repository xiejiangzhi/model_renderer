local M = {}
M.__index = M

local private = {}

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

  self.projection = nil
  self.view = Mat4.new()

  self.cache = {}
end

function M:perspective(fovy, aspect, near, far)
  self.projection = Mat4.from_perspective(fovy, aspect, near, far)
  self.cache = {}
end

function M:orthogonal(left, right, top, bottom, near, far)
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
  r.x, r.y, r.z = x, y, z

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
  r.x, r.y, r.z = x, y, z

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

  local cache = self.cache
  if not cache.proj_view then
    cache.proj_view = Mat4()
    Mat4.mul(cache.proj_view, self.projection, self.view)
  end

  return private.project(point, cache.proj_view, viewport)
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

  local cache = self.cache
  if not cache.proj_view then
    cache.proj_view = Mat4()
    Mat4.mul(cache.proj_view, self.projection, self.view)
  end

  if not cache.inverted_proj_view then
    cache.inverted_proj_view = Mat4()
    cache.inverted_proj_view:invert(cache.proj_view)
  end

  local point = Cpml.vec3(screen_x, viewport[4] - screen_y, 0)
  local wp1 = private.unproject(point, cache.inverted_proj_view, viewport)
  point.z = 1
  local wp2 = private.unproject(point, cache.inverted_proj_view, viewport)
  if not plane then plane = default_unproject_plane end

  return Cpml.intersect.ray_plane({ position = wp1, direction = wp2 - wp1 }, plane)
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

	return vec3(position[1], position[2], position[3])
end

function private.unproject(vec3, inverted_proj_view, viewport)
	local position = { vec3.x, vec3.y, vec3.z, 1 }

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