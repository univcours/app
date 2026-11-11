extends SceneTree
## Blockfall Ghost: projected piece is faint, never outlined or playable,
## and is independent of Classic HINT and the falling piece itself.
const Falling=preload("res://scripts/Falling.gd")
var failures:Array[String]=[]

func check(ok:bool,description:String)->void:
 if not ok:
  failures.append(description)
  printerr("BLOCKFALL GHOST FAIL: "+description)

func _initialize()->void:
 call_deferred("_run")

func _run()->void:
 var file:String=FileAccess.get_file_as_string("res://scripts/Main.gd")
 var start:int=file.find("func _blockfall_ghost(")
 var end:int=file.find("func _draw_falling(",start)
 check(start>=0 and end>start,"dedicated Blockfall-only landing ghost renderer exists")
 if start>=0 and end>start:
  var painter:String=file.substr(start,end-start)
  check(painter.contains("BLOCKFALL_GHOST_ALPHA") and
   painter.contains("draw_rect(tile,Color("),
   "projection uses a transparent neon colour fill")
  check(painter.contains("BLOCKFALL_GHOST_GLOW_ALPHA") and
   painter.contains("tile.grow(3.7)") and painter.contains("tile.grow(1.8)"),
   "faint Blockfall landing guide includes two diffuse glow layers")
  check(painter.contains("if not visuals.reduced_effects:"),
   "mobile reduced-effects mode skips costly secondary halo layers")
  check(not painter.contains(",false") and not painter.contains("false,") and
   not painter.contains("_gem(") and not painter.contains("draw_line(") and
   not painter.contains("draw_arc(") and not painter.contains("draw_texture"),
   "Blockfall ghost is always filled colour with no stroke, border or texture")
 check(file.contains("const BLOCKFALL_GHOST_ALPHA:float=0.10"),
  "Blockfall landing tile opacity remains faint at 10 percent")
 check(file.contains("const BLOCKFALL_GHOST_GLOW_ALPHA:float=0.028"),
  "soft neon halo remains subtle at under three percent per layer")
 check(file.contains("_blockfall_ghost(Rect2(board.position+Vector2(pos.x*cell,pos.y*cell_h)"),
  "actual Blockfall projection routes through faint borderless renderer")
 var game=load("res://scenes/Main.tscn").instantiate()
 root.add_child(game)
 game.set_process(false)
 await process_frame
 game.mode=1
 game.entry="blockfall"
 game.paused=false
 game.falling.reset()
 game.falling.kind=1
 game.falling.piece=game.falling._shape(1)
 game.falling.active=Vector2i(3,0)
 var starting:Dictionary=game.falling.snapshot()
 check(game.falling.ghost_row()==16,"an empty 18-row board lands a 2x2 piece at row 16")
 check(game.falling.snapshot()==starting,
  "querying the landing projection never moves the real falling piece")
 game.falling.board[17][3]=1
 check(game.falling.ghost_row()==15,
  "ghost projection stops above occupied landing cells")
 check(game.falling.score==0 and game.falling.lines==0,
  "landing preview cannot award points or modify score")
 var layout:Dictionary=game._layout()
 check(layout["board"].size.x>0 and layout["board"].size.y>0,
  "Blockfall ghost stays on the real responsive game board")
 game.queue_free()
 await process_frame
 if failures.is_empty():
  print("ALL NOVAGRID BLOCKFALL FAINT GHOST TESTS PASSED")
  quit(0)
 else:
  printerr("%d BLOCKFALL GHOST TESTS FAILED"%failures.size())
  quit(1)
