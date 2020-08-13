Simple 3D Model Renderer
========================

A simple 3D scene renderer for Love2D 11.3. Support simple lighting.
Its goal is only to render 3d models or scenes. 

## Features

* Create model from `.obj` model file
* Create basic model: `plane`, `cycle`, `box`, `cylinder`, `sphere`.
* `perspective` and `orthogonal` camera.
* Project Love2D drawing to 3D world.
* Simple render scene with light and shadow.
* Simple PBR

## Example

![Example Image](./example.png)


## Installation

Copy `src` to your project.

Copy [CPML](https://github.com/excessive/cpml) to your project. And make sure able to `require 'cpml'`


## Usage

```
local MR = require 'model_renderer'

-- Create model from obj file or basic shape
local ground = MR.model.new_plane(2000, 2000)
local model = MR.model.load('3d.obj')
local box = MR.model.new_box(50)
local sphere = MR.model.new_sphere(30)
local cylinder = MR.model.new_cylinder(30, 100)

local renderer, scene, camera

function love.load()
  -- Initalize render, scene and camera
  renderer = MR.renderer.new()
  renderer.light_pos = { 1000, 2000, 1000 }
  renderer.light_color = { 1000000, 1000000, 1000000 }
  renderer.ambient_color = { 0.3, 0.3, 0.3 }
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
  scene:add_model(ground, { -1000, 0, -1000 }, nil, nil, { 0, 1, 0, 1 }, { 1, 0 })
  scene:add_model(model, { 0, 0, 0 }, { 0, math.sin(ts) * math.pi * 2, 0 }, 10, { 0, 1, 0, 1 }, { 0.5, 0.5 })
  scene:add_model(model,
    { math.sin(ts) * 100, 0, math.cos(ts) * 100 },
    { 0, math.rad(45), 0 }, 10, { 1, 0, 0, 1 }, { 0.5, 0.5 }
  )

  local angle = { 0, ts % (math.pi * 2), 0 }
  scene:add_model(box, { -300, 25, 0 }, angle)
  scene:add_model(sphere, { -300, 100, 300 }, angle)
  scene:add_model(cylinder, { 300, 0, 300 }, angle)

  love.graphics.clear(0.5, 0.5, 0.5)
  -- Render and clean scene
  renderer:render(scene:build())
  scene:clean()
end
```

See examples folder for more.

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
* Model:set_instances(transforms): { { x, y, z, rotate_x, rotate_y, rotate_z, scale_x, scale_y, scale_z, albedo_r, albedo_g, albedo_b, albedo_a, roughness, metallic }, ... }. Set intances for render, it will create(if not created or vertices_count < #transforms) a mesh to save all instances data and attach to the model.


### Renderer

* MR.renderer.new() return a new instance
* renderer:apply_camera(camera_instance): the camera must initialized projection and view. fetch all camera attributes and apply to renderer.
* renderer:render(scene_desc):

```
renderer:render({ model = { model1, model2, ... } })
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
* scene:add_model(model, coord, angle, scale, albedo, physics): add a model to scene. Coord is required, other is optional

  * coord: { x, y, z } or { x = x, y = y, z = z }
  * angle: { x, y, z } or { x = x, y = y, z = z }, defualt { 0, 0, 0 }
  * scale: { x, y, z } or { x = x, y = y, z = z }, default { 1, 1, 1 }
  * albedo: { r, g, b, a } or { r = r, g = g, b = b, a = a }, now alpha is unused.
  * physics: { roughness, metallic } or { roughness = 0.5, metallic = 0.5 }. value 0.0-1.0

* scene:clean(): reset scene, remove all models from scene.
* scene:build(): build scene for renderer. `renderer:render(scene:build())`. Automatically apply all transforms to models by `model:set_instances`


### Camera

It is optional, you can also manually set all camera attributes for renderer.

* MR.camera.new() return camera instance
* camera:perspective(fovy, aspect, near, far) create perspective projection for this camera
* camera:orthogonal(left, right, top, bottom, near, far) create orthogonal projection for this camera
* camera:move_to(x, y, z, rx, ry, rz) move camera to the position, set camera angle and update view
* camera:look_at(x, y, z, rx, ry, rz) look at the position use the specified angle and update view
* camera:project(point, viewport) project the world point to screen. point: Cpml.vec3 or { x = x, y = y, z = z }. viewport: { ox, oy, w, h }
* camera:unproject(screen_x, screen_y, viewport, plane) unproject the screen point to world. viewport: { ox, oy, w, h }. plane: { position = vec3, normal = vec3 }, default is { position = vec3(0, 0, 0), normal = vec3(0, 1, 0) }
* camera:attach(plane_transform) project love 2D drawing to 3D world. the `plane_transform` is a matrix to transform the 2d plane. plane_transform is optional, default just rotate `math.pi * 0.5` based on x(transform `y` of 2D to z of `3D`). The function will call `love.graphics.setShader`
* camera:detach()

## TODO

* More support for model file(mtl, tex and more)
* Better render shader
* Better shadow


## References

* [LearnOpenGL](https://learnopengl.com/)
* [LOVEPBR](https://github.com/pablomayobre/LOVEPBR)
