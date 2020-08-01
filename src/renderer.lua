local M = {}

local dir = (...):gsub('.[^%.]+$', ''):gsub('%.', '/')
local shader = love.graphics.newShader(dir..'/shader.glsl')

local lg = love.graphics

local transform_mesh_format = {
  { 'ModelPos', 'float', 3 },
  { 'ModelAngle', 'float', 3 },
  { 'ModelScale', 'float', 1 },
  { 'ModelColor', 'byte', 4 },
}

local render_opts = {
  ambient_color = { 0.1, 0.1, 0.1 },
  light_pos = { 1000, 2000, 1000 },
  light_color = { 1, 1, 1 },
  diffuse_strength = 0.4,
  specular_strength = 0.5, -- require view_pos
  specular_shininess = 32, -- require view_pos
}

M.projection = nil
M.view = nil
M.view_pos = nil

M.shadow_depth_map = lg.newCanvas(1024, 1024, { type = '2d', format = 'depth24', readable = true })

-- projection, view: mat4, 1-based, column major matrices
-- view_pos: required for specular
function M.begin(projection, view, view_pos)
  if not projection then projection = M.projection end
  if not view then view = M.view end
  if not view_pos then view_pos = M.view_pos end

  M.old_shader = lg.getShader()
	lg.setShader(shader)
	shader:send("projection_mat", 'column', projection)
	shader:send("view_mat", 'column', view)
	shader:send("light_pos", render_opts.light_pos)
	shader:send("light_color", render_opts.light_color)
	shader:send("diffuse_strength", render_opts.diffuse_strength)
	shader:send("ambient_color", render_opts.ambient_color)

	if view_pos then
    shader:send("view_pos", view_pos)
	  shader:send("specular_strength", render_opts.specular_strength)
	  shader:send("specular_shininess", render_opts.specular_shininess)
  end
end

function M.clean()
	lg.setShader(M.old_shader)
end

function M.draw(model, model_transforms)
  local model_opts = model.options
  local mesh = model.mesh
  M.attach_transforms(mesh, model_transforms)

  M.begin()
	love.graphics.setDepthMode("lequal", model_opts.write_depth)
	love.graphics.setMeshCullMode(model_opts.face_culling)

  lg.drawInstanced(mesh, #model_transforms)

	love.graphics.setMeshCullMode('none')
  love.graphics.setDepthMode("always", false)
  M.clean()
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
