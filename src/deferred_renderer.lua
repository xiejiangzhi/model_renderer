local M = {}
M.__index = M
local private = {}

local code_dir = (...):gsub('.[^%.]+$', '')
local file_dir = code_dir:gsub('%.', '/')
local Cpml = require 'cpml'
local Mat4 = Cpml.mat4

local Model = require(code_dir..'.model')
local Util = require(code_dir..'.util')
local ShadowBuilder = require(code_dir..'.shadow_builder')

local lg = love.graphics

local skybox_model

local BrdfLUT_size = 512
local BrdfLUT

local SSAOConf = {
  radius = { uniform = 'SSAORadius' },
  intensity = { uniform = 'SSAOIntensity' },
  samples_count = { uniform = 'SSAOSamplesCount' },
  pow = { uniform = 'SSAOPow' },
}

function M.new(...)
  local obj = setmetatable({}, M)
  obj:init(...)
  return obj
end

function M:init(options)
  if not options then options = {} end
  self.options = options

  self.projection = nil
  self.view = nil
  self.view_scale = 1
  self.camera_pos = nil
  self.look_at = { 0, 0, 0 }
  self.render_shadow = true
  self.fxaa = true
  self.ssao = {
    radius = 64,
    intensity = 10,
    samples_count = 16,
    pow = 0.5
  }

  -- self.shadow_builder = ShadowBuilder.new(1024, 1024)
  self.shadow_builder = ShadowBuilder.new(2048, 2048)
  self.default_shadow_depth_map = Util.new_depth_map(1, 1, 'less')

  self.skybox_shader = lg.newShader(file_dir..'/shader/skybox.glsl')

  self.skybox = nil
  if not skybox_model then
    skybox_model = Model.new_skybox()
    BrdfLUT = Util.generate_brdf_lut(BrdfLUT_size)
  end

  self.gbuffer_shader = Util.new_shader(
    file_dir..'/shader/gbuffer.glsl', file_dir..'/shader/vertex.glsl',
    nil, options.vertex_code, options.macros
  )
  self.deferred_shader = Util.new_shader(
    file_dir..'/shader/deferred.glsl', nil,
    options.pixel_code, nil, options.macrox
  )
  self.fxaa_shader = Util.new_shader(file_dir..'/shader/fxaa_filter.glsl')
  self.screen_depth_shader = Util.new_shader(file_dir..'/shader/screen_depth.glsl')
  self.transparent_render_shader = Util.new_shader(
    file_dir..'/shader/forward.glsl', file_dir..'/shader/vertex.glsl',
    options.pixel_code, options.vertex_code, options.macros
  )
  Util.send_uniforms(self.transparent_render_shader, {
    { 'render_shadow',  false },
    { 'use_skybox', false },
    { 'brdfLUT', BrdfLUT },
    { 'y_flip', -1 },
  })

  local w, h = lg.getDimensions()
  -- normal, roughness, metallic
  self.np_map = private.new_gbuffer(w, h, 'rgba8')
  self.albedo_map = private.new_gbuffer(w, h, 'rgba8')
  self.depth_map = Util.new_depth_map(w, h, 'less')

  self.write_screen_depth = false

  self.screen_tmp_map = self.albedo_map
  self.output_canvas = lg.newCanvas(w, h)

  self.screen_mesh = lg.newMesh({
    { 0, 0, 0, 0 },
    { 1, 0, 1, 0 },
    { 1, 1, 1, 1 },
    { 0, 1, 0, 1 },
  }, 'fan')

  Util.send_uniforms(self.skybox_shader, {
    { 'y_flip', -1 }
  })
  Util.send_uniforms(self.gbuffer_shader, {
    { 'y_flip', -1 }
  })
  Util.send_uniforms(self.deferred_shader, {
    { 'brdfLUT', BrdfLUT }
  })
  self:set_ssao(self.ssao)
end

function M:set_ssao(opts)
  for k, v in pairs(opts) do
    local desc = SSAOConf[k]
    if desc then
      Util.send_uniform(self.deferred_shader, desc.uniform, v)
    else
      print("Invalid SSAO conf '"..k.."'")
    end
  end
