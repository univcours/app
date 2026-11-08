extends SceneTree
var passed:int=0
var failed:int=0
func check(ok:bool,reason:String):
 if ok: passed+=1
 else:
  failed+=1
  printerr("FAIL: "+reason)
func _initialize(): call_deferred("run")
func run():
 var app=load("res://scenes/Welcome.tscn").instantiate()
 root.add_child(app)
 for dimensions in [Vector2i(360,640),Vector2i(432,960),Vector2i(600,1024)]:
  root.content_scale_size=dimensions
  root.size=dimensions
  await process_frame
  check(app._rectangles().size()==4,"four mode choices")
  for rect in app._rectangles():
   check(Rect2(Vector2.ZERO,Vector2(dimensions)).encloses(rect),"menu button inside viewport")
   check(rect.size.y>=44,"menu tap target at least44")
  var cards:Array=app._rectangles()
  for i in 3: check(not cards[i].intersects(cards[i+1]),"cards do not overlap")
 app.screen="home"
 var daily:Vector2=app._rectangles()[1].get_center()
 app._press(daily)
 app._release(daily)
 check(app.screen=="daily","daily card opens real daily screen")
 app.screen="home"
 var galaxy:Vector2=app._rectangles()[3].get_center()
 app._press(galaxy)
 app._release(galaxy)
 check(app.screen=="map","galaxy card opens native map")
 app._launch(0,"stage",3)
 check(app.chosen<0,"locked stage cannot launch")
 app._launch(0,"stage",1)
 check(app.chosen==0 and root.get_node("Session").entry=="stage","unlocked stage selects actual gameplay")
 app.chosen=-1
 var p=load("res://scripts/Puzzle.gd").new()
 var c=load("res://scripts/Campaign.gd").new()
 p.moves=6;p.score=260
 check(c.record_result(1,p,{"specials":1})==0,"incomplete objective cannot unlock")
 check(c.record_result(1,p,{"specials":2})==1 and c.unlocked==2,"verified first stage unlocks second")
 var restored=load("res://scripts/Campaign.gd").new()
 check(restored.restore(c.snapshot()) and restored.unlocked==2,"campaign roundtrip")
 restored.restore({"version":1,"completed":{"3":3},"unlocked":3})
 check(restored.unlocked==1,"forged skip progression rejected")
 p.cells=load("res://scripts/Campaign.gd").initial_board(2)
 p.last_groups=1;p.combo=1;p.moves=1;p.score=120;p.last_gained=120
 var result:Dictionary=c.apply_turn(2,p,{})
 check(int(result.specials)==1 and int(result.removed)==5 and p.score==220,"rocket clears actual occupied best line")
 print("MENU/CAMPAIGN CHECKS: %d passed, %d failed"%[passed,failed])
 app.queue_free()
 await process_frame
 quit(1 if failed else 0)
