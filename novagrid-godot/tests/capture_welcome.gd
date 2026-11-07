extends SceneTree
## Capture REAL native Godot renderer with the new Glass Galaxy welcome UI.
func _initialize()->void:
 call_deferred("_capture")

func _capture()->void:
 DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://build"))
 var scene=load("res://scenes/Welcome.tscn")
 if scene==null:
  printerr("Welcome scene cannot be imported.")
  quit(1)
  return
 var welcome=scene.instantiate()
 root.add_child(welcome)
 await create_timer(.4).timeout
 var cards:Array[Rect2]=welcome._rectangles()
 if cards.size()!=2 or cards[1].end.y>root.get_viewport().get_visible_rect().size.y:
  printerr("Real device landing page layout has overflowing game cards")
  quit(1)
  return
 var png:Image=root.get_texture().get_image()
 if png.is_empty() or png.get_width()<400 or png.get_height()<800:
  printerr("No real Godot image from 432x960 render")
  quit(1)
  return
 var err:int=png.save_png("res://build/novagrid-real-welcome.png")
 if err!=OK:
  printerr("Unable to save actual Welcome screenshot:",err)
  quit(1)
  return
 welcome.queue_free()
 await process_frame
 await process_frame
 print("REAL NOVAGRID OPEN SOURCE HOME SCREENSHOT SAVED")
 quit(0)
