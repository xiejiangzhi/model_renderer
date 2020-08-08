Simple 3D Model Renderer
========================

A simple 3D model renderer for Love2D 11.3. Support simple lighting.

## Example

![Example Image](./example.png)


## Installation

Copy `src` to your project.
Copy [CPML](https://github.com/excessive/cpml) to your project. And make sure able to `require 'cpml'`


## Usage

```
local MR = require 'src'

-- Create model from obj file or basic shape
local model = MR.model.load('3d.obj')
local box = MR.model.new_box(50)
local sphere = MR.model.new_sphere(30)
local cylinder = MR.model.new_cylinder(30, 100)

local renderer, scene, camera

function love.load()
  -- Initalize render, scene and camera
  renderer = MR.renderer.new()
  renderer.light_pos = { 1000, 2000, 1000 }
  renderer.light_color = { 1, 1, 1 }
  renderer.ambient_color = { 0.6, 0.6, 0.6 }
  scene = MR.scene.new()
  camera = MR.camera.new()
end

function love.draw()
  local w, h = love.graphics.getDimensions()
  local hw, hh = w * 0.5, h * 0.5

  -- Set camera projection and view, and apply camera for renderer
  camera:orthogonal(-hw, hw, hh, -hh, -500, 2000)
  camera:look_at(0, 0, 0, math.rad(60), 0, 0)
  renderer:apply_camera(camera)

  local ts = love.timer.getTime()

  -- Add some model to scene
  -- model, coord, angle, scale, color
  scene:add_model(model, { 0, -10, 0 }, { 0, math.sin(ts) * math.pi * 2, 0 }, 10, { 0, 1, 0, 1 })
  scene:add_model(model,
    { math.sin(ts) * 100, -10, math.cos(ts) * 100 },
    { 0, math.rad(45), 0 }, 10, { 1, 0, 0, 1 }
  )
  scene:add_model(box, { -300, 0, 0 })
  scene:add_model(sphere, { -300, 0, 300 })
  scene:add_model(cylinder, { 300, 0, 300 })

  love.graphics.clear(0.5, 0.5, 0.5)
  -- Render and clean scene
  renderer:render(scene:build())
  scene:clean()
end
```

## Functions

### Model

* MR.model.new(vertices, texture, opts): new a custom model form vertices. vertex: { x, y, z, tex_x, tex_y, normal_x, normal_y, normal_z }
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

* MR.renderer.new() return a new instance
* renderer:apply_camera(camera_instance): the camera must initialized projection and view. fetch all camera attributes and apply to renderer.
* renderer:render(scene_desc):

```
  renderer:render({ model = {
    { model1, { { x, y, z, rx, ry, rz, sx, sy, sz, r, g, b, a }, transfrom2, ... } } ,
    model_conf2,
    ...
  } })
```

**Attributes**

* renderer.projection: column major 4x4 matrices
* renderer.view: column major 4x4 matrices
* renderer.view_scale: number, scale the shadow view size, default is 1
* renderer.camera_pos: { x, y, z }, must set before render
* renderer.look_at: { x, y, z }, must set before render
* renderer.render_shadow: boolean


### Scene

It is optional, you can also manually build scene description for renderer.

* MR.scene.new() return scene instance
* scene:add_model(model, coord, angle, scale, color): add a model to scene. Coord is required, other is optional

  * coord: { x, y, z } or { x = x, y = y, z = z }
  * angle: { x, y, z } or { x = x, y = y, z = z }, defualt { 0, 0, 0 }
  * scale: { x, y, z } or { x = x, y = y, z = z }, default { 1, 1, 1 }
  * color: { r, g, b, a } or { r = r, g = g, b = b, a = a }, alpha is optional, defualt is { 1, 1, 1, 1 }

* scene:clean(): reset scene, remove all models from scene.
* scene:build(): build scene for renderer. `renderer:render(scene:build())`


### Camera

It is optional, you can also manually set all camera attributes for renderer.

* MR.camera.new() return camera instance
* camera:perspective(fovy, aspect, near, far) create perspective projection for this camera
* camera:orthogonal(left, right, top, bottom, near, far) create orthogonal projection for this camera
* camera:move_to(x, y, z, rx, ry, rz) move camera to the position, set camera angle and update view
* camera:look_at(x, y, z, rx, ry, rz) look at the position use the specified angle and update view
* camera:project(point, viewport) project the world point to screen. point: Cpml.vec3 or { x = x, y = y, z = z }. viewport: { ox, oy, w, h }
* camera:unproject(screen_x, screen_y, viewport, plane) unproject the screen point to world. viewport: { ox, oy, w, h }. plane: { position = vec3, normal = vec3 }, default is { position = vec3(0, 0, 0), normal = vec3(0, 1, 0) }


## TODO

* More support for model file(mtl, tex and more)
* Better render shader
* Better shadow


## References

* [LearnOpenGL](https://learnopengl.com/)
* [LOVEPBR](https://github.com/pablomayobre/LOVEPBR)
