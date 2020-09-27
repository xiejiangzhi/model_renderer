local M = {}
M.__index = M

local code_dir = (...):gsub('.[^%.]+$', '')
local file_dir = code_dir:gsub('%.', '/')
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

function M.new(...)
  local obj = setmetatable({}, M)
  obj:init(...)
  return obj
end

-- options:
--  vertex_code:
--  pixel_code:
--  macros
function M:init(options)
  if not options then options = {} end
  self.options = options

  self.projection = nil
  self.view = nil
  self.view_scale = 1
  self.camera_pos = nil
  self.look_at = { 0, 0, 0 }
  self.render_shadow = true

  self.shadow_builder = ShadowBuilder.new(2048, 2048)
  self.default_shadow_depth_map = Util.new_depth_map(1, 1, 'less')

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
    options.pixel_code, options.vertex_code, options.macros
  )
  Util.send_uniforms(self.render_shader, {
    { 'brdfLUT', brdf_lut },
    { 'y_flip', -1 }
  })

  local w, h = lg.getDimensions()
  self.output_canvas = lg.newCanvas(w, h, { msaa = 4 })
  -- self.depth_map = Util.new_depth_map(w, h, 'less', 'depth32f', { msaa = 4, readable = false })
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

-- {
--    model = { m1, m2, m3 },
--    lights = {
--      pos = { { x, y, z }, light2_pos, ... },
--      color = { { r, g, b }, light2_color, ... },
--      linear = { 0, light2_linear, ... },
--      quadratic = { 1, light2_quadratic, ... },
--    },
--    sun_dir = { x, y, z },
--    sun_color = { r, g, b },
--    ambient_color = { r, g, b },
-- }
function M:render(scene, time)
  if not scene.sun_dir then scene.sun_dir = { 1, 1, 1 } end
  if not scene.sun_color then scene.sun_color = { 0.5, 0.5, 0.5 } end
  if not scene.ambient_color then scene.ambient_color = { 0.1, 0.1, 0.1 } end

  self.time = time or love.timer.getTime()

  if self.render_shadow then
    self:build_shadow_map(scene)
    send_uniform(self.render_shader, 'render_shadow', true)
  else
    send_uniform(self.render_shader, 'render_shadow', false)
  end

  self:render_scene(scene)
  self:render_to_screen()
end

----------------------------------

function M:build_shadow_map(scene)
  local shadow_depth_map, sun_proj_view = self.shadow_builder:build(
    scene, self.camera_space_vertices, scene.sun_dir
  )
  send_uniform(self.render_shader, 'lightProjViewMat', 'column', sun_proj_view)
  send_uniform(self.render_shader, "ShadowDepthMap", shadow_depth_map)
end

function M:render_scene(scene)
  local render_shader = self.render_shader

  Util.push_render_env({ self.output_canvas, depth = true }, self.render_shader)
  lg.clear(0, 0, 0, 0)

  local pv_mat = Mat4.new()
  pv_mat:mul(self.projection, self.view)
  Util.send_uniforms(render_shader, {
	  { "projViewMat", 'column', pv_mat },
    { 'sunDir', scene.sun_dir },
    { 'sunColor', scene.sun_color },
	  { "ambientColor", scene.ambient_color },
	  { "cameraPos", self.camera_pos },
	  { "Time", self.time },
  })

  Util.send_lights_uniforms(render_shader, scene.lights)

  if not self.render_shadow then
    send_uniform(render_shader, "ShadowDepthMap", self.default_shadow_depth_map)
  end

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
    self:render_model(model)
  end

  if self.skybox then
    self:render_skybox(skybox_model)
  end

  Util.send_uniforms(render_shader, {
    { 'render_shadow', false },
  })
  if scene.transparent_model then
    for i, model in ipairs(scene.transparent_model) do
      self:render_model(model)
    end
  end

  Util.pop_render_env()
end

function M:render_model(model)
  local model_opts = model.options

	lg.setDepthMode("less", model_opts.write_depth)
	lg.setMeshCullMode(model_opts.face_culling)

  if model_opts.ext_pass_id and model_opts.ext_pass_id ~= 0 then
    local render_shader = self.render_shader
    send_uniform(render_shader, 'extPassId', model_opts.ext_pass_id)
    lg.drawInstanced(model.mesh, model.total_instances)
    send_uniform(render_shader, 'extPassId', 0)
  else
    lg.drawInstanced(model.mesh, model.total_instances)
  end

	lg.setMeshCullMode('none')
  lg.setDepthMode()
end

function M:render_skybox(model)
  local skybox_shader = self.skybox_shader
  local old_shader = lg.getShader()
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

  lg.setShader(old_shader)
end

function M:render_to_screen()
  lg.setBlendMode('alpha', 'premultiplied')
  lg.draw(self.output_canvas)
  lg.setBlendMode('alpha')
end

return M
