extends Node
## Off-screen real 3D crystals rendered once to textures that can be drawn
## by the fast 2D gameplay renderer. Each crystal is a rounded 3D mesh with
## 3D lights, PBR specular/clearcoat, and a perspective-visible side face.
## All seven colors share one indexed mesh; no 3D draw calls per board cell.
const SWATCHES := [
 Color("#152858"), Color("#ff42b4"), Color("#ffc83c"), Color("#37dcff"),
 Color("#aa68ff"), Color("#1defa8"), Color("#ff9342"), Color("#4e9bff")
]
const TILE_SIZE := 144
const BEVEL := 0.16
const EXTENT := 0.98
const FACE_SEGMENTS := 8
var gem_mesh: ArrayMesh
var gem_views: Array = []
var material_cache: Array = []
var rendering_ready := false

func _ready() -> void:
 gem_mesh = make_beveled_cube()
 for i in range(1,SWATCHES.size()):
  var surface:SubViewport = _make_gem_view(i)
  add_child(surface)
  gem_views.append(surface)
 call_deferred("_render_once")

func _render_once() -> void:
 for view in gem_views:
  view.render_target_update_mode = SubViewport.UPDATE_ONCE
 rendering_ready = true

func texture_for(color_id:int) -> Texture2D:
 if not rendering_ready or color_id < 1 or color_id > gem_views.size():
  return null
 return gem_views[color_id - 1].get_texture()

func _make_gem_view(color_id:int) -> SubViewport:
 var view := SubViewport.new()
 view.name = "Crystal_%d" % color_id
 view.size = Vector2i(TILE_SIZE,TILE_SIZE)
 view.transparent_bg = true
 view.own_world_3d = true
 view.render_target_update_mode = SubViewport.UPDATE_DISABLED
 view.msaa_3d = Viewport.MSAA_4X
 view.gui_disable_input = true
 var stage := Node3D.new()
 stage.name = "CrystalStage"
 view.add_child(stage)

 var mesh_instance := MeshInstance3D.new()
 mesh_instance.name = "RealBeveledCrystalMesh"
 mesh_instance.mesh = gem_mesh
 mesh_instance.material_override = _material(color_id)
 stage.add_child(mesh_instance)

 # A small translucent diagonal glint is genuine 3D geometry on the front face.
 var glint := MeshInstance3D.new()
 glint.name = "GlassSpecularRibbon"
 var stripe := QuadMesh.new()
 stripe.size = Vector2(.96,.16)
 glint.mesh = stripe
 glint.position = Vector3(-.14,.55,1.01)
 glint.rotation_degrees.z = -22
 var shine := StandardMaterial3D.new()
 shine.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
 shine.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
 shine.albedo_color = Color(1.0,1.0,1.0,.22)
 shine.no_depth_test = false
 shine.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
 glint.material_override = shine
 stage.add_child(glint)

 var camera := Camera3D.new()
 camera.name = "CrystalCamera"
 camera.projection = Camera3D.PROJECTION_ORTHOGONAL
 camera.size = 2.75
 camera.transform = Transform3D(Basis(),Vector3(2.7,3.6,8.1)).looking_at(Vector3.ZERO,Vector3.UP)
 camera.current = true
 stage.add_child(camera)

 var key := DirectionalLight3D.new()
 key.name = "SoftboxKey"
 key.rotation_degrees = Vector3(-54,-37,0)
 key.light_color = Color("#e9f7ff")
 key.light_energy = 2.0
 stage.add_child(key)

 var rim := OmniLight3D.new()
 rim.name = "VioletRim"
 rim.position = Vector3(-2.6,1.3,-2.0)
 rim.light_color = Color("#bc8aff")
 rim.light_energy = 1.45
 rim.omni_range = 9.0
 stage.add_child(rim)

 var fill := OmniLight3D.new()
 fill.name = "CyanFill"
 fill.position = Vector3(2.0,-1.6,2.1)
 fill.light_color = Color("#45f4ff")
 fill.light_energy = .55
 fill.omni_range = 7.0
 stage.add_child(fill)

 var world := WorldEnvironment.new()
 world.name = "StudioEnvironment"
 var environment := Environment.new()
 environment.background_mode = Environment.BG_CLEAR_COLOR
 environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
 environment.ambient_light_color = Color("#7086bb")
 environment.ambient_light_energy = .64
 environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
 world.environment = environment
 stage.add_child(world)
 return view

func _material(color_id:int) -> StandardMaterial3D:
 var mat := StandardMaterial3D.new()
 var color:Color = SWATCHES[color_id]
 mat.albedo_color = color
 mat.metallic = .12
 mat.roughness = .16
 mat.metallic_specular = .93
 mat.clearcoat_enabled = true
 mat.clearcoat = .94
 mat.clearcoat_roughness = .08
 mat.emission_enabled = true
 mat.emission = color.lightened(.36)
 mat.emission_energy_multiplier = .24
 mat.refraction_enabled = false
 material_cache.append(mat)
 return mat

static func make_beveled_cube() -> ArrayMesh:
 var verts := PackedVector3Array()
 var normals := PackedVector3Array()
 var uvs := PackedVector2Array()
 var indices := PackedInt32Array()
 var inner:float = EXTENT - BEVEL
 for face in 6:
  var offset:int = verts.size()
  for y in range(FACE_SEGMENTS+1):
   for x in range(FACE_SEGMENTS+1):
    var u:float = -EXTENT+2.0*EXTENT*float(x)/float(FACE_SEGMENTS)
    var v:float = -EXTENT+2.0*EXTENT*float(y)/float(FACE_SEGMENTS)
    var point:Vector3
    match face:
     0: point = Vector3(u,v,EXTENT)       # Front
     1: point = Vector3(-u,v,-EXTENT)     # Back
     2: point = Vector3(EXTENT,v,-u)      # Right
     3: point = Vector3(-EXTENT,v,u)      # Left
     4: point = Vector3(u,EXTENT,-v)      # Top
     _: point = Vector3(u,-EXTENT,v)      # Bottom
    var core := Vector3(clampf(point.x,-inner,inner),
     clampf(point.y,-inner,inner),clampf(point.z,-inner,inner))
    var direction:Vector3 = (point-core).normalized()
    verts.append(core+direction*BEVEL)
    normals.append(direction)
    uvs.append(Vector2(float(x)/FACE_SEGMENTS,float(y)/FACE_SEGMENTS))
  for y in FACE_SEGMENTS:
   for x in FACE_SEGMENTS:
    var a:int = offset+y*(FACE_SEGMENTS+1)+x
    var b:int = a+1
    var c:int = a+FACE_SEGMENTS+1
    var d:int = c+1
    indices.append_array(PackedInt32Array([a,b,c,b,d,c]))
 var arrays:Array = []
 arrays.resize(Mesh.ARRAY_MAX)
 arrays[Mesh.ARRAY_VERTEX] = verts
 arrays[Mesh.ARRAY_NORMAL] = normals
 arrays[Mesh.ARRAY_TEX_UV] = uvs
 arrays[Mesh.ARRAY_INDEX] = indices
 var mesh := ArrayMesh.new()
 mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
 return mesh
