local M = {}

local dir = (...):gsub('.[^%.]+$', ''):gsub('%.', '/')
local shader = love.graphics.newShader(dir..'/shader.glsl')

local lg = love.graphics

local transform_mesh_format = {
  { 'ModelPos', 'float', 3 },
  { 'ModelAngle', 'float', 3 },
  { 'ModelScale', 'float', 3 },
  { 'ModelColor', 'byte', 4 },
}

M.light_pos = { 1000, 2000, 1000 }

-- projection, view: mat4, 1-based, column major matrices
function M.draw(projection, view, model, model_transforms)
  local mesh = model.mesh
  M.attach_transforms(mesh, model_transforms)

  local old_shader = lg.getShader()
	lg.setShader(shader)
	shader:send("projection_mat", 'column', projection)
	shader:send("view_mat", 'column', view)
	shader:send("light_pos", M.light_pos)
	love.graphics.setDepthMode("lequal", true)

  lg.drawInstanced(mesh, #model_transforms)

  love.graphics.setDepthMode("always", false)
	lg.setShader(old_shader)
end

function M.attach_transforms(model_mesh, model_transforms)
  local tfs_mesh = lg.newMesh(transform_mesh_format, model_transforms, nil, 'static')
  model_mesh:attachAttribute('ModelPos', tfs_mesh, 'perinstance')
  model_mesh:attachAttribute('ModelAngle', tfs_mesh, 'perinstance')
  model_mesh:attachAttribute('ModelScale', tfs_mesh, 'perinstance')
  model_mesh:attachAttribute('ModelColor', tfs_mesh, 'perinstance')
end

return M
