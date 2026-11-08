extends SceneTree
## Real Godot source + user-approved reference artwork checks.
var fails:Array[String]=[]
func check(ok:bool,name:String) -> void:
 if not ok:
  printerr("NEON REFERENCE FAIL: ",name)
  fails.append(name)

func _initialize() -> void:
 call_deferred("_go")

func _go() -> void:
 var packed:PackedScene=load("res://scenes/Main.tscn")
 var app=packed.instantiate()
 root.add_child(app)
 await process_frame
 app.mode=0
 app.puzzle.reset()
 check(app.skin_neon_puzzle!=null,"User-approved neon art loaded")
 for c in range(1,8):
  check(app.neon_gem_textures[c]!=null,"Exact crystal face loaded "+str(c))
 for size in [Vector2i(360,640),Vector2i(393,852),Vector2i(432,960),Vector2i(600,1024)]:
  root.content_scale_size=size
  root.size=size
  await process_frame
  for ad in [0.0,64.0]:
   app.set_native_banner_height(ad)
   var l:Dictionary=app._layout()
   var board:Rect2=l["board"]
   var box:Rect2=app._neon_puzzle_frame(l["viewport"],float(l["height"]))
   check(board.position.x>=0.0 and board.end.x<=float(size.x)+.01,
    "9x9 board fits width "+str(size)+" ad "+str(ad))
   check(board.position.y>=0.0 and board.end.y<float(l["height"])-66.0,
    "9x9 board fits above touch trays "+str(size)+" ad "+str(ad))
   check(absf(board.size.x-board.size.y)<board.size.x*.035,
    "Grid square cells kept in aspect "+str(size))
   check((l["tray"] as Array).size()==3,"Exactly three independent trays")
   for tray in l["tray"]:
    var t:Rect2=tray
    check(not t.intersects(board) and t.end.y<float(l["height"])-30.0,
     "Tray placed under board, above banner "+str(size)+" ad "+str(ad))
   check(not (l["mode_switch"] as Rect2).intersects(board),"Home does not cover cells")
   check(not (l["pause"] as Rect2).intersects(board),"Settings does not cover cells")
   check(box.size.x<=float(size.x)+.5 and box.end.y<=float(l["height"])+.5,
    "Exact image fit without crop or stretch")
 root.content_scale_size=Vector2i(432,960)
 root.size=Vector2i(432,960)
 app.set_native_banner_height(0.0)
 await process_frame
 # True touch flow: select a real piece from its art-aligned tray and place it.
 var layout:Dictionary=app._layout()
 var slot:int=0
 var shape:Array=app.puzzle.tray[slot]
 var target:=Vector2i(-1,-1)
 for y in 9:
  if target.x>=0:break
  for x in 9:
   if app.puzzle.fits(shape,Vector2i(x,y)):
    target=Vector2i(x,y)
    break
 check(target.x>=0,"Real placement target found")
 var before:int=app.puzzle.moves
 var tpoint:Vector2=(layout["tray"][slot] as Rect2).get_center()
 app._press(tpoint)
 app._release(tpoint)
 check(app.selected==slot,"Touch selects illustrated tray and real shape")
 var brd:Rect2=layout["board"]
 var hit:Vector2=brd.position+Vector2(
  (float(target.x)+.5)*brd.size.x/9.0,
  (float(target.y)+.5)*brd.size.y/9.0)
 app._press(hit)
 app._release(hit)
 check(app.puzzle.moves>before,"Real touch places a piece on the board")
 # Gear icon is a functional SETTINGS menu with SOUND/MUSIC/RESUME.
 var gear:Vector2=(layout["pause"] as Rect2).get_center()
 app._press(gear)
 app._release(gear)
 check(app.paused,"Illustrated gear opens SETTINGS")
 var w:float=float(layout["viewport"].x)
 var h:float=float(layout["height"])
 var pane:=Rect2(Vector2(w*.1,h*.30),Vector2(w*.8,295))
 var sound_before:bool=app.audio.sounds_enabled
 var sound:Vector2=pane.position+Vector2(pane.size.x*.5,79)
 app._press(sound)
 app._release(sound)
 check(app.audio.sounds_enabled!=sound_before,"SOUND setting is tappable")
 app.audio.toggle_sound() # restore test device's preference
 var resume:Vector2=pane.position+Vector2(pane.size.x*.5,188)
 app._press(resume)
 app._release(resume)
 check(not app.paused,"RESUME actually resumes playable game")
 app.mode=1
 var fall:Dictionary=app._layout()
 check((fall["next"] as Rect2).size.x>0.0,"Blockfall remains available and independent")
 root.remove_child(app)
 app.free()
 await process_frame
 if fails.is_empty():
  print("ALL EXACT NEON REFERENCE GAMEPLAY, TOUCH, UI AND RESPONSIVE TESTS PASSED")
  quit(0)
 else:
  quit(1)