local M = {}
M.__index = M

local dir = (...):gsub('.init$', '')
M.model = require(dir..'.'..'model')
M.renderer = require(dir..'.'..'renderer')

return M
