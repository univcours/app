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
  for row in 9:
   if found:
    break
   for col in 9:
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
  var cell:float=layout["board"].size.x/9.0
  var play_pt:Vector2=layout["board"].position+Vector2((origin.x+.3)*cell,(origin.y+.3)*cell)
  app._press(play_pt)
  app._release(play_pt)
  verify(app.puzzle.moves==1 and app.progress.total_plays==1,"tap-to-place earns real XP")
  verify(app.selected==-1,"successful placement clears selection")
 # Real HUD button, armed state, touch-target detonation and zero-score rescue.
 app.puzzle.reset()
 app.puzzle.cells[4][4]=3
 app.puzzle.cells[5][4]=2
 app.puzzle.bombs=1
 var score_before:int=app.puzzle.score
 var bomb_button:Vector2=app._layout()["bomb"].get_center()
 app._press(bomb_button)
 app._release(bomb_button)
 verify(app.bomb_armed and app.puzzle.bombs==1,"glass bomb HUD arms with touch")
 var b:Rect2=app._layout()["board"]
 var square:float=b.size.x/9.0
 var blast_position:Vector2=b.position+Vector2(square*4.5,square*4.5)
 app._press(blast_position)
 app._release(blast_position)
 verify(not app.bomb_armed and app.puzzle.bombs==0,"touch bomb is consumed once")
 verify(app.puzzle.cells[4][4]==0 and app.puzzle.cells[5][4]==0,"bomb clears the chosen 3x3 grid zone")
 verify(app.puzzle.score==score_before and app.puzzle.total_lines==0,"bomb never grants points or line clears")
 # Blockfall has only gestures, with a consistent snap + smooth drawn motion.
 app.mode=1
 var f_layout:Dictionary=app._layout()
 verify(f_layout["next"].position.x>=f_layout["board"].end.x,
  "NEXT reference card is physically outside the falling board")
 verify(f_layout["hold"].position.x>=f_layout["board"].end.x,
  "HOLD reference card is physically outside the falling board")
 verify(f_layout["hold"].end.x<=f_layout["viewport"].x+1.0,
  "HOLD is visible and touchable even on mobile width")
 var original_kind:int=app.falling.kind
 var hold_point:Vector2=f_layout["hold"].get_center()
 app._press(hold_point)
 app._release(hold_point)
 verify(app.falling.hold_kind==original_kind and app.falling.hold_used,
  "real right-hand HOLD card stores one falling block by tap")
 app._press(hold_point)
 app._release(hold_point)
 verify(app.falling.hold_kind==original_kind,
  "HOLD card does not allow infinite swaps before a lock")
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
 app.queue_free()
 await process_frame
 await process_frame
 if faults.is_empty():
  print("ALL NOVAGRID TOUCH CONTROLS PASSED")
  quit(0)
 else:
  printerr("%d NOVAGRID TOUCH CONTROL FAILURES" % faults.size())
  quit(1)
