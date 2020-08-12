local M = {}
M.__index = M
local private = {}

local code_dir = (...):gsub('.[^%.]+$', '')
local file_dir = code_dir:gsub('%.', '/')
local Cpml = require 'cpml'
local Mat4 = Cpml.mat4
local Vec3 = Cpml.vec3

local lg = love.graphics

local transform_mesh_format = {
  { 'ModelPos', 'float', 3 },
  { 'ModelAngle', 'float', 3 },
  { 'ModelScale', 'float', 3 },
  { 'ModelColor', 'byte', 4 },
}

local default_opts = {
  ambient_color = { 0.3, 0.3, 0.3 },
  light_pos = { 1000, 2000, 1000 },
  light_color = { 3000, 3000, 3000 },
}

function M.new()
  local obj = setmetatable({}, M)
  obj:init()
  return obj
end

function M:init()
  for k, v in pairs(default_opts) do self[k] = v end

  self.projection = nil
  self.view = nil
  self.view_scale = 1
  self.camera_pos = nil
  self.look_at = { 0, 0, 0 }
  self.render_shadow = true

  self.shadow_resolution = { 1024, 1024 }
  local w, h = unpack(self.shadow_resolution)
  self.shadow_depth_map = private.new_depth_map(w, h, 'less')

  self.render_shader = lg.newShader(file_dir..'/shader/pbr.glsl', file_dir..'/shader/vertex.glsl')
  self.shadow_shader = lg.newShader(file_dir..'/shader/shadow.glsl')
end

function M:apply_camera(camera)
  self.projection = camera.projection
  self.view = camera.view
  self.camera_pos = { camera.pos:unpack() }
  self.look_at = { camera.focus:unpack() }
end

-- {
--  model = { m1, m2, m3 }
-- }
function M:render(scene)
  if self.render_shadow then self:build_shadow_map(scene) end
  self:render_scene(scene)
end

function M:build_shadow_map(scene)
  local old_shader = lg.getShader()
  local old_canvas = lg.getCanvas()

  local shadow_shader = self.shadow_shader
  local render_shader = self.render_shader

	lg.setShader(shadow_shader)
	lg.setCanvas({ depthstencil = self.shadow_depth_map })
  lg.clear(0, 0, 0, 0)

  local tw, th = love.graphics.getDimensions()
  local lhw, lhh = tw * 2 / self.view_scale, th * 2 / self.view_scale
  local dist = (Vec3(unpack(self.light_pos)) - Vec3(unpack(self.look_at))):len()
  local projection = Mat4.from_ortho(-lhw, lhw, lhh, -lhh, -dist, dist * 1.5)
  local view = Mat4()
  view = view:look_at(view, Vec3(unpack(self.light_pos)), Vec3(unpack(self.look_at)), Vec3(0, 1, 0))

	shadow_shader:send("projection_mat", 'column', projection)
	shadow_shader:send("view_mat", 'column', view)
  render_shader:send('light_projection_mat', 'column', projection)
  render_shader:send('light_view_mat', 'column', view)

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

	lg.setShader(old_shader)
	lg.setCanvas(old_canvas)
end

function M:render_scene(scene)
  local old_shader = lg.getShader()
  local render_shader = self.render_shader

	lg.setShader(render_shader)
	render_shader:send("projection_mat", 'column', self.projection)
	render_shader:send("view_mat", 'column', self.view)
	render_shader:send("light_pos", self.light_pos)
	render_shader:send("light_color", self.light_color)
	render_shader:send("ambient_color", self.ambient_color)
	render_shader:send("camera_pos", self.camera_pos)

	render_shader:send("shadow_depth_map", self.shadow_depth_map)

  for i, model in ipairs(scene.model) do
    self:render_model(model)
  end

	lg.setShader(old_shader)
end

function M:render_model(model)
  local model_opts = model.options
  -- local render_shader = self.render_shader

	lg.setDepthMode("less", model_opts.write_depth)
	lg.setMeshCullMode(model_opts.face_culling)

	-- render_shader:send("model_roughness", model_opts.roughness)
  -- render_shader:send("model_metallic", model_opts.metallic)
  -- render_shader:send("model_albedo", model_opts.albedo)

  lg.drawInstanced(model.mesh, model.total_instances)

	lg.setMeshCullMode('none')
  lg.setDepthMode()
end

------------------

function private.attach_transforms(model_mesh, model_transforms)
  local tfs_mesh = lg.newMesh(transform_mesh_format, model_transforms, nil, 'static')
  model_mesh:attachAttribute('ModelPos', tfs_mesh, 'perinstance')
  model_mesh:attachAttribute('ModelAngle', tfs_mesh, 'perinstance')
  model_mesh:attachAttribute('ModelScale', tfs_mesh, 'perinstance')
  model_mesh:attachAttribute('ModelColor', tfs_mesh, 'perinstance')
end

function private.new_depth_map(w, h, mode)
  local canvas = lg.newCanvas(w, h, { type = '2d', format = 'depth24', readable = true })
  canvas:setDepthSampleMode(mode)
  return canvas
end


return M
