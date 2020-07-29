local lfs = love.filesystem

function love.keyreleased(key)
  if key == '1' then
    lfs.load('examples/hello.lua')()
    love.load()
  elseif key == '2' then
    lfs.load('examples/large_instances.lua')()
    love.load()
  end
end

function love.draw()
end

lfs.load('examples/hello.lua')()