end

function M:apply_camera(camera)
  self.camera = camera
  self.projection = camera.projection
  self.view = camera.view
  self.camera_pos = { camera.pos:unpack() }
  self.look_at = { camera.focus:unpack() }
  self.camera_space_vertices = camera:get_space_vertices()

  local pv_mat = Mat4.new()
  pv_mat:mul(self.projection, self.view)
  self.proj_view_mat = pv_mat
end

function M:render(scene, time)
  if not scene.sun_dir then scene.sun_dir = { 1, 1, 1 } end
  if not scene.sun_color then scene.sun_color = { 0.5, 0.5, 0.5 } end
  if not scene.ambient_color then scene.ambient_color = { 0.1, 0.1, 0.1 } end

  self.time = time or love.timer.getTime()

  if self.render_shadow then
    self.deferred_shader:send('render_shadow', true)
    self:build_shadow_map(scene)
  else
    self.deferred_shader:send('render_shadow', false)
  end

  self:render_gbuffer(scene)

  if self.debug then
    local w, h = lg.getDimensions()
    local hw , hh = w / 3, h / 3
    local sx, sy = hw / w, hh / h

    self:deferred_render(scene)
    self:render_transparent(scene)

    lg.setBlendMode('alpha')
    self.depth_map:setDepthSampleMode()
    lg.draw(self.depth_map, 0, 0, 0, sx, sy)
    self.depth_map:setDepthSampleMode('less')
    lg.setBlendMode('replace')
    lg.draw(self.np_map, hw, 0, 0, sx, sy)
    lg.draw(self.albedo_map, hw * 2, 0, 0, sx, sy)
    lg.setBlendMode('alpha')
    self.shadow_depth_map:setDepthSampleMode()
    lg.draw(self.shadow_depth_map, 10, hh + 10, 0, sx, sy)
    self.shadow_depth_map:setDepthSampleMode('less')

    self:render_to_screen(hw, hh, 0, sx * 2, sy * 2)
  else
    self:deferred_render(scene)
    self:render_transparent(scene)
    self:render_to_screen()
  end
end

function M:build_shadow_map(scene)
  local shadow_depth_map, sun_proj_view = self.shadow_builder:build(
    scene, self.camera_space_vertices, scene.sun_dir
  )

  self.shadow_depth_map = shadow_depth_map
  self.deferred_shader:send('sunProjViewMat', 'column', sun_proj_view)
  self.deferred_shader:send("ShadowDepthMap", self.shadow_depth_map)
end

function M:render_gbuffer(scene)
  local gbuffer_shader = self.gbuffer_shader

  Util.push_render_env({
    self.np_map, self.albedo_map,
    depthstencil = self.depth_map
  }, gbuffer_shader)
  lg.clear(0, 0, 0, 0)

  Util.send_uniforms(gbuffer_shader, {
    { "projViewMat", 'column', self.proj_view_mat },
    { "Time", self.time }
  })

  lg.setBlendMode('replace', 'premultiplied')
  for i, model in ipairs(scene.model) do
    self:render_model(model, gbuffer_shader)
  end
  lg.setBlendMode('alpha')

  Util.pop_render_env()
end

