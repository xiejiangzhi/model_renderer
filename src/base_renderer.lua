local M = {}
M.__index = M

local code_dir = (...):gsub('.[^%.]+$', '')
-- local file_dir = code_dir:gsub('%.', '/')

local Cpml = require 'cpml'
local Mat4 = Cpml.mat4

local Util = require(code_dir..'.util')

local lg = love.graphics

function M:extend()
  local cls = {}
  for k, v in pairs(self) do
    if type(v) == 'function' then
      cls[k] = v
    end
  end

  cls.init = nil
  cls.__index = cls
  cls.new = function(...)
    local obj = setmetatable({}, cls)
    M.init(obj)
    obj:init(...)
    return obj
  end

  return cls
end

function M:init()
  self.camera = nil
  self.projection = nil
  self.view = nil
  self.camera_pos = nil
  self.look_at = nil
  self.camera_space_vertices = nil

  self.depth_map = nil
  self.output_canvas = nil
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

-- scene:
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
-- draw_to_screen: default is true
-- function M:render(scene, time, draw_to_screen)
-- end

function M:draw_to_screen()
  lg.setBlendMode('alpha', 'premultiplied')
  lg.draw(self.output_canvas)
  lg.setBlendMode('alpha')
end

function M:attach(...)
  self.old_canvas = lg.getCanvas()
  lg.setCanvas({ self.output_canvas, depthstencil = self.depth_map })
  self.camera:attach(...)
end

function M:detach()
  lg.setCanvas(self.old_canvas)
  self.old_canvas = nil
  self.camera:detach()
end

----------------------------

function M:render_skybox(model, skybox_tex, skybox_shader)
  local old_shader = lg.getShader()
  lg.setShader(skybox_shader)

  -- remove camera move transform
  local view = self.view:clone()
  view[13], view[14], view[15], view[16] = 0, 0, 0, 1
  local pv_mat = Mat4.new()
  pv_mat:mul(self.projection, view)

  Util.send_uniforms(skybox_shader, {
    { "projViewMat", 'column', pv_mat },
    { "skybox", skybox_tex },
  })

	lg.setDepthMode("lequal", true)
  lg.draw(model.mesh)
  lg.setDepthMode()

  lg.setShader(old_shader)
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

return M
