local code_dir = (...):gsub('.[^%.]+$', '')
local file_dir = code_dir:gsub('%.', '/')

local M = require(code_dir..'.base_renderer'):extend()

local Cpml = require 'cpml'
local Mat4 = Cpml.mat4

local Model = require(code_dir..'.model')
local Util = require(code_dir..'.util')
local ShadowBuilder = require(code_dir..'.shadow_builder')
local send_uniform = Util.send_uniform

local lg = love.graphics

local skybox_model

local brdf_lut_size = 512
local brdf_lut

local default_options = {
  vertex_code = false,
  pixel_code = false,
  macros = false,
  msaa = 4,
}

function M:init(options)
  self.options = Util.merge_options(default_options, options or {})
  local opts = self.options

  self.shadow_builder = ShadowBuilder.new(2048, 2048)

  self.shadow_shader = lg.newShader(file_dir..'/shader/shadow.glsl')
  self.skybox_shader = lg.newShader(file_dir..'/shader/skybox.glsl')
  Util.send_uniforms(self.skybox_shader, {
    { 'y_flip', -1 }
  })

  self.skybox = nil
  if not skybox_model then
    skybox_model = Model.new_skybox()
    brdf_lut = Util.generate_brdf_lut(brdf_lut_size)
  end

  self.render_shader = Util.new_shader(
    file_dir..'/shader/forward.glsl',
    file_dir..'/shader/vertex.glsl',
    opts.pixel_code, opts.vertex_code, opts.macros
  )
  Util.send_uniforms(self.render_shader, {
    { 'brdfLUT', brdf_lut },
    { 'y_flip', -1 }
  })

  local w, h = lg.getDimensions()
  self.output_canvas = lg.newCanvas(w, h, { msaa = opts.msaa })

  self.depth_shader = Util.new_shader(
    file_dir..'/shader/depth.glsl', file_dir..'/shader/vertex.glsl',
    nil, opts.vertex_code, opts.macros
  )
  Util.send_uniforms(self.depth_shader, {
    { 'y_flip', -1 },
    { 'lightProjViewMat', 'column', Mat4.new() }
  })
  self.depth_map = Util.new_depth_map(w, h, 'less')
end

function M:render(scene, time, draw_to_screen)
  if not scene.sun_dir then scene.sun_dir = { 1, 1, 1 } end
  if not scene.sun_color then scene.sun_color = { 0.5, 0.5, 0.5 } end
  if not scene.ambient_color then scene.ambient_color = { 0.1, 0.1, 0.1 } end

  self.time = time or love.timer.getTime()

  self:build_shadow_map(scene)

  self:render_depth(scene)
  -- lg.setWireframe(true)
  self:render_scene(scene)
  -- lg.setWireframe(false)

  if draw_to_screen or draw_to_screen == nil then
    self:draw_to_screen()
  end

  return self.output_canvas
end

function M:attach(...)
  self.old_canvas = lg.getCanvas()
  lg.setCanvas({ self.output_canvas, depth = true })
  self.camera:attach(...)
end

----------------------------------

function M:build_shadow_map(scene)
  local shadow_depth_map, sun_proj_view = self.shadow_builder:build(
    scene, self.camera_space_vertices, scene.sun_dir
  )
  send_uniform(self.render_shader, 'lightProjViewMat', 'column', sun_proj_view)
  send_uniform(self.render_shader, "ShadowDepthMap", shadow_depth_map)
end

function M:render_depth(scene)
  local render_shader = self.depth_shader

  Util.push_render_env({ depthstencil = self.depth_map }, render_shader)
  lg.clear(0, 0, 0, 0)

  Util.send_uniforms(render_shader, {
    { "projViewMat", 'column', self.proj_view_mat },
    { "Time", self.time },
  })

  Util.send_lights_uniforms(render_shader, scene.lights)

  for i, model in ipairs(scene.model) do
    self:render_model(model, render_shader)
  end

  if scene.ordered_model then
    for i, model in ipairs(scene.ordered_model) do
      self:render_model(model, render_shader)
    end
  end

  Util.pop_render_env()
end

function M:render_scene(scene)
  local render_shader = self.render_shader

  Util.push_render_env({ self.output_canvas, depth = true }, self.render_shader)
  lg.clear(0, 0, 0, 0)

  Util.send_uniforms(render_shader, {
    { 'render_shadow', true },
	  { "projViewMat", 'column', self.proj_view_mat },
    { 'sunDir', scene.sun_dir },
    { 'sunColor', scene.sun_color },
	  { "ambientColor", scene.ambient_color },
	  { "cameraPos", self.camera_pos },
	  { "Time", self.time },

	  { "cameraClipDist", { self.camera.near, self.camera.far } },
  })

  Util.send_lights_uniforms(render_shader, scene.lights)

  if self.skybox then
    Util.send_uniforms(render_shader, {
      { "skybox", self.skybox },
      { "skybox_max_mipmap_lod", self.skybox:getMipmapCount() - 1 },
      { "useSkybox", true }
    })
  else
    send_uniform(render_shader, "useSkybox", false)
  end

  for i, model in ipairs(scene.model) do
    self:render_model(model, render_shader)
  end

  if self.skybox then
    self:render_skybox(skybox_model, self.skybox, self.skybox_shader)
  end

  self.depth_map:setDepthSampleMode()
  Util.send_uniforms(render_shader, {
    { 'render_shadow', false },
	  { "DepthMap", self.depth_map },
  })
  if scene.ordered_model then
    for i, model in ipairs(scene.ordered_model) do
      self:render_model(model, render_shader)
    end
  end
  self.depth_map:setDepthSampleMode('less')

  Util.pop_render_env()
end

return M
