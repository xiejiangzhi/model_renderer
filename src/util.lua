local M = {}

local tan = math.tan
local rad = math.rad

function M.new_mat4()
  return {
    0, 0, 0, 0,
    0, 0, 0, 0,
    0, 0, 0, 0,
    0, 0, 0, 0,
  }
end

-- From CPML
function M.mat4_from_ortho(left, right, top, bottom, near, far)
	local out = M.new_mat4()
	out[1]    =  2 / (right - left)
	out[6]    =  2 / (top - bottom)
	out[11]   = -2 / (far - near)
	out[13]   = -((right + left) / (right - left))
	out[14]   = -((top + bottom) / (top - bottom))
	out[15]   = -((far + near) / (far - near))
	out[16]   =  1
	return out
end

function M.mat4_from_perspective(fovy, aspect, near, far)
	assert(aspect ~= 0, "Invalid aspect")
	assert(near   ~= far, "Invalid near & far")

	local t   = tan(rad(fovy) / 2)
	local out = M.new_mat4()
	out[1]    =  1 / (t * aspect)
	out[6]    =  1 / t
	out[11]   = -(far + near) / (far - near)
	out[12]   = -1
	out[15]   = -(2 * far * near) / (far - near)
	out[16]   =  0
	return out
end

-- From CPML
function M.mat4_look_at(eye, look_at, up)
  if not up then up = { 0, 1, 0 } end
	local z_axis = M.vec3_normalize(M.vec3_sub(eye, look_at))
	local x_axis = M.vec3_normalize(M.vec3_cross(up, z_axis))
	local y_axis = M.vec3_cross(z_axis, x_axis)
  local out = {}
	out[1] = x_axis[1]
	out[2] = y_axis[1]
	out[3] = z_axis[1]
	out[4] = 0
	out[5] = x_axis[2]
	out[6] = y_axis[2]
	out[7] = z_axis[2]
	out[8] = 0
	out[9] = x_axis[3]
	out[10] = y_axis[3]
	out[11] = z_axis[3]
	out[12] = 0
	out[13] = 0
	out[14] = 0
	out[15] = 0
	out[16] = 1
  return out
end

function M.vec3_normalize(a)
  local out = {}
  local len = math.sqrt(a[1]^2 + a[2]^2 + a[3]^2)
  out[1] = a[1] / len
  out[2] = a[2] / len
  out[3] = a[3] / len
	return out
end

function M.vec3_cross(a, b)
  return {
    b[3] - a[3] * b[2],
		a[3] * b[1] - a[1] * b[3],
		a[1] * b[2] - a[2] * b[1]
  }
end

function M.vec3_sub(a, b)
  return {
    a[1] - b[1],
    a[2] - b[2],
    a[3] - b[3],
  }
end

return M
