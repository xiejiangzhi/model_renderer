local M = {}
M.__index = M
local private = {}

local code_dir = (...):gsub('.[^%.]+$', '')
local file_dir = code_dir:gsub('%.', '/')
local Cpml = require 'cpml'
local Mat4 = Cpml.mat4
local Vec3 = Cpml.vec3

local Model = require(code_dir..'.model')

local lg = love.graphics

local default_opts = {
  ambient_color = { 0.03, 0.03, 0.03 },

  light_pos = { 1000, 2000, 1000 },
  light_color = { 3000, 3000, 3000 },

  -- for shadow
  sun_dir = { 1, 1, 1 },
  sun_color = { 1, 1, 1 },
}

local render_modes = { pbr = true, phong = true, pure3d = true }

local skybox_model

function M.new()
  local obj = setmetatable({}, M)
  obj:init()
  return obj
end

-- render_mode: pbr is valid, others are currently only used for testing
function M:init(render_mode)
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
  self.default_shadow_depth_map = private.new_depth_map(1, 1, 'less')

  self:set_render_mode(render_mode)
  self.shadow_shader = lg.newShader(file_dir..'/shader/shadow.glsl')
  self.skybox_shader = lg.newShader(file_dir..'/shader/skybox.glsl')

  self.skybox = nil
  if not skybox_model then
    skybox_model = Model.new_skybox()
  end
end

function M:apply_camera(camera)
  self.projection = camera.projection
  self.view = camera.view
  self.camera_pos = { camera.pos:unpack() }
  self.look_at = { camera.focus:unpack() }

  local w, h = love.graphics.getDimensions()
  local viewport = { 0, 0, w, h }
  local p = camera:unproject(w / 2, h, viewport)
  if p then
    self.shadow_start_at = { p:unpack() }
  else
    self.shadow_start_at = { unpack(self.camera_pos) }
  end
end

-- {
--  model = { m1, m2, m3 }
-- }
function M:render(scene)
  if self.render_shadow and self.render_mode ~= 'pure3d' then self:build_shadow_map(scene) end
  self:render_scene(scene)

  -- local c = self.shadow_depth_map
  -- c:setDepthSampleMode()
  -- lg.draw(c, 0, 0, 0, 0.5, 0.5)
  -- c:setDepthSampleMode('less')
end

function M:set_render_mode(mode)
  local glsl_path
  if mode == nil then
    mode = 'pbr'
    glsl_path = 'pbr.glsl'
  elseif render_modes[mode] then
    glsl_path = mode..'.glsl'
  else
    error("Invalid render mode "..mode)
  end
  self.render_shader = lg.newShader(file_dir..'/shader/'..glsl_path, file_dir..'/shader/vertex.glsl')
  self.render_mode = mode
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

  local angle = math.atan2(self.look_at[3] - self.camera_pos[3], self.look_at[1] - self.camera_pos[1])
  local ox, oy = math.cos(angle) * lhh, math.sin(angle) * lhh
  local shadow_look_at = Vec3(self.shadow_start_at) + Vec3(ox, 0, oy)
  local dist = (Vec3(self.camera_pos) - Vec3(self.look_at)):len() * 2
  local offset = Vec3(self.sun_dir) * dist

  local projection = Mat4.from_ortho(-lhw, lhw, lhh, -lhh, -100, dist * 2.5)
  local view = Mat4()
  view = view:look_at(view, shadow_look_at + offset, shadow_look_at, Vec3(0, 1, 0))

  local light_proj_view = Mat4.new()
  light_proj_view:mul(projection, view)

	shadow_shader:send("projection_view_mat", 'column', light_proj_view)
  render_shader:send('light_proj_view_mat', 'column', light_proj_view)

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
  local pv_mat = Mat4.new()
  pv_mat:mul(self.projection, self.view)
	render_shader:send("projection_view_mat", 'column', pv_mat)

	render_shader:send("light_pos", self.light_pos)
	render_shader:send("light_color", self.light_color)
  render_shader:send('sun_dir', self.sun_dir)
  render_shader:send('sun_color', self.sun_color)
	render_shader:send("ambient_color", self.ambient_color)
	render_shader:send("camera_pos", self.camera_pos)

  if render_shader:hasUniform('shadow_depth_map') then
    if self.render_shadow then
      render_shader:send("shadow_depth_map", self.shadow_depth_map)
    else
      render_shader:send("shadow_depth_map", self.default_shadow_depth_map)
    end
  end

  -- if self.skybox then
  --   render_shader:send("skybox", self.skybox)
  -- end

  for i, model in ipairs(scene.model) do
    self:render_model(model)
  end

  if self.skybox then
    self:render_skybox(skybox_model)
  end

	lg.setShader(old_shader)
end

function M:render_model(model)
  local model_opts = model.options

	lg.setDepthMode("less", model_opts.write_depth)
	lg.setMeshCullMode(model_opts.face_culling)

  lg.drawInstanced(model.mesh, model.total_instances)

	lg.setMeshCullMode('none')
  lg.setDepthMode()
end

function M:render_skybox(model)
  local skybox_shader = self.skybox_shader
  lg.setShader(skybox_shader)

  -- remove camera move transform
  local view = self.view:clone()
  view[13], view[14], view[15], view[16] = 0, 0, 0, 1
  local pv_mat = Mat4.new()
  pv_mat:mul(self.projection, view)

  skybox_shader:send("projection_view_mat", 'column', pv_mat)
  skybox_shader:send("skybox", self.skybox)

	lg.setDepthMode("lequal", true)
  lg.draw(model.mesh)
  lg.setDepthMode()
end

------------------

function private.new_depth_map(w, h, mode)
  local canvas = lg.newCanvas(w, h, { type = '2d', format = 'depth32f', readable = true })
  canvas:setDepthSampleMode(mode)
  return canvas
end


return M
