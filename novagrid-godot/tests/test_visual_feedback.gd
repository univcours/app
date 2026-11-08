extends SceneTree
var errors:Array[String]=[]
func check(ok:bool,msg:String)->void:
 if not ok:
  errors.append(msg)
  printerr("VISUAL FEEDBACK ERROR: "+msg)
func _initialize()->void:
 call_deferred("_run")
func _run()->void:
 var app=load("res://scenes/Main.tscn").instantiate()
 root.add_child(app)
 await process_frame
 var layout:Dictionary=app._layout()
 var footer:Rect2=layout["progress"]
 check(footer.size.y>=40,"progress HUD readable")
 check(footer.end.y<=float(layout["height"]),"progress HUD stays inside safe area")
 app._burst(Vector2(160,300),20,Color("#00ddff"))
 check(app.shockwaves.size()==1,"crystal burst is emitted")
 if app.shockwaves.size()>0:
  check(float(app.shockwaves[0]["radius"])<=72,"burst does not obscure board")
 app._announce("CLEAR",Vector2(180,300),Color("#00ddff"))
 app._announce("CLEAR",Vector2(180,300),Color("#00ddff"))
 check(app.headlines.size()==1,"duplicate message coalesces")
 app._announce("ACHIEVEMENT",Vector2(180,330),Color("#ff31ed"))
 app._announce("COMBO",Vector2(180,350),Color("#ff31ed"))
 check(app.headlines.size()==2,"headlines limited to two")
 app.queue_free()
 await process_frame
 if errors.is_empty():
  print("ALL NOVAGRID VISUAL FEEDBACK TESTS PASSED")
  quit(0)
 else:quit(1)
