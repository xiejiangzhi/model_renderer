local lfs = love.filesystem

function love.load()
  lfs.load('examples/hello.lua')()
end

function love.keyreleased(key)
  if key == '1' then
    lfs.load('examples/hello.lua')()
  elseif key == '2' then
    lfs.load('examples/large_instances.lua')()
  end
end

function love.draw()
end
