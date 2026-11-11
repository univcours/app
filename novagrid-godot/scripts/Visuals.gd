extends Node2D
## Lightweight Godot-native visual system; tile shaders rendered once per palette
## into 80x80 subviewport textures and reused for all board/tray cubes.
const GALAXY = preload("res://shaders/galaxy.gdshader")
const CRYSTAL = preload("res://shaders/crystal.gdshader")
const CANDY3D = preload("res://scripts/Candy3D.gd")
var background: ColorRect
var sky_material: ShaderMaterial
var candy_renderer: Node
var tile_textures: Array[Texture2D] = []
var tile_viewports: Array[SubViewport] = []
const TILE_SIZE := 80

var reduced_effects:bool=false

func configure(palette: Array) -> void:
 var settings:=ConfigFile.new()
 if settings.load("user://novagrid-visual.cfg")==OK:
  reduced_effects=bool(settings.get_value("graphics","reduced_effects",false))
 background = ColorRect.new()
 background.name = "AnimatedNebula"
 background.mouse_filter = Control.MOUSE_FILTER_IGNORE
 background.position = Vector2.ZERO
 background.size = get_viewport_rect().size
 background.show_behind_parent = true
 background.z_index = -100
 sky_material = ShaderMaterial.new()
 sky_material.shader = GALAXY
 background.material = sky_material
 add_child(background)

 # One-shot smooth neon glass textures are baked per colour (no X facets).
 # No live per-frame viewport cost, matching low-end Android constraints.
 sky_material.set_shader_parameter("reduced_effects",reduced_effects)
 sky_material.set_shader_parameter("activity",.45 if reduced_effects else .75)
 sky_material.set_shader_parameter("motion_speed",0.0 if reduced_effects else .08)
 for gem in palette:
  var viewport := SubViewport.new()
  viewport.name = "CrystalShaderSource"
  viewport.size = Vector2i(TILE_SIZE,TILE_SIZE)
  viewport.transparent_bg = true
  viewport.disable_3d = true
  viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
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
 if candy_renderer!=null:
  var candy:Texture2D=candy_renderer.get_candy_texture(color_id)
  if candy!=null:
   return candy
 if tile_textures.is_empty():
  return null
 var index:int=clampi(color_id,0,tile_textures.size()-1)
 return tile_textures[index]

func uses_real_candy_3d() -> bool:
 return candy_renderer!=null and candy_renderer.candy_count()>=7

func set_skin(index:int) -> void:
 # Change only seven cached crystal shaders; no per-cell 3D or runtime
 # purchases. Every unlocked skin remains an offline earned-Stars cosmetic.
 var kind:int=clampi(index,0,2)
 var inner:Array=[1.30,1.55,1.86]
 var polish:Array=[.94,.96,1.0]
 for viewport in tile_viewports:
  if viewport.get_child_count()==0:continue
  var patch:ColorRect=viewport.get_child(0) as ColorRect
  if patch==null or not (patch.material is ShaderMaterial):continue
  var crystal:ShaderMaterial=patch.material as ShaderMaterial
  crystal.set_shader_parameter("inner_illumination",inner[kind])
  crystal.set_shader_parameter("shine",polish[kind])
  viewport.render_target_update_mode=SubViewport.UPDATE_ONCE

func set_theme(index:int) -> void:
 if sky_material==null:
  return
 var palettes: Array = [
  [Color("#751bdf"),Color("#1d91ff")], # NEON
  [Color("#1c6ad5"),Color("#14e5e4")], # OCEAN
  [Color("#d13bf1"),Color("#8155ff")], # VIOLET
  [Color("#2dc67d"),Color("#2cc0da")], # EMERALD
  [Color("#dc7751"),Color("#d6b13e")]  # GOLD
 ]
 var selected: Array=palettes[clampi(index,0,palettes.size()-1)]
 sky_material.set_shader_parameter("magenta_nebula",selected[0])
 sky_material.set_shader_parameter("blue_nebula",selected[1])
