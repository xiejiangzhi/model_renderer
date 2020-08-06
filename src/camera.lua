local M = {}
M.__index = M

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
  self.pos = Vec3(0, 800, 0)
  self.rotation = Vec3(0, 0, 0)

  self.focus_offset = Vec3(0, 0, 0)
  self.focus = Vec3(0, 0, 0)

  self.projection = nil
end

function M:move_to(x, y, z)
  local c = self.pos
  c.x, c.y, c.z = x, y, z
  self.focus = self.pos + self.focus_offset
end

function M:rotate(x, y, z)
  local r = self.rotation
  r.x, r.y, r.z = x, y, z
  self:update_focus_offset()
end

function M:update_focus_offset()
  local r = self.rotation
  local offset = Vec3(0, -self.sight_dist, 0)
    :rotate(r.z, Vec3.unit_z)
    :rotate(r.x, Vec3.unit_x)
    :rotate(r.y, Vec3.unit_y)

  self.focus_offset = offset
  self.focus = self.pos + self.focus_offset
end

function M:perspective(fovy, aspect, near, far)
  self.projection = Mat4.from_perspective(fovy, aspect, near, far)
end

function M:orthogonal(left, right, top, bottom, near, far)
  self.projection = Mat4.from_ortho(left, right, top, bottom, near, far)
end

function M:build_view()
  local view = Mat4()
  view:look_at(view, self.pos, self.pos + self.focus_offset, Vec3.unit_y)
  return view
end

return M
