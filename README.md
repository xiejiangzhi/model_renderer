Simple 3D Model Renderer
========================

A simple 3D model renderer for Love2D 11.3. Support simple lighting.

## Example

![Example Image](./example.png)


## Installation

Copy `src` to your project.

And recommend use [CPML](https://github.com/excessive/cpml) to build projection and view matrix.


## Usage

```
local MR = require 'model_renderer'
local Cpml = require 'cpml'

local model = MR.model.load('3d.obj')
local box = MR.model.new_box(50)
local sphere = MR.model.new_sphere(30)
local cylinder = MR.model.new_cylinder(30, 100)

local renderer

function love.load()
  renderer = MR.renderer.new()
  renderer.light_pos = { 1000, 2000, 1000 }
  renderer.light_color = { 1, 1, 1 }
  renderer.ambient_color = { 0.6, 0.6, 0.6 }
end

function love.draw()
  local w, h = love.graphics.getDimensions()
  local hw, hh = w * 0.5, h * 0.5

  local projection = Cpml.mat4.from_ortho(-hw, hw, hh, -hh, -500, 1000)
  local view = Cpml.mat4()
  -- z is face to user
  local eye = Cpml.vec3(0, math.sin(math.rad(60)) * 200, 200)
  local target = Cpml.vec3(0, 0, 0)
  view:look_at(view, eye, target, Cpml.vec3(0, 1, 0))

  renderer.projection = projection
  renderer.view = view
  renderer.camera_pos = { eye:unpack() }
  renderer.look_at = { target:unpack() }

  local ts = love.timer.getTime()

  -- pos.x, pos.y, pos.z
  -- angle.x, angle.y, angle.z
  -- scale
  -- r, g, b, a
  local instance_transforms = {
    {
      0, -10, 0,
      0, math.sin(ts) * math.pi * 2, 0,
      10,
      0, 1, 0, 1
    },
    {
      math.sin(ts) * 100, -10, math.cos(ts) * 100,
      0, math.rad(45), 0,
      10,
      1, 0, 0, 1
    }
  }

  love.graphics.clear(0.5, 0.5, 0.5)
  renderer:render({ model = {
    { model, instance_transforms },
    { box, {{ -300, 0, 0, 0, 0, 0, 1 }}},
    { sphere, {{ -300, 0, 300, 0, 0, 0, 1, 1, 1, 0 }} },
    { cylinder, {{ 300, 0, 300, 0, 0, 0, 1 }} }
  } })
end
```

## Functions

### Model

* MR.model.new(vertices, texture, opts): new a custom model form vertices
* MR.model.load(path): load a model from `.obj` file
* MR.model.new_plane(width, height)
* MR.model.new_circle(radius, segments)
* MR.model.new_box(xlen, ylen, zlen)
* MR.model.new_cylinder(radius, height, segments)
* MR.model.new_sphere(radius_x, radius_y, radius_z, segments)
* Model:set_texture(texture): image or canvas
* Model:set_opts(opts)
  * write_depth = true,
  * face_culling = 'back', -- 'back', 'front', 'none'
  * diffuse_strength = 0.4,
  * specular_strength = 0.5,
  * specular_shininess = 16,

### Renderer

* MR.renderer.new()
* MR.renderer:render(scene):

```
  renderer:render({ model = {
    { model1, { { x, y, z, rx, ry, rz, scale, r, g, b, a }, transfrom2, ... } } ,
    model_conf2, ...
  } })
```

**Attributes**

* renderer.projection: column major 4x4 matrices
* renderer.view: column major 4x4 matrices
* renderer.camera_pos: { x, y, z }, must set before render
* renderer.look_at: { x, y, z }, must set before render
* renderer.render_shadow: boolean



## TODO

* More support for model file
* Better render shader
* Better shadow


## References

* [LearnOpenGL](https://learnopengl.com/)
* [LOVEPBR](https://github.com/pablomayobre/LOVEPBR)
