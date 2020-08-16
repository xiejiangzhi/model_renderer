local M = {}

local Cpml = require 'Cpml'
local Mat4 = Cpml.mat4

local cos = math.cos
local sin = math.sin

-- angle: vec3
-- scale: vec3
function M.build_model_mat4(angle, scale)
  local c1 = cos(angle.z);
  local s1 = sin(angle.z);
  local c2 = cos(angle.x);
  local s2 = sin(angle.x);
  local c3 = cos(angle.y);
  local s3 = sin(angle.y);

  local tfm = Mat4(
    c1 * c3 - s1 * s2 * s3, c3 * s1 + c1 * s2 * s3, -c2 * s3,
    -c2 * s1, c1 * c2, s2,
    c1 * s3 + c3 * s1 * s2, s1 * s3 - c1 * c3 * s2, c2 * c3
  )

  if not scale then return tfm end
  return tfm:scale(tfm, scale)
end

return M
