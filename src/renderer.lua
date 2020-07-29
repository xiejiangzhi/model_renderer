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

local render_opts = {
  ambient_color = { 0.1, 0.1, 0.1 },
  light_pos = { 1000, 2000, 1000 },
  light_color = { 1, 1, 1 },
  diffuse_strength = 0.4,
}

-- projection, view: mat4, 1-based, column major matrices
function M.draw(projection, view, model, model_transforms)
  local mesh = model.mesh
  M.attach_transforms(mesh, model_transforms)

  local old_shader = lg.getShader()
	lg.setShader(shader)
	shader:send("projection_mat", 'column', projection)
	shader:send("view_mat", 'column', view)
	shader:send("light_pos", render_opts.light_pos)
	shader:send("light_color", render_opts.light_color)
	shader:send("diffuse_strength", render_opts.diffuse_strength)
	shader:send("ambient_color", render_opts.ambient_color)
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

function M.set_render_opts(opts)
  for k, v in pairs(opts) do
    if k == 'ambient_color' or k == 'light_color' then
      assert(#v == 3, "Invalid RGB color")
    elseif k == 'light_pos' then
      assert(#v == 3, "Invalid coord")
    else
      assert(render_opts[k], 'Invalid render opts '..k)
    end

    render_opts[k] = v
  end
end

return M
