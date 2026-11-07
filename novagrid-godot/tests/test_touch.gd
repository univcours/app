extends SceneTree
## Exercise the actual Godot touch handlers (not only the rules classes).
var faults: Array=[]
func verify(value:bool,label:String) -> void:
 if not value:
  faults.append(label)
  printerr("TOUCH FAIL: "+label)

func _initialize() -> void:
 call_deferred("_run_touch")

func _run_touch() -> void:
 var scene=load("res://scenes/Main.tscn")
 var app=scene.instantiate()
 root.add_child(app)
 var layout:Dictionary=app._layout()
 verify(layout["buttons"].is_empty(),"no obsolete directional or restart buttons")
 var found:=false
 var slot:=0
 var origin:=Vector2i.ZERO
 for s in 3:
  if found:
   break
  for row in 12:
   if found:
    break
   for col in 10:
    if app.puzzle.fits(app.puzzle.tray[s],Vector2i(col,row)):
     origin=Vector2i(col,row)
     slot=s
     found=true
     break
 verify(found,"find playable placement")
 if found:
  var chosen:Rect2=layout["tray"][slot]
  var tray_pt:Vector2=chosen.get_center()
  app._press(tray_pt)
  app._release(tray_pt)
  verify(app.selected==slot,"tap selected a crystal")
  var cell:float=layout["board"].size.x/10.0
  var play_pt:Vector2=layout["board"].position+Vector2((origin.x+.3)*cell,(origin.y+.3)*cell)
  app._press(play_pt)
  app._release(play_pt)
  verify(app.puzzle.moves==1 and app.progress.total_plays==1,"tap-to-place earns real XP")
  verify(app.selected==-1,"successful placement clears selection")
 # Blockfall has only gestures, with a consistent snap + smooth drawn motion.
 app.mode=1
 var f_layout:Dictionary=app._layout()
 verify(f_layout["buttons"].is_empty(),"no Blockfall direction buttons")
 var mid:Vector2=f_layout["board"].get_center()
 var stride:float=f_layout["board"].size.x/10.0
 var start_x:int=app.falling.active.x
 app._press(mid)
 app._move_pointer(mid+Vector2(stride*1.2,0))
 app._release(mid+Vector2(stride*1.2,0))
 verify(app.falling.active.x>start_x,"horizontal swipe moves falling block")
 var previous_drops:int=app.falling.drops
 app._press(mid)
 app._release(mid+Vector2(0,stride*4.1))
 verify(app.falling.drops==previous_drops+1 and app.progress.total_drops==1,"down swipe hard-drops and rewards once")
 verify(app.progress.snapshot().has("active_theme"),"cosmetic unlock state persists")
 if faults.is_empty():
  print("ALL NOVAGRID TOUCH CONTROLS PASSED")
  quit(0)
 else:
  printerr("%d NOVAGRID TOUCH CONTROL FAILURES" % faults.size())
  quit(1)
