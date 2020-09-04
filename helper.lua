local M = {}

local Cpml = require 'Cpml'
local MR = require 'src'

local lkb = love.keyboard
local lg = love.graphics

M.ts = 0
M.pause = false

local key_state = {}

local camera_move_speed = 500
local camera_rotation_speed = math.pi

local camera, renderer, camera_mode
local near, far, fov = 1, 3000, 70

function M.reset()
  camera = nil
  camera_mode = nil
  renderer = nil
end

local oc_pos, oc_rotation
function M.bind(new_camera, new_renderer, new_camera_mode, new_near, new_far, new_fov)
  camera, renderer, camera_mode = new_camera, new_renderer, new_camera_mode
  if camera then
    oc_pos, oc_rotation = camera.pos:clone(), camera.rotation:clone()
  end

  near = new_near or near
  far = new_far or far
  fov = new_fov or fov
end

function M.update(dt)
  if not M.pause then M.ts = M.ts + dt end
  if M.keyreleased('space') then
    M.pause = not M.pause
  end

  if camera then
    local mv = camera_move_speed * dt
    local dv = Cpml.vec3(0, 0, 0)
    if lkb.isDown('a') then dv.x = dv.x - mv end
    if lkb.isDown('d') then dv.x = dv.x + mv end
    if lkb.isDown('w') then dv.z = dv.z - mv end
    if lkb.isDown('s') then dv.z = dv.z + mv end
    if lkb.isDown('q') then dv.y = dv.y - mv end
    if lkb.isDown('e') then dv.y = dv.y + mv end

    local rv = camera_rotation_speed * dt
    local av = Cpml.vec3(0, 0, 0)
    if lkb.isDown('j') then av.y = av.y - rv end
    if lkb.isDown('l') then av.y = av.y + rv end
    if lkb.isDown('i') then av.x = av.x - rv end
    if lkb.isDown('k') then av.x = av.x + rv end
    if lkb.isDown('u') then av.z = av.z - rv end
    if lkb.isDown('o') then av.z = av.z + rv end

    if lkb.isDown('[') then near = near - mv end
    if lkb.isDown(']') then near = near + mv end
    if lkb.isDown('-') then far = far - mv end
    if lkb.isDown('=') then far = far + mv end
    if lkb.isDown('t') then fov = fov + dt * 20 end
    if lkb.isDown('g') then fov = fov - dt * 20 end

    local p = camera.pos + dv
    camera:move_to(p.x, p.y, p.z, (camera.rotation + av):unpack())

    local w, h = lg.getDimensions()
    if camera_mode == 'perspective' then
      camera:perspective(fov, w / h, near, far)
    else
      local hw, hh = w / 2, h / 2
      camera:orthogonal(-hw, hw, hh, -hh, near, far)
    end
    camera.sight_dist = math.sqrt(far^2 / 2)

    if M.keyreleased('r') then
      camera:move_to(oc_pos.x, oc_pos.y, oc_pos.z, oc_rotation:unpack())
      near, far, fov = 1, 3000, 70
    end
  end

  if renderer then
    if M.keyreleased('tab') then
      if renderer.deferred_shader then
        M.convert_to_normal_renderer()
      else
        M.convert_to_deferred_renderer()
      end
    end

    if M.keyreleased('f1') then
      renderer.render_shadow = not renderer.render_shadow
    end

    if lkb.isDown('`') then
      renderer.debug = true
    else
      renderer.debug = false
    end

    if not renderer.deferred_shader and M.keyreleased('f2') then
      if renderer.render_mode == 'pure3d' then
        M.convert_to_normal_renderer()
      elseif renderer.render_mode == 'phong' then
        M.convert_to_pure3d_renderer()
      else
        M.convert_to_phong_renderer()
      end
    end
  end
end

function M.debug(ext_str)
  lg.setColor(1, 1, 1)
  local str = ''
  str = str..string.format('\nFPS: %i', love.timer.getFPS())
  str = str..string.format('\ntime: %.1f', M.ts)
  if renderer then
    if renderer.deferred_shader then
      str = str..string.format('\nrenderer: %s', 'deferred')
    else
      str = str..string.format('\nrenderer: %s - %s', 'normal', renderer.render_mode or 'none')
    end
    str = str..string.format('\nlight pos(%.2f %.2f %.2f)', unpack(renderer.light_pos))
    str = str..string.format('\nlight color(%.2f, %.2f, %.2f)',unpack(renderer.light_color))
    str = str..string.format('\nsun dir(%.1f, %.1f, %.1f)',unpack(renderer.sun_dir))
    str = str..string.format('\nsun color(%.2f, %.2f, %.2f)',unpack(renderer.sun_color))
  end

  if camera then
    str = str..string.format('\ncamera pos: %.2f, %.2f %.2f', camera.pos:unpack())
    str = str..string.format('\ncamera angle: %.2f, %.2f, %.2f', camera.rotation:unpack())
    str = str..string.format('\nlook at: %.2f, %.2f, %.2f', camera.focus:unpack())
    str = str..string.format('\nnear far: %.1f, %.1f', near, far)
    if camera_mode == 'perspective' then
      str = str..string.format('\nfov: %.1f', fov)
    end
  end

  if ext_str then str = str..'\n'..ext_str end

  str = str.."\n\nTab switch renderer"
  str = str.."\nF1 toggle shadow"
  str = str.."\nF2 swithc light mode"

  lg.print(str, 15, 0)
end

function M.keyreleased(key)
  if lkb.isDown(key) then
    key_state[key] = true
    return false
  elseif key_state[key] then
    key_state[key] = false
    return true
  end

  return false
end

function M.convert_to_deferred_renderer()
  M.replace_renderer(MR.deferred_renderer.new())
end

function M.convert_to_normal_renderer()
  M.replace_renderer(MR.renderer.new())
end

function M.convert_to_pure3d_renderer()
  local new = MR.renderer.new()
  new.render_shader = MR.util.new_shader('src/shader/pure3d.glsl')
  new.render_mode = 'pure3d'
  M.replace_renderer(new)
end

function M.convert_to_phong_renderer()
  local new = MR.renderer.new()
  new.render_shader = MR.util.new_shader('src/shader/phong.glsl', 'src/shader/vertex.glsl')
  new.render_mode = 'phong'
  M.replace_renderer(new)
end

function M.replace_renderer(new)
  for k, v in pairs(renderer) do
    if k:match('_shader$') or k:match('_map') or k:match('_canvas') then
      renderer[k] = nil
    end
  end
  renderer.render_mode = nil

  for k, v in pairs(new) do
    if type(v) ~= 'table' or not renderer[k] then
      renderer[k] = v
    end
  end
  setmetatable(renderer, getmetatable(new))
end

return M
