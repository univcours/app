extends Node2D
## Lightweight Godot-native visual system; tile shaders rendered once per palette
## into 80x80 subviewport textures and reused for all board/tray cubes.
const GALAXY = preload("res://shaders/galaxy.gdshader")
const CRYSTAL = preload("res://shaders/crystal.gdshader")
var background: ColorRect
var tile_textures: Array[Texture2D] = []
var tile_viewports: Array[SubViewport] = []
const TILE_SIZE := 80

func configure(palette: Array) -> void:
 background = ColorRect.new()
 background.name = "AnimatedNebula"
 background.mouse_filter = Control.MOUSE_FILTER_IGNORE
 background.position = Vector2.ZERO
 background.size = get_viewport_rect().size
 background.show_behind_parent = true
 background.z_index = -100
 var sky_material := ShaderMaterial.new()
 sky_material.shader = GALAXY
 background.material = sky_material
 add_child(background)

 for gem in palette:
  var viewport := SubViewport.new()
  viewport.name = "CrystalShaderSource"
  viewport.size = Vector2i(TILE_SIZE,TILE_SIZE)
  viewport.transparent_bg = true
  viewport.disable_3d = true
  viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
  add_child(viewport)
  var crystal := ColorRect.new()
  crystal.mouse_filter = Control.MOUSE_FILTER_IGNORE
  crystal.position = Vector2.ZERO
  crystal.size = Vector2(TILE_SIZE,TILE_SIZE)
  var crystal_material := ShaderMaterial.new()
  crystal_material.shader = CRYSTAL
  crystal_material.set_shader_parameter("gem_color",gem)
  crystal.material = crystal_material
  viewport.add_child(crystal)
  tile_viewports.append(viewport)
  tile_textures.append(viewport.get_texture())
 get_viewport().size_changed.connect(resize_background)

func resize_background() -> void:
 if background:
  background.size = get_viewport_rect().size

func get_gem_texture(color_id: int) -> Texture2D:
 var index := clampi(color_id,0,tile_textures.size()-1)
 if tile_textures.is_empty():
  return null
 return tile_textures[index]
