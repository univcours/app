extends SceneTree
## Native neon glass: seven real gameplay colours, no X-face facets,
## cached one-shot GPU shaders and low-FX mobile parity.
const Visuals=preload("res://scripts/Visuals.gd")
var failures:Array[String]=[]

func check(ok:bool,description:String)->void:
 if not ok:
  failures.append(description)
  printerr("NEON GLASS FAIL: "+description)

func _initialize()->void:
 call_deferred("_run")

func _run()->void:
 var source:String=FileAccess.get_file_as_string("res://shaders/crystal.gdshader")
 check(source.contains("uniform float inner_illumination"),
  "shader has adjustable internal neon emission")
 check(source.contains("glow_core") and source.contains("glass_edge") and
  source.contains("softbox"),"smooth glass has luminous core, rim and glint")
 check(not source.contains("float diamond=") and not source.contains("float crease=")
  and not source.contains("float triangle=") and not source.contains("float diagonal="),
  "legacy internal X-shaped cube facets are removed")
 var app=load("res://scenes/Main.tscn").instantiate()
 root.add_child(app)
 app.set_process(false)
 await process_frame
 var welcome=load("res://scenes/Welcome.tscn").instantiate()
 root.add_child(welcome)
 welcome.set_process(false)
 await process_frame
 check(app.GEM_COLORS.size()==8 and welcome.GEMS.size()==8,
  "both game modes and home use 7 real neon hues plus transparent")
 for i in range(1,8):
  check(app.GEM_COLORS[i]==welcome.GEMS[i],
   "same neon hue on Home and actual Puzzle/Blockfall: "+str(i))
  var colour:Color=app.GEM_COLORS[i]
  check(colour.s>0.68 and colour.v>0.85,
   "each cube remains saturated bright neon "+str(i))
 check(app.visuals.tile_viewports.size()==8 and
  welcome.visuals.tile_viewports.size()==8,
  "both scenes cache 8 one-time colour textures")
 for scene in [app.visuals,welcome.visuals]:
  for i in range(1,8):
   var vp:SubViewport=scene.tile_viewports[i]
   check(vp.render_target_update_mode==SubViewport.UPDATE_ONCE,
    "crystal tile is baked once, not re-rendered every frame")
   check(scene.get_gem_texture(i)!=null,"each crystal supplies a Godot texture")
   var col:Color=(vp.get_child(0).material as ShaderMaterial).get_shader_parameter("gem_color")
   check(col==app.GEM_COLORS[i],
    "material shader receives exact multicolour hue")
 check(app.visuals.candy_renderer==null,
  "no hidden 3D renderer increasing per-frame phone load")
 var old:Dictionary=app.puzzle.save_state()
 app.visuals.reduced_effects=true
 app.queue_redraw()
 check(app.puzzle.save_state()==old,
  "neon style and reduced effects never change score, board, save or state")
 app.queue_free()
 welcome.queue_free()
 await process_frame
 if failures.is_empty():
  print("ALL NOVAGRID SMOOTH NEON GLASS TESTS PASSED")
  quit(0)
 else:
  printerr("%d NOVAGRID NEON GLASS TESTS FAILED"%failures.size())
  quit(1)
