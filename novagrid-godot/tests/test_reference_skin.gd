extends SceneTree
## QA exercises actual texture-backed mobile menu/gameplay branch using test
## fixtures created by CI, not an untrusted copy of a real monetized image.
var errors:Array[String]=[]
func check(ok:bool,label:String) -> void:
 if not ok:
  errors.append(label)
  printerr("REFERENCE SKIN QA FAIL: ",label)

func _initialize() -> void:
 call_deferred("_run")

func _run() -> void:
 var scene:PackedScene=load("res://scenes/Main.tscn")
 var app=scene.instantiate()
 root.add_child(app)
 await process_frame
 check(app.skin_fall!=null,"Blockfall reference texture loads")
 check(app.skin_puzzle!=null,"Puzzle cosmic backdrop texture loads")
 check(app.skin_puzzle_chrome!=null,"Real Block Puzzle luxury 9x9 chrome texture loads")
 for size in [Vector2i(360,640),Vector2i(393,852),Vector2i(432,960)]:
  root.content_scale_size=size
  root.size=size
  await process_frame
  for reserved in [0.0,64.0]:
   app.set_native_banner_height(reserved)
   app.mode=1
   var r:Dictionary=app._layout()
   var board:Rect2=r["board"]
   var content_height:float=float(r["height"])
   check(board.position.x>=0.0 and board.end.x<=float(size.x)+1.0,
    "reference Blockfall well stays on screen "+str(size)+" banner "+str(reserved))
   check(board.position.y>=0.0 and board.end.y<=content_height-90.0,
    "reference Blockfall well stays above controls "+str(size))
   check(board.size.y>=board.size.x*1.78,
    "native Blockfall 10x18 remains tall "+str(size))
   check((r["next"] as Rect2).position.x >= board.end.x,
    "live NEXT remains outside falling well "+str(size))
   check((r["hold"] as Rect2).end.x<=float(size.x)+1.0,
    "live HOLD remains touchable "+str(size))
   app.mode=0
   var p:Dictionary=app._layout()
   check((p["board"] as Rect2).size.x >= float(size.x)*.70,
    "Block Puzzle board remains large "+str(size))
   check((p["tray"] as Array).size()==3,
    "Three draggable live Puzzle shapes available "+str(size))
   var puzzle_board:Rect2=p["board"]
   check(puzzle_board.position.y>=0 and puzzle_board.end.y<float(p["height"])-110.0,
    "Exact Puzzle 9x9 leaves space for real trays "+str(size))
   if float(p["height"])>=760.0:
    check(absf(puzzle_board.size.y-puzzle_board.size.x)<puzzle_board.size.x*.08,
     "Exact Puzzle reference grid stays approximately square "+str(size))
    for slot in p["tray"]:
     var well:Rect2=slot
     check(well.position.y>puzzle_board.end.y and well.end.y<float(p["height"])-100.0,
      "All 3 live premium candy wells below 9x9 field "+str(size))
    # Verify HUD text art geometry, not only board dimensions.
    var premium_frame:Rect2=app._puzzle_chrome_frame(p["viewport"],float(p["height"]))
    var unit:float=premium_frame.size.x/941.0
    check(386.0*unit-11.0 > 350.0*unit,
     "BOMB percentage must sit BELOW illustrated BOMB heading "+str(size))
    check(not (p["bomb"] as Rect2).intersects(puzzle_board),
     "BOMB touch region overlays actual puzzle grid "+str(size))
    check(not (p["audio"] as Rect2).intersects(p["music"] as Rect2),
     "Audio and music controls overlap "+str(size))
    check((p["progress"] as Rect2).end.y <= float(p["height"])+0.75,
     "Rank footer enters AdMob dock "+str(size))
 app.mode=1
 app.set_native_banner_height(0.0)
 var old_drops:int=app.falling.drops
 app.falling.hard_drop()
 check(app.falling.drops==old_drops+1,
  "skin is decorative and real Blockfall drop still works")
 root.remove_child(app)
 app.free()
 await process_frame
 if errors.is_empty():
  print("ALL NOVAGRID EXACT REFERENCE ART GAMEPLAY TESTS PASSED")
  quit(0)
 else:
  quit(1)
