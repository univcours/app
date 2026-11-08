extends SceneTree
## Corrupt JSON rejection is transactional; real legal games remain resumable.
const Puzzle=preload("res://scripts/Puzzle.gd")
const Falling=preload("res://scripts/Falling.gd")
var passed:int=0
var failed:int=0

func check(condition:bool,description:String) -> void:
 if condition:
  passed+=1
 else:
  failed+=1
  printerr("INTEGRITY FAIL: ",description)

func reject_puzzle(source:Dictionary,key:String,value:Variant,label:String) -> void:
 var game=Puzzle.new()
 var before:Dictionary=game.save_state()
 var bad:Dictionary=source.duplicate(true)
 bad[key]=value
 check(not game.load_state(bad),"Classic rejects "+label)
 check(game.save_state()==before,"Classic failure leaves state intact: "+label)

func reject_falling(source:Dictionary,key:String,value:Variant,label:String) -> void:
 var game=Falling.new()
 var before:Dictionary=game.snapshot()
 var bad:Dictionary=source.duplicate(true)
 bad[key]=value
 check(not game.restore(bad),"Blockfall rejects "+label)
 check(game.snapshot()==before,"Blockfall failure leaves state intact: "+label)

func _initialize() -> void:
 var p=Puzzle.new()
 var p_saved:Dictionary=JSON.parse_string(JSON.stringify(p.save_state()))
 check(p.load_state(p_saved),"Classic accepts JSON numbers from current saves")
 var corrupt_cells:Array=p_saved["cells"].duplicate(true)
 corrupt_cells[0][0]={"bad":true}
 reject_puzzle(p_saved,"cells",corrupt_cells,"object-valued cell")
 corrupt_cells=p_saved["cells"].duplicate(true)
 corrupt_cells[0][0]=1.5
 reject_puzzle(p_saved,"cells",corrupt_cells,"fractional cell")
 corrupt_cells=p_saved["cells"].duplicate(true)
 corrupt_cells[0]=[]
 reject_puzzle(p_saved,"cells",corrupt_cells,"short row")
 for item in [null,"200",{},[],INF,NAN,-1,1.5]:
  reject_puzzle(p_saved,"score",item,"invalid score "+str(item))
 for item in [null,"color",[],[0,1,2],[1,2,8],[1,2.5,3]]:
  reject_puzzle(p_saved,"tray_colors",item,"invalid palette "+str(item))
 reject_puzzle(p_saved,"tray",[[[0,0],[0,0]],[],[]],"duplicated crystal")
 reject_puzzle(p_saved,"tray",[[[99,0]],[],[]],"off-grid shape")
 reject_puzzle(p_saved,"tray",[[[0,0],[2,0]],[],[]],"nonexistent disconnected shape")
 reject_puzzle(p_saved,"tray",[[[0,null]],[],[]],"null coordinate")
 reject_puzzle(p_saved,"tray",{},"dictionary tray")
 reject_puzzle(p_saved,"over","false","string boolean")
 reject_puzzle(p_saved,"version",2,"future version")
 reject_puzzle(p_saved,"fever",101,"out-of-range fever")
 var legacy:Dictionary=p_saved.duplicate(true)
 legacy["cells"]=[]
 for _y in 12:
  var row:Array=[]
  row.resize(10)
  row.fill(0)
  legacy["cells"].append(row)
 legacy["score"]=1234
 check(p.load_state(legacy) and p.score==1234 and p.cells.size()==9,"legacy 10x12 migration retains score")
 legacy["cells"][0]=[]
 check(not p.load_state(legacy),"malformed legacy board is rejected")
 p.reset()
 p.tray[0]=[Vector2i(0,0)]
 check(p.place(0,Vector2i(4,4)),"real placement before undo")
 check(p.undo() and p.cells[4][4]==0 and p.moves==0,"internal Vector2i undo snapshot remains compatible")
 for form in Puzzle.SHAPES:
  var legal:Dictionary=p_saved.duplicate(true)
  legal["tray"]=[form,[],[]]
  check(p.load_state(legal),"all original Classic shapes restore: "+str(form))
 var f=Falling.new()
 var f_saved:Dictionary=JSON.parse_string(JSON.stringify(f.snapshot()))
 check(f.restore(f_saved),"Blockfall accepts JSON numbers from current saves")
 for item in [null,{},"bag",[0,0],[7],[-1],[2.5]]:
  reject_falling(f_saved,"bag",item,"invalid bag "+str(item))
 for item in [null,{},"piece",[[0,0],[0,0],[1,0],[2,0]],[[99,0],[1,0],[2,0],[3,0]]]:
  reject_falling(f_saved,"piece",item,"invalid piece "+str(item))
 for item in [null,{},[],[100,0],[0,100],[-99,0],[0,null],[1.5,0]]:
  reject_falling(f_saved,"active",item,"invalid active position "+str(item))
 for item in [null,"10",{},INF,NAN,-1,2.5]:
  reject_falling(f_saved,"score",item,"invalid score "+str(item))
 reject_falling(f_saved,"kind",9,"invalid kind")
 reject_falling(f_saved,"next_kind",-1,"invalid next kind")
 reject_falling(f_saved,"hold_kind",7,"invalid hold kind")
 reject_falling(f_saved,"hold_used",1,"numeric boolean")
 reject_falling(f_saved,"over","false","string boolean")
 reject_falling(f_saved,"lock_delay_elapsed",NAN,"NaN lock timer")
 reject_falling(f_saved,"lock_delay_elapsed",-1,"negative lock timer")
 reject_falling(f_saved,"lock_resets",16,"exceeded reset count")
 reject_falling(f_saved,"version",2,"future version")
 var collision:Dictionary=f_saved.duplicate(true)
 var first:Array=collision["piece"][0]
 collision["board"][int(collision["active"][1])+int(first[1])][int(collision["active"][0])+int(first[0])]=2
 check(not f.restore(collision),"live save cannot resume inside a locked cell")
 collision["over"]=true
 check(f.restore(collision) and f.over,"legitimate blocked-spawn game over restores")
 for kind in 7:
  f.reset()
  f.kind=kind
  f.piece=f._shape(kind)
  f.active=Vector2i(3,0)
  for turn in 4:
   var copy=Falling.new()
   var rotated:Dictionary=JSON.parse_string(JSON.stringify(f.snapshot()))
   check(copy.restore(rotated) and copy.piece==f.piece,"legal kind %d rotation %d resumes"%[kind,turn])
   f.rotate()
 # Classic old saves and falling saves need no new lock-reset field.
 var old:Dictionary=f_saved.duplicate(true)
 old.erase("lock_resets")
 check(f.restore(old) and f.lock_resets==0,"old Blockfall save gets fresh manipulation budget")
 # Real floor moves eventually stop resetting the lock deadline.
 f.reset()
 f.kind=2
 f.piece=f._shape(2)
 f.active=Vector2i(3,0)
 f.active.y=f.ghost_row()
 for n in Falling.MAX_LOCK_RESETS:
  check(not f.advance_lock(.1),"ground grace before manipulation %d"%n)
  check(f.move(1 if n%2==0 else -1),"ground slide %d"%n)
 check(f.lock_resets==Falling.MAX_LOCK_RESETS,"exactly fifteen floor lock resets are allowed")
 check(not f.advance_lock(.1),"deadline can advance after budget is spent")
 check(f.move(-1),"spent budget does not disable movement")
 var budget_copy=Falling.new()
 check(budget_copy.restore(f.snapshot()) and budget_copy.lock_resets==Falling.MAX_LOCK_RESETS,"remaining lock budget survives pause/save")
 check(f.advance_lock(.33) and f.drops==1,"alternating floor moves cannot stall the game forever")
 check(f.lock_resets==0,"next piece gets a new manipulation budget")
 # Simultaneous four-line clear exercises collision, ghost, score and restart.
 f.reset()
 f.kind=0
 f.piece=[Vector2i(0,0),Vector2i(0,1),Vector2i(0,2),Vector2i(0,3)]
 f.active=Vector2i(4,0)
 for y in range(14,18):
  for x in 10:
   if x!=4:f.board[y][x]=3
 check(f.ghost_row()==14,"four-line ghost lands in the precise gap")
 f.hard_drop()
 check(f.last_lines==4 and f.lines==4 and f.score>1500,"four-line clear pays its distinct reward")
 check(not f.over and f.drops==1 and f.fits(f.piece,f.active),"after clear a legal next piece spawns")
 f.reset()
 check(f.score==0 and f.lines==0 and f.drops==0 and not f.over,"restart clears active run counters")
 print("NOVAGRID INTEGRITY: %d passed, %d failed"%[passed,failed])
 quit(0 if failed==0 else 1)
