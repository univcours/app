extends SceneTree
## Actual Godot-rendered candy showroom for art QA, not a generated concept.
## Demonstrates the seven real StandardMaterial3D sweet meshes at phone scale.
const Visuals = preload("res://scripts/Visuals.gd")
const COLORS=[
 Color("#1c224a"),Color("#ff287f"),Color("#ffbe17"),Color("#13c7fa"),
 Color("#963aff"),Color("#11db60"),Color("#ff751c"),Color("#127bff")]
const NAMES=[
 "CHERRY JELLY","GOLDEN CARAMEL","BUBBLE BONBON",
 "AMETHYST GUMDROP","EMERALD GUMMY","ORANGE SUGAR",
 "SAPPHIRE CANDY"]

class SweetStage extends Node2D:
 var renderer
 var face:Font
 func _ready()->void:
  face=ThemeDB.fallback_font
  renderer=Visuals.new()
  add_child(renderer)
  renderer.configure(COLORS)
  queue_redraw()
 func _draw()->void:
  var w:float=get_viewport_rect().size.x
  draw_string(face,Vector2(0,65),"NOVAGRID 3D",HORIZONTAL_ALIGNMENT_CENTER,w,38,Color("#ffffff"))
  draw_string(face,Vector2(0,91),"JELLY • GLOSS • CANDY GALAXY",
   HORIZONTAL_ALIGNMENT_CENTER,w,13,Color("#ffe0fc"))
  draw_string(face,Vector2(0,113),"REAL GODOT 3D GEOMETRY • PBR CLEARCOAT",
   HORIZONTAL_ALIGNMENT_CENTER,w,10,Color("#b8dcff"))
  for index in 7:
   var col:int=index%2
   var row:int=int(index/2)
   var x:float=18.0+float(col)*203.0
   var y:float=130.0+float(row)*185.0
   var tile:=Rect2(Vector2(x,y),Vector2(193,176))
   draw_rect(tile.grow(3),Color(.35,.26,.7,.35),false,3.0)
   draw_rect(tile,Color(.08,.13,.34,.76),true)
   draw_rect(tile,Color(.67,.58,.92,.7),false,1.1)
   var texture:Texture2D=renderer.get_gem_texture(index+1)
   if texture!=null:
    draw_circle(Vector2(x+96,y+82),54,Color(.36,.23,.54,.21))
    draw_texture_rect(texture,Rect2(x+27,y+9,139,139),false,Color.WHITE)
   draw_string(face,Vector2(x,y+163),String(NAMES[index]),
    HORIZONTAL_ALIGNMENT_CENTER,193,13,Color("#f8efff"))
  draw_string(face,Vector2(0,934),"ORIGINAL CANDIES • OPTIMIZED FOR MOBILE",
   HORIZONTAL_ALIGNMENT_CENTER,w,11,Color("#b9e3ff"))

func _initialize()->void:
 call_deferred("_capture")

func _capture()->void:
 DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://build"))
 var stage=SweetStage.new()
 root.add_child(stage)
 await create_timer(.40).timeout
 if not stage.renderer.uses_real_candy_3d():
  printerr("Candy renderers do not expose actual 3D SubViewports")
  quit(1)
  return
 # Check that cyan and pink are truly distinct shaded sweets, not a single
 # contaminated world showing all models overlaid.
 var pink:Image=stage.renderer.get_gem_texture(1).get_image()
 var aqua:Image=stage.renderer.get_gem_texture(3).get_image()
 if pink.is_empty() or aqua.is_empty():
  printerr("Candy material render targets are empty")
  quit(1)
  return
 var a:Color=pink.get_pixel(64,64)
 var b:Color=aqua.get_pixel(64,64)
 var difference:float=absf(a.r-b.r)+absf(a.g-b.g)+absf(a.b-b.b)
 if difference<.24:
  printerr("3D palette rendered with shared/washed-out colors: ",a," vs ",b)
  quit(1)
  return
 var full:Image=root.get_texture().get_image()
 if full.is_empty():
  printerr("No real screenshot of 3D sweet collection")
  quit(1)
  return
 var err:int=full.save_png("res://build/novagrid-real-candy3d-gallery.png")
 if err!=OK:
  printerr("Saving real 3D candy screenshot failed:",err)
  quit(1)
  return
 stage.queue_free()
 await process_frame
 await process_frame
 root.remove_child(stage)
 stage.free()
 print("REAL NOVAGRID 3D CANDY GALLERY SCREENSHOT SAVED")
 quit(0)
