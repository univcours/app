extends SceneTree
## Back-to-home regression for actual interactive Godot scenes.
var errors:Array[String]=[]
func _initialize() -> void:
 call_deferred("_run")
func _verify(ok:bool,description:String) -> void:
 if not ok:
  errors.append(description)
  printerr("BACK BUTTON FAIL: ",description)
func _run() -> void:
 for choice in [{"mode":0,"paused":false},{"mode":1,"paused":true},{"mode":1,"paused":false}]:
  var packed:PackedScene=load("res://scenes/Main.tscn")
  var app=packed.instantiate()
  root.add_child(app)
  current_scene=app
  app.mode=choice["mode"]
  app.paused=choice["paused"]
  await process_frame
  var rect:Rect2=app._layout()["mode_switch"]
  _verify(rect.size.x>15 and rect.position.x>=0,"valid hit target "+str(choice))
  var touch:Vector2=rect.get_center()
  app._press(touch)
  app._release(touch)
  await process_frame
  await process_frame
  _verify(current_scene!=null,"returned scene exists "+str(choice))
  if current_scene:
   _verify(current_scene.scene_file_path.ends_with("/Welcome.tscn"),
    "back arrow opens Welcome "+str(choice))
   current_scene.queue_free()
   await process_frame
   current_scene=null
 if errors.is_empty():
  print("ALL NOVAGRID BOTH-MODE BACK-TO-MENU TESTS PASSED")
  quit(0)
 else:
  quit(1)
