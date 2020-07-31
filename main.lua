local lfs = love.filesystem

local kr_cb
kr_cb = function(key)
  local path
  if key == '1' then
    path = 'examples/hello.lua'
  elseif key == '2' then
    path = 'examples/large_instances.lua'
  elseif key == '3' then
    path = 'examples/misc.lua'
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
  end
end
love.keyreleased = kr_cb

function love.draw()
end

lfs.load('examples/hello.lua')()