function M:deferred_render(scene)
  local output = self.output_canvas
  local render_shader = self.deferred_shader

  Util.push_render_env(output, render_shader)
  lg.clear(0, 0, 0, 0)

  self.depth_map:setDepthSampleMode()
  local inverted_proj = Mat4.new():invert(self.projection)
  local inverted_view = Mat4.new():invert(self.view)

  Util.send_uniforms(render_shader, {
    { 'NPMap', self.np_map },
    { 'AlbedoMap', self.albedo_map },
    { 'DepthMap', self.depth_map },

    { 'sunDir', scene.sun_dir },
    { 'sunColor', scene.sun_color },
	  { "ambientColor", scene.ambient_color },

	  { "cameraPos", self.camera_pos },
	  { "cameraNear", self.camera.near },
	  { "cameraFar", self.camera.far },

	  { "invertedProjMat", 'column', inverted_proj },
	  { "invertedViewMat", 'column', inverted_view },
	  { "projViewMat", 'column', self.proj_view_mat },
	  { "Time", self.time },
  })

  Util.send_lights_uniforms(render_shader, scene.lights)

  if not self.render_shadow then
    render_shader:send("ShadowDepthMap", self.default_shadow_depth_map)
  end

  if self.skybox then
    Util.send_uniforms(render_shader, {
      { "skybox", self.skybox },
      { "skybox_max_mipmap_lod", self.skybox:getMipmapCount() - 1 },
      { "use_skybox", true }
    })
  else
    render_shader:send("use_skybox", false)
  end

  lg.setBlendMode('alpha', 'premultiplied')

  lg.draw(self.screen_mesh, 0, 0, 0, output:getDimensions())

  self.depth_map:setDepthSampleMode('less')
  lg.setCanvas({ output, depthstencil = self.depth_map })
	lg.setDepthMode("less", false)
  if self.skybox then
    self:render_skybox(skybox_model)
  end
	lg.setDepthMode()

  lg.setBlendMode('alpha')
  Util.pop_render_env()
end

function M:render_transparent(scene)
  local tp_model = scene.transparent_model
  if not tp_model or #tp_model == 0 then return end

  local output = self.output_canvas

  local render_shader = self.transparent_render_shader
  Util.push_render_env({ output, depthstencil = self.depth_map }, render_shader)

	lg.setDepthMode("less", true)

  Util.send_uniforms(render_shader, {
	  { "projViewMat", 'column', self.proj_view_mat },
    { 'sunDir', scene.sun_dir },
    { 'sunColor', scene.sun_color },
	  { "ambientColor", scene.ambient_color },
	  { "cameraPos", self.camera_pos },
	  { "Time", self.time },
  })

  Util.send_lights_uniforms(render_shader, scene.lights)

  for i, model in ipairs(tp_model) do
    self:render_model(model, render_shader)
  end

  lg.setDepthMode()

  Util.pop_render_env()
end

function M:render_to_screen(x, y, rotate, sx, sy)
  local tex_w, tex_h = self.output_canvas:getDimensions()

  lg.setBlendMode('alpha', 'premultiplied')
  if self.fxaa then
    private.attach_shader(self.fxaa_shader, {
      { 'Resolution', { tex_w, tex_h } },
    })
    lg.draw(self.output_canvas, x, y, rotate, sx, sy)
    lg.setShader()
  else
    lg.draw(self.output_canvas, x, y, rotate, sx, sy)
  end
  lg.setBlendMode('alpha')

  if self.write_screen_depth then
    lg.setDepthMode('less', true)
    self.depth_map:setDepthSampleMode()
    private.attach_shader(self.screen_depth_shader, {
      { 'DepthMap', self.depth_map },
    })

    lg.draw(self.screen_mesh, 0, 0, 0, self.depth_map:getDimensions())

    lg.setShader()
    lg.setDepthMode()
    self.depth_map:setDepthSampleMode('less')
  end
end

function M:render_model(model, render_shader)
  local model_opts = model.options

	lg.setDepthMode("less", model_opts.write_depth)
	lg.setMeshCullMode(model_opts.face_culling)

  if model_opts.ext_pass_id and model_opts.ext_pass_id ~= 0 then
    Util.send_uniform(render_shader, 'extPassId', model_opts.ext_pass_id)
    lg.drawInstanced(model.mesh, model.total_instances)
    Util.send_uniform(render_shader, 'extPassId', 0)
  else
    lg.drawInstanced(model.mesh, model.total_instances)
  end

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

  Util.send_uniforms(skybox_shader, {
    { "projViewMat", 'column', pv_mat },
    { "skybox", self.skybox },
  })

	lg.setDepthMode("lequal", true)
  lg.draw(model.mesh)
  lg.setDepthMode()
end

------------------

function private.new_gbuffer(w, h, format)
  local canvas = lg.newCanvas(w, h, { type = '2d', format = format })
  canvas:setFilter('nearest', 'nearest')
  return canvas
end

function private.attach_shader(shader, uniforms)
  lg.setShader(shader)
  Util.send_uniforms(shader, uniforms)
end

return M
