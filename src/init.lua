local M = {}

local dir = (...):gsub('.init$', '')

M.model = require(dir..'.model')
M.renderer = require(dir..'.renderer')
M.scene = require(dir..'.scene')
M.camera = require(dir..'.camera')
M.util = require(dir..'.util')

return M
