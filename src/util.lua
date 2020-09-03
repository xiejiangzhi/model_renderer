local M = {}

function M.send_uniform(shader, k, ...)
  if shader:hasUniform(k) then
    shader:send(k, ...)
  end
end

function M.compute_face_normal(v1, v2, v3)
  local nx = (v2[2] - v1[2]) * (v3[3] - v1[3]) - (v2[3] - v1[3]) * (v3[2] - v1[2])
  local ny = (v2[3] - v1[3]) * (v3[1] - v1[1]) - (v2[1] - v1[1]) * (v3[3] - v1[3])
  local nz = (v2[1] - v1[1]) * (v3[2] - v1[2]) - (v2[2] - v1[2]) * (v3[1] - v1[1])
  return { nx, ny, nz }
end

-- Params:
--  vs: vertices
--  fs: faces, { { vidx1, vidx2, vidx3, ... }, ... }
--        or { { { vidx1, vn = { x, y, z } }, { vidx2, vn = normal2 }, { vidx3, vn = normal3 }, ... }, ... }
-- generate_vertices({{ x, y, z }, { x2, y2, z2 }, { x3, y3, z3 }, { x4, y4, z4 }}, {{ 1, 2, 3 }, { 2, 3, 4 }})
function M.generate_vertices(vs, fs)
  if not fs then return vs end
  local vertices = {}

  for i, face in ipairs(fs) do
    local first = face[1]
    local last = face[2]
    local first_vi, first_vn, last_vi, last_vn
    if type(first) == 'number' then
      first_vi = first
    else
      first_vi, first_vn = first[1], first.vn
    end

    if type(last) == 'number' then
      last_vi, last_vn = last, nil
    else
      last_vi, last_vn = last[1], last.vn
    end

    for j = 3, #face do
      local c = face[j]
      local vn1, vn2 = first_vn, last_vn
      local vi1, vi2 = first_vi, last_vi
      local vi3, vn3
      if type(c) == 'number' then
        vi3 = c
      else
        vi3, vn3 = c[1], c.vn
      end
      local v1, v2, v3 = vs[vi1], vs[vi2], vs[vi3]
      if not vn1 or not vn2 or not vn3 then
        local vn = M.compute_face_normal(v1, v2, v3)
        if not vn1 then vn1 = vn end
        if not vn2 then vn2 = vn end
        if not vn3 then vn3 = vn end
      end

      table.insert(vertices, { v1[1], v1[2], v1[3], v1[4] or 0, v1[5] or 0, vn1[1], vn1[2], vn1[3] })
      table.insert(vertices, { v2[1], v2[2], v2[3], v2[4] or 0, v2[5] or 0, vn2[1], vn2[2], vn2[3] })
      table.insert(vertices, { v3[1], v3[2], v3[3], v3[4] or 0, v3[5] or 0, vn3[1], vn3[2], vn3[3] })
      last_vi, last_vn = vi3, vn3
    end
  end

  return vertices
end

return M
