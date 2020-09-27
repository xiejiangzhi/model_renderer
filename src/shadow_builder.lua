local M = {}
M.__index = M
-- local private = {}

local lg = love.graphics

local code_dir = (...):gsub('.[^%.]+$', '')
local file_dir = code_dir:gsub('%.', '/')

local Cpml = require 'cpml'
local Mat4 = Cpml.mat4
local Vec3 = Cpml.vec3

local Util = require(code_dir..'.util')

function M.new(...)
  local obj = setmetatable({}, M)
  obj:init(...)
  return obj
end

function M:init(w, h)
  self.w, self.h = w, h
  self.shadow_depth_map = Util.new_depth_map(w, h, 'less', 'depth24')
  self.shadow_shader = lg.newShader(file_dir..'/shader/shadow.glsl')
end

function M:build(scene, camera_space_vertices, sun_dir)
  local shadow_shader = self.shadow_shader
  Util.push_render_env({ depthstencil = self.shadow_depth_map }, shadow_shader)
  lg.clear(0, 0, 0, 0)

  local light_proj_view = self:calc_proj_view(camera_space_vertices, sun_dir)

	shadow_shader:send("projViewMat", 'column', light_proj_view)

	lg.setDepthMode("less", true)
	lg.setMeshCullMode('front')

  for i, model in ipairs(scene.model) do
    local mesh = model.mesh
    local tex = mesh:getTexture()
    if tex then shadow_shader:send("MainTex", tex) end
    lg.drawInstanced(mesh, model.total_instances)
  end

	lg.setMeshCullMode('none')
  lg.setDepthMode()

  Util.pop_render_env()

  return self.shadow_depth_map, light_proj_view
end

function M:calc_proj_view(camera_space_vertices, sun_dir)
  local min_v, max_v = self:calc_sight_bbox(camera_space_vertices)
  local center = Util.vertices_center({ min_v, max_v })
  local max_dist = (max_v - min_v):len()
  local hdist = max_dist / 2
  local offset = Vec3(sun_dir):normalize() * hdist

  local projection = Mat4.from_ortho(-hdist, hdist, hdist, -hdist, 0, max_dist)
  local view = Mat4()
  view = view:look_at(view, center + offset, center, Vec3(0, 1, 0))

  return Mat4.new():mul(projection, view)
end

function M:calc_sight_bbox(camera_space_vertices)
  local vts = {}
  for i = 1, #camera_space_vertices, 2 do
    local near, far = camera_space_vertices[i], camera_space_vertices[i + 1]
    vts[i] = near
    vts[i + 1] = near + (far - near) * 1
  end

  local min_v, max_v = Util.vertices_bbox(vts)
  return min_v, max_v
end

return M
