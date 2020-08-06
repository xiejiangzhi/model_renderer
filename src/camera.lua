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
end

function M:perspective(fovy, aspect, near, far)
  self.projection = Mat4.from_perspective(fovy, aspect, near, far)
end

function M:orthogonal(left, right, top, bottom, near, far)
  self.projection = Mat4.from_ortho(left, right, top, bottom, near, far)
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
end

--- point: { x, y, z} or { x = x, y = y, z = z }
function M:project(point, viewport)
  if not self.projection then error("Must set projection mat4") end
  if not self.view then error("Must set view mat4") end

  if not viewport then viewport = { -1, -1, 2, 2 } end
  return Mat4.project(point, self.view, self.projection, viewport)
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

return M
