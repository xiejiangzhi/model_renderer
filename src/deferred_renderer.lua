local private = {}

local code_dir = (...):gsub('.[^%.]+$', '')
local file_dir = code_dir:gsub('%.', '/')
local Cpml = require 'cpml'
local Mat4 = Cpml.mat4

local M = require(code_dir..'.base_renderer'):extend()

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

function M:init()
  local options = self.options
  if options.render_shadow == nil then options.render_shadow = true end

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
  self.forward_render_shader = Util.new_shader(
    file_dir..'/shader/forward.glsl', file_dir..'/shader/vertex.glsl',
    options.pixel_code, options.vertex_code, options.macros
  )
  Util.send_uniforms(self.forward_render_shader, {
    { 'render_shadow',  false },
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
  self.tmp_output_canvas = lg.newCanvas(w, h)

  self.screen_mesh = Util.new_screen_mesh()

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

function M:render(scene, time, draw_to_screen)
  if not scene.sun_dir then scene.sun_dir = { 1, 1, 1 } end
  if not scene.sun_color then scene.sun_color = { 0.5, 0.5, 0.5 } end
  if not scene.ambient_color then scene.ambient_color = { 0.1, 0.1, 0.1 } end

  self.time = time or love.timer.getTime()

  if self.options.render_shadow then
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
    self:forward_render(scene)

    lg.setBlendMode('alpha')
    self.depth_map:setDepthSampleMode()
    lg.draw(self.depth_map, 0, 0, 0, hw / self.depth_map:getWidth(), hh / self.depth_map:getHeight())
    self.depth_map:setDepthSampleMode('less')
    lg.setBlendMode('replace')
    lg.draw(self.np_map, hw, 0, 0, sx, sy)
    lg.draw(self.albedo_map, hw * 2, 0, 0, sx, sy)
    lg.setBlendMode('alpha')
    self.shadow_depth_map:setDepthSampleMode()
    lg.draw(self.shadow_depth_map, 10, hh + 10, 0, sx, sy)
    self.shadow_depth_map:setDepthSampleMode('less')

    self:post_pass(hw, hh, 0, sx * 2, sy * 2)
  else
    self:deferred_render(scene)
    self:forward_render(scene)
    self:post_pass()
  end

  if draw_to_screen or draw_to_screen == nil then
    self:draw_to_screen()
  end

  return self.output_canvas
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
  local output = self.tmp_output_canvas
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
    { "cameraClipDist", { self.camera.near, self.camera.far } },
  })

  Util.send_lights_uniforms(render_shader, scene.lights)

  if not self.options.render_shadow then
    render_shader:send("ShadowDepthMap", self.default_shadow_depth_map)
  end

  if self.skybox then
    Util.send_uniforms(render_shader, {
      { "skybox", self.skybox },
      { "skybox_max_mipmap_lod", self.skybox:getMipmapCount() - 1 },
      { "useSkybox", true }
    })
  else
    render_shader:send("useSkybox", false)
  end

  lg.setBlendMode('alpha', 'premultiplied')

  lg.draw(self.screen_mesh, 0, 0, 0, output:getDimensions())

  self.depth_map:setDepthSampleMode('less')
  lg.setCanvas({ output, depthstencil = self.depth_map })
	lg.setDepthMode("less", false)
  if self.skybox then
    self:render_skybox(skybox_model, self.skybox, self.skybox_shader)
  end
	lg.setDepthMode()

  lg.setBlendMode('alpha')
  Util.pop_render_env()
end

function M:forward_render(scene)
  local od_model = scene.ordered_model
  if not od_model or #od_model == 0 then return end

  local output = self.tmp_output_canvas

  local render_shader = self.forward_render_shader
  Util.push_render_env({ output, depthstencil = self.depth_map }, render_shader)

	lg.setDepthMode("less", true)

  self.depth_map:setDepthSampleMode()
  Util.send_uniforms(render_shader, {
	  { "projViewMat", 'column', self.proj_view_mat },
    { 'sunDir', scene.sun_dir },
    { 'sunColor', scene.sun_color },
	  { "ambientColor", scene.ambient_color },
	  { "cameraPos", self.camera_pos },
	  { "Time", self.time },

	  { "DepthMap", self.depth_map },
	  { "cameraClipDist", { self.camera.near, self.camera.far } },
  })
  self.depth_map:setDepthSampleMode('less')

  if self.skybox then
    Util.send_uniforms(render_shader, {
      { "skybox", self.skybox },
      { "skybox_max_mipmap_lod", self.skybox:getMipmapCount() - 1 },
      { "useSkybox", true }
    })
  else
    render_shader:send("useSkybox", false)
  end

  Util.send_lights_uniforms(render_shader, scene.lights)

  for i, model in ipairs(od_model) do
    self:render_model(model, render_shader)
  end

  lg.setDepthMode()

  Util.pop_render_env()
end

function M:post_pass(x, y, rotate, sx, sy)
  local tex_w, tex_h = self.output_canvas:getDimensions()

  lg.setBlendMode('alpha', 'premultiplied')
  Util.push_render_env(self.output_canvas)
  lg.clear(0, 0, 0, 0)
  if self.fxaa then
    private.attach_shader(self.fxaa_shader, {
      { 'Resolution', { tex_w, tex_h } },
    })
    lg.draw(self.tmp_output_canvas, x, y, rotate, sx, sy)
    lg.setShader()
  else
    lg.draw(self.tmp_output_canvas, x, y, rotate, sx, sy)
  end
  Util.pop_render_env()
  lg.setBlendMode('alpha')
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
