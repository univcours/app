extends SceneTree
## Real Classic hint integration and deterministic, side-effect-free suggestion QA.
const Puzzle=preload("res://scripts/Puzzle.gd")
const Solver=preload("res://scripts/HintSolver.gd")
var failures:Array[String]=[]

func check(value:bool,label:String)->void:
 if not value:
  failures.append(label)
  printerr("HINT FAIL: "+label)

func _initialize()->void:
 call_deferred("_run")

func _run()->void:
 var p=Puzzle.new()
 p.reset()
 for x in 8:
  p.cells[1][x]=2
 p.tray[0]=[Vector2i.ZERO]
 p.tray[1]=[]
 p.tray[2]=[]
 var before:String=JSON.stringify(p.save_state())
 var answer:Dictionary=Solver.best_move(p)
 check(answer.get("slot",-1)==0 and answer.get("origin",Vector2i(-1,-1))==Vector2i(8,1),
  "solver identifies exact last cell to clear a row")
 check(int(answer.get("groups",0))==1 and int(answer.get("cleared",0))==9,
  "solver projects the genuine row clear")
 check(JSON.stringify(p.save_state())==before and p.score==0 and p.moves==0,
  "asking for hint never changes live board, score, RNG-facing state or tray")
 var stable:Dictionary=Solver.best_move(p)
 check(stable==answer,"same puzzle produces deterministic hint")
 p.reset()
 for x in 8:
  p.cells[1][x]=3
  p.cells[2][x]=3
 p.tray[0]=[Vector2i(0,0),Vector2i(0,1)]
 p.tray[1]=[Vector2i.ZERO]
 p.tray[2]=[]
 answer=Solver.best_move(p)
 check(answer.get("slot",-1)==0 and answer.get("origin",Vector2i(-1,-1))==Vector2i(8,1),
  "two real rows are preferred over single-row clear")
 check(int(answer.get("groups",0))==2 and int(answer.get("cleared",0))==18,
  "multi-line hint counts overlapping cleared cells exactly once")
 p.reset()
 for y in 9:
  for x in 9:
   p.cells[y][x]=1
 check(Solver.best_move(p).is_empty(),"full unplayable board returns no fake hint")
 p.reset()
 p.tray=[[],[],[]]
 check(Solver.best_move(p).is_empty(),"empty tray produces no impossible suggestion")
 var app=load("res://scenes/Main.tscn").instantiate()
 root.add_child(app)
 await process_frame
 app.mode=0
 app.entry="classic"
 app.paused=false
 app.settings_open=false
 app.puzzle.reset()
 for x in 8:
  app.puzzle.cells[1][x]=1
 app.puzzle.tray[0]=[Vector2i.ZERO]
 app.puzzle.tray[1]=[]
 app.puzzle.tray[2]=[]
 var layout:Dictionary=app._layout()
 check(layout.has("hint") and layout["hint"].size.x>=44.0,
  "Classic includes a visible finger-sized HINT button")
 check(layout["hint"].end.x<=layout["safe"].end.x and
  layout["hint"].end.y<=layout["safe"].end.y,
  "HINT stays within safe area and outside native ad dock")
 check(not layout["hint"].intersects(layout["replay"]) and
  not layout["hint"].intersects(layout["bomb"]),
  "HINT does not overlap Replay or Bomb controls")
 var hint_point:Vector2=layout["hint"].get_center()
 var original_moves:int=app.puzzle.moves
 var original_score:int=app.puzzle.score
 var original_xp:int=app.progress.xp
 app._press(hint_point)
 app._release(hint_point)
 check(not app.active_hint.is_empty() and app.selected==0,
  "HINT tap previews and selects recommended tray piece")
 check(app.puzzle.moves==original_moves and app.puzzle.score==original_score and
  app.progress.xp==original_xp,
  "HINT interaction grants no points, XP, or automatic placement")
 var chosen:Vector2i=app.active_hint["origin"]
 var board:Rect2=layout["board"]
 var cell:float=board.size.x/9.0
 var touch:Vector2=board.position+Vector2((chosen.x+.5)*cell,(chosen.y+.5)*cell)
 app._press(touch)
 app._release(touch)
 check(app.puzzle.moves==1 and app.puzzle.last_groups==1,
  "player's separate tap performs the suggested real line clear")
 check(app.active_hint.is_empty() and app.selected==-1,
  "successful move clears the ghost and selected tray")
 app.puzzle.reset()
 app.active_hint.clear()
 app._press(hint_point)
 app._release(hint_point)
 check(not app.active_hint.is_empty(),"HINT still works after clearing the board")
 app._press(hint_point)
 app._release(hint_point)
 check(app.active_hint.is_empty() and app.selected==-1,
  "second HINT tap dismisses suggestion without a move")
 app.mode=1
 check(app._layout()["hint"].size==Vector2.ZERO,
  "Blockfall retains its original HUD layout without fake Hint control")
 app.queue_free()
 await process_frame
 if failures.is_empty():
  print("ALL NOVAGRID SMART HINT TESTS PASSED")
  quit(0)
 else:
  printerr("%d NOVAGRID SMART HINT TESTS FAILED"%failures.size())
  quit(1)
