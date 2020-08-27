local M = {}
M.__index = M

local dir = (...):gsub('.init$', '')
M.model = require(dir..'.'..'model')
M.renderer = require(dir..'.'..'renderer')
M.deferred_renderer = require(dir..'.'..'deferred_renderer')
M.scene = require(dir..'.'..'scene')
M.camera = require(dir..'.'..'camera')

return M
