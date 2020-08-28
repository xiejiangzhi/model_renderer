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

local skybox_model

local brdf_lut_size = 512
local brdf_lut

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
  local sr = self.shadow_resolution
  self.shadow_depth_map = private.new_depth_map(sr[1], sr[2], 'less')
  self.default_shadow_depth_map = private.new_depth_map(1, 1, 'less')

  self.shadow_shader = lg.newShader(file_dir..'/shader/shadow.glsl')
  self.skybox_shader = lg.newShader(file_dir..'/shader/skybox.glsl')

  self.skybox = nil
  if not skybox_model then
    skybox_model = Model.new_skybox()
    brdf_lut = private.generate_brdf_lut(brdf_lut_size)
  end

  self.gbuffer_shader = lg.newShader(file_dir..'/shader/gbuffer.glsl', file_dir..'/shader/vertex.glsl')
  self.deferred_shader = lg.newShader(file_dir..'/shader/deferred.glsl')
  self.deferred_shader:send('brdf_lut', brdf_lut)

  local w, h = love.graphics.getDimensions()
  -- self.pos_map = private.new_gbuffer(w, h, 'rgba16f')
  self.normal_map = private.new_gbuffer(w, h, 'rg8')
  self.albedo_map = private.new_gbuffer(w, h, 'rgba8')
  -- misc: roughness, metallic, shadow
  self.misc_map = private.new_gbuffer(w, h, 'rgba8')
  self.depth_map = private.new_depth_map(w, h, 'less')

  self.screen_mesh = lg.newMesh({
    { 0, 0, 0, 0 },
    { 1, 0, 1, 0 },
    { 1, 1, 1, 1 },
    { 0, 1, 0, 1 },
  }, 'fan')
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
  if self.render_shadow then
    self.gbuffer_shader:send('render_shadow', true)
    self:build_shadow_map(scene)
  else
    self.gbuffer_shader:send('render_shadow', false)
  end

  self:render_gbuffer(scene)

  if self.debug then
    local w, h = lg.getDimensions()
    local hw , hh = w / 3, h / 3
    local sx, sy = hw / w, hh / h

    if not self.output_canvas then
      self.output_canvas = lg.newCanvas(w, h)
    end
    self:final_render(self.output_canvas)

    lg.setBlendMode('alpha', 'premultiplied')
    -- lg.draw(self.pos_map, 0, 0, 0, sx, sy)
    lg.draw(self.normal_map, hw, 0, 0, sx, sy)
    lg.draw(self.albedo_map, hw * 2, 0, 0, sx, sy)
    lg.draw(self.misc_map, 0, hh, 0, sx, sy)
    lg.draw(self.output_canvas, hw, hh, 0, sx * 2, sy * 2)
    lg.setBlendMode('alpha', 'alphamultiply')
  else
    self:final_render()
  end
end

function M:build_shadow_map(scene)
  local old_shader = lg.getShader()
  local old_canvas = lg.getCanvas()

  local shadow_shader = self.shadow_shader

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
  self.gbuffer_shader:send('light_proj_view_mat', 'column', light_proj_view)

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

function M:render_gbuffer(scene)
  local old_shader = lg.getShader()
  local old_canvas = lg.getCanvas()

  local gbuffer_shader = self.gbuffer_shader

	lg.setShader(gbuffer_shader)
  lg.setCanvas({
    -- self.pos_map, self.normal_map, self.albedo_map, self.misc_map,
    self.normal_map, self.albedo_map, self.misc_map,
    depthstencil = self.depth_map
  })
  lg.clear(0, 0, 0, 0)

  local pv_mat = Mat4.new()
  pv_mat:mul(self.projection, self.view)
	gbuffer_shader:send("projection_view_mat", 'column', pv_mat)
  -- gbuffer_shader:send('CameraPos', self.camera_pos)
  gbuffer_shader:send('y_flip', -1)

  if self.render_shadow then
    gbuffer_shader:send("shadow_depth_map", self.shadow_depth_map)
  else
    gbuffer_shader:send("shadow_depth_map", self.default_shadow_depth_map)
  end

  for i, model in ipairs(scene.model) do
    self:render_model(model)
  end

	lg.setShader(old_shader)
	lg.setCanvas(old_canvas)
end

-- output: canvas or nil, nil will render to screen
function M:final_render(output)
  local old_shader = lg.getShader()
  local old_canvas = lg.getCanvas()

  local render_shader = self.deferred_shader

  -- render_shader:send('PosMap', self.pos_map)
  render_shader:send('NormalMap', self.normal_map)
  render_shader:send('AlbedoMap', self.albedo_map)
  render_shader:send('MiscMap', self.misc_map)

  self.depth_map:setDepthSampleMode()
  render_shader:send('DepthMap', self.depth_map)
  self.depth_map:setDepthSampleMode('less')

	render_shader:send("light_pos", self.light_pos)
	render_shader:send("light_color", self.light_color)
  render_shader:send('sun_dir', self.sun_dir)
  render_shader:send('sun_color', self.sun_color)
	render_shader:send("ambient_color", self.ambient_color)
	render_shader:send("camera_pos", self.camera_pos)

  local inverted_proj = Mat4.new():invert(self.projection)
	render_shader:send("invertedProjMat", 'column', inverted_proj)
  local inverted_view = Mat4.new():invert(self.view)
	render_shader:send("invertedViewMat", 'column', inverted_view)


  if self.skybox then
    render_shader:send("skybox", self.skybox)
    render_shader:send("skybox_max_mipmap_lod", self.skybox:getMipmapCount() - 1)
    render_shader:send("use_skybox", true)
  else
    render_shader:send("use_skybox", false)
  end

  lg.setCanvas(output)

  if self.skybox then
    self:render_skybox(skybox_model)
  end

	lg.setShader(render_shader)

  lg.draw(self.screen_mesh, 0, 0, 0, lg.getDimensions())

	lg.setShader(old_shader)
	lg.setCanvas(old_canvas)
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
  local canvas = lg.newCanvas(w, h, { type = '2d', format = 'depth24', readable = true })
  canvas:setDepthSampleMode(mode)
  return canvas
end

function private.generate_brdf_lut(size)
  local shader = lg.newShader(file_dir..'/shader/brdf_lut.glsl')
  local old_shader = lg.getShader()
  local old_canvas = lg.getCanvas()
  local canvas = lg.newCanvas(size, size, { type = '2d', format = 'rg16f' })

  lg.setShader(shader)
  lg.setCanvas(canvas)

  local mesh = lg.newMesh({
    { 0, 0, 0, 1 }, { size, 0, 1, 1 }, { size, size, 1, 0 }, { 0, size, 0, 0 }
  }, 'fan', 'static')
  lg.draw(mesh)

  canvas:setWrap('clamp', 'clamp')

  lg.setCanvas(old_canvas)
  lg.setShader(old_shader)

  return canvas
end

function private.new_gbuffer(w, h, format)
  local canvas = lg.newCanvas(w, h, { type = '2d', format = format })
  canvas:setFilter('nearest', 'nearest')
  return canvas
end

return M