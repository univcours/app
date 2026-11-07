extends SceneTree
## Godot 4.5.1 regression tests for MIT-derived modern tetromino mechanics.
const Falling = preload("res://scripts/Falling.gd")
const Kicks = preload("res://scripts/WallKicks.gd")
const Welcome = preload("res://scripts/Welcome.gd")
var faults:Array=[]
func verify(condition:bool,reason:String)->void:
 if not condition:
  faults.append(reason)
  printerr("OPEN SOURCE FAIL: "+reason)

func _initialize()->void:
 var f=Falling.new()
 verify(Kicks.offsets(0,0).size()>=5,"MIT SRS I-piece source kick data loaded")
 verify(Kicks.offsets(2,1).size()>=5,"MIT SRS common piece kick data loaded")
 f.kind=2
 f.piece=f._shape(2)
 f.active=Vector2i(3,0)
 var was:Vector2i=f.active
 verify(f.rotate(),"T tetromino rotates using MIT wall kicks")
 verify(f.rotation_state==1,"rotation state advances clockwise")
 verify(f.rotate(-1),"counter-clockwise rotation accepts reverse kick tests")
 verify(f.rotation_state==0,"rotation state returns to zero")
 verify(f.active.distance_to(was)<5.0,"rotation does not teleport across board")
 f.active=Vector2i(0,0)
 verify(f.rotate(),"wall rotation can use wall kick near border")
 for tile in f.piece:
  var pos:Vector2i=f.active+tile
  verify(pos.x>=0 and pos.x<10,"every rotated crystal remains within board")
 f.active.y=f.ghost_row()
 var original_score:int=f.score
 var original_drops:int=f.drops
 verify(not f.advance_lock(.20),"floor contact must have grace period")
 verify(f.drops==original_drops,"piece remains controllable during lock delay")
 verify(f.advance_lock(.25),"piece locks once fair lock delay has elapsed")
 verify(f.drops==original_drops+1,"one piece locked only once")
 verify(f.score==original_score,"landing alone grants zero points")
 verify(f.lock_delay_elapsed==0.0,"spawn resets lock timer")
 var save:Dictionary=f.snapshot()
 var restored=Falling.new()
 verify(restored.restore(save),"new rotation and lock fields survive save")
 verify(restored.rotation_state==f.rotation_state,"rotation state restored")
 var home=Welcome.new()
 root.add_child(home)
 var cards:Array[Rect2]=home._rectangles()
 verify(cards.size()==2,"new Galaxy home has two real selectable modes")
 verify(cards[0].size.y>100 and cards[1].position.y>cards[0].end.y,
  "two touch cards do not overlap")
 home.queue_free()
 if faults.is_empty():
  print("ALL NOVAGRID OPEN SOURCE REBUILD TESTS PASSED")
  quit(0)
 else:
  printerr("%d OPEN SOURCE REBUILD TESTS FAILED" % faults.size())
  quit(1)
