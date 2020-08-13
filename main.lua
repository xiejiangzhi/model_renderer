local lfs = love.filesystem

local kr_cb

local fs = {}
local idx
for i, name in ipairs(love.filesystem.getDirectoryItems('examples')) do
  if name:match('.lua$') then
    fs[#fs + 1] = 'examples/'..name
    if name == 'hello.lua' then
      idx = #fs
    end
  end
end
table.sort(fs)
if not idx then idx = 1 end

kr_cb = function(key)
  local v = tonumber(key)
  local path

  if v then
    path = fs[v]
  elseif key == 'up' or key == 'left' then
    idx = (idx - 2) % #fs + 1
    path = fs[idx]
  elseif key == 'down' or key == 'right' then
    idx = idx % #fs + 1
    path = fs[idx]
  elseif key == 'tab' and love.renderer then
    local r = love.renderer
    if r.render_mode == 'pbr' then
      r:set_render_mode('phong')
    else
      r:set_render_mode('pbr')
    end
  end

  if path then
    love.keyreleased = nil
    lfs.load(path)()
    love.load()
    local new_cb = love.keyreleased
    if new_cb then
      love.keyreleased = function(...)
        kr_cb(...)
        new_cb(...)
      end
    else
      love.keyreleased = kr_cb
    end
    love.window.setTitle(path)
  end
end
love.keyreleased = kr_cb

function love.draw()
end

kr_cb(tostring(idx))

