local M = {}

function M.send_uniform(shader, k, ...)
  if shader:hasUniform(k) then
    shader:send(k, ...)
  end
end

return M
