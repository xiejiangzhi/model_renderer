local M = {}

local Cpml = require 'cpml'
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

  near = new_near or camera.near or near
  far = new_far or camera.far or far
  fov = new_fov or camera.fov or fov
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

    local yangle = camera.rotation.y + av.y
    local c, s = math.cos(-yangle), math.sin(-yangle)
    dv.x, dv.z = c * dv.x - s * dv.z, s * dv.x + c * dv.z
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
    if M.keyreleased('f1') then
      renderer.render_shadow = not renderer.render_shadow
    end

    if M.keyreleased('f3') then
      renderer.fxaa = not renderer.fxaa
    end

    local ssao = renderer.ssao
    if renderer.ssao then
      local changed = false
      if lkb.isDown('f4') then
        changed = true
        if lkb.isDown('lshift') then
          ssao.radius = math.max(1, ssao.radius - 20 * dt)
        else
          ssao.radius = ssao.radius + 20 * dt
        end
      end

      if lkb.isDown('f5') then
        changed = true
        if lkb.isDown('lshift') then
          ssao.intensity = math.max(0.1, ssao.intensity - 10 * dt)
        else
          ssao.intensity = ssao.intensity + 10 * dt
        end
      end

      if lkb.isDown('f6') then
        changed = true
        if lkb.isDown('lshift') then
          ssao.pow = math.max(0.1, ssao.pow - 0.5 * dt)
        else
          ssao.pow = ssao.pow + 0.5 * dt
        end
      end

      if changed then
        renderer:set_ssao(ssao)
      end
    end

    if lkb.isDown('`') then
      renderer.debug = true
    else
      renderer.debug = false
    end
  end
end

function M.debug(ext_str)
  lg.setColor(1, 1, 1)
  local str = ''
  str = str..string.format('\nFPS: %i', love.timer.getFPS())
  str = str..string.format('\ntime: %.1f', M.ts)
  if renderer then
    str = str..string.format('\nrenderer: %s - %s', 'normal', renderer.render_mode or 'none')
    str = str..string.format('\nfxaa: %s', tostring(renderer.fxaa or false))
    str = str..string.format('\nshadow: %s', tostring(renderer.render_shadow or false))
    local ssao = renderer.ssao
    if ssao then
      str = str..string.format(
        '\nssao: radius: %i, intensity: %.1f, samples: %i, pow: %.2f',
        ssao.radius, ssao.intensity, ssao.samples_count, ssao.pow
      )
    end
    str = str..string.format('\nsharpen: %.2f', renderer.sharpen or 0)
  end

  if camera then
    str = str..string.format('\ncamera pos: %.2f, %.2f %.2f', camera.pos:unpack())
    str = str..string.format('\ncamera angle: %.2f, %.2f, %.2f', camera.rotation:unpack())
    str = str..string.format('\nlook at: %.2f, %.2f, %.2f', camera.focus:unpack())
    str = str..string.format('\nnear far: %.1f, %.1f', near, far)
    if camera_mode == 'perspective' then
      str = str..string.format('\nfov: %.1f', fov)
    end

    local space_vertices = camera:get_space_vertices(0, 0.5)
    local min_v, max_v
    if renderer then
      min_v, max_v = renderer.shadow_builder:calc_sight_bbox(space_vertices)
    else
      min_v, max_v = MR.util.vertices_bbox(space_vertices)
    end
    str = str..string.format(
      '\ncamera space bbox: [%.1f,%.1f,%.1f] - [%.1f,%.1f,%.1f]',
      min_v.x, min_v.y, min_v.z, max_v:unpack()
    )
    str = str..string.format('\ncamera space size, %.1f', (min_v - max_v):len())
  end

  if ext_str then str = str..'\n'..ext_str end

  str = str.."\n"
  local stats = lg.getStats()
  str = str..string.format("\ndraw calls: %i", stats.drawcalls)
  str = str..string.format("\ncanvas switches: %i", stats.canvasswitches)
  str = str..string.format("\ntexture memory: %iM", stats.texturememory / 1024 / 1024)
  str = str..string.format("\nshader switches: %i", stats.shaderswitches)

  str = str.."\n"
  str = str.."\nF1 toggle shadow"
  str = str.."\nF2 switch light mode"
  str = str.."\n1-9, left or right to switch examples"
  str = str.."\nSpace to Pause/Resume time"

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

function M.replace_renderer(new)
  for k, v in pairs(renderer) do
    if k:match('_shader$') or k:match('_map') or k:match('_canvas') then
      renderer[k] = nil
    end
  end
  renderer.render_mode = nil
  renderer.ssao = nil
  renderer.shadow_builder = nil

  for k, v in pairs(new) do
    if type(v) ~= 'table' or not renderer[k] then
      renderer[k] = v
    end
  end
  setmetatable(renderer, getmetatable(new))
end

return M
