extends SceneTree
## Verify candy is rendered from genuine lit 3D meshes, not flat UI tricks.
const CandyRenderer = preload("res://scripts/Candy3D.gd")
var failures:Array[String]=[]

func verify(ok:bool,label:String) -> void:
 if not ok:
  failures.append(label)
  printerr("CANDY 3D FAIL: "+label)

func _initialize() -> void:
 call_deferred("_run")

func _run() -> void:
 var studio=CandyRenderer.new()
 root.add_child(studio)
 var palette=[
  Color("#162052"),Color("#ff2677"),Color("#ffbc1d"),Color("#11dbf6"),
  Color("#a545ff"),Color("#14dd6b"),Color("#ff7d1c"),Color("#137aff")
 ]
 studio.build_candies(palette)
 verify(studio.candy_count()==8,"all eight palette entries have 3D candy textures")
 verify(studio.body_mesh!=null and studio.body_mesh.get_surface_count()==1,
  "smooth actual ArrayMesh bevelled candy geometry")
 for i in 8:
  var viewport:SubViewport=studio.render_viewports[i]
  verify(not viewport.disable_3d,"candy viewport is genuinely 3D %d"%i)
  verify(viewport.transparent_bg,"candy is composited over the live board %d"%i)
  verify(viewport.size==Vector2i(128,128),"mobile-friendly 128px candy render %d"%i)
  verify(studio.get_candy_texture(i)!=null,"each 3D candy gives a texture %d"%i)
  var world=viewport.get_node_or_null("SweetStudio")
  verify(world!=null,"actual 3D world exists %d"%i)
  if world!=null:
   var lights:int=0
   var meshes:int=0
   var coated:int=0
   var cameras:int=0
   for node in world.get_children():
    if node is DirectionalLight3D:
     lights+=1
    if node is Camera3D:
     cameras+=1
    if node is MeshInstance3D:
     meshes+=1
     if node.material_override is StandardMaterial3D:
      if node.material_override.clearcoat_enabled:
       coated+=1
   verify(lights>=2,"each candy has real studio lights %d"%i)
   verify(cameras==1,"orthographic 3D camera %d"%i)
   verify(meshes>=3,"mesh toppings and real geometry %d"%i)
   verify(coated>=2,"clearcoat PBR materials %d"%i)
 await process_frame
 await process_frame
 if failures.is_empty():
  print("ALL NOVAGRID REAL 3D CANDY ASSET TESTS PASSED")
  quit(0)
 else:
  printerr("%d REAL 3D CANDY TEST FAILURES"%failures.size())
  quit(1)
