local M = {}

local Cpml = require 'Cpml'

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
      if renderer.render_mode == 'pbr' then
        renderer:set_render_mode('phong')
      elseif renderer.render_mode == 'phong' then
        renderer:set_render_mode('pure3d')
      else
        renderer:set_render_mode('pbr')
      end
    end

    if M.keyreleased('f1') then
      renderer.render_shadow = not renderer.render_shadow
    end
  end
end

function M.debug(ext_str)
  lg.setColor(1, 1, 1)
  local str = ''
  str = str..string.format('\nFPS: %i', love.timer.getFPS())
  str = str..string.format('\ntime: %.1f', M.ts)

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

return M
