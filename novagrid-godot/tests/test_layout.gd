extends SceneTree
## Test real Godot board coordinates on compact Android viewports, including
## the separate native-banner reserved region. Never simulates an actual ad.
const Dock = preload("res://scripts/BannerDock.gd")
var faults:Array[String]=[]
func verify(ok:bool,label:String)->void:
 if not ok:
  faults.append(label)
  printerr("LAYOUT FAIL: "+label)

func _initialize()->void:
 call_deferred("_run")

func _run()->void:
 var packed=load("res://scenes/Main.tscn")
 var app=packed.instantiate()
 root.add_child(app)
 await process_frame
 for dims in [Vector2i(360,640),Vector2i(393,852),Vector2i(432,960)]:
  # The project uses canvas_items stretching with a 432x960 design viewport.
  # Alter its LOGICAL content scale as well as Window size for phone-size QA.
  root.content_scale_size=dims
  root.size=dims
  await process_frame
  for ad_h in [0.0,64.0]:
   app.set_native_banner_height(ad_h)
   for mode_index in 2:
    app.mode=mode_index
    var layout:Dictionary=app._layout()
    var board:Rect2=layout["board"]
    var h:float=float(layout["height"])
    var width:float=float(layout["viewport"].x)
    var label:String="%s mode%d banner%d"%[str(dims),mode_index,int(ad_h)]
    verify(absf(float(layout["viewport"].y)-float(dims.y))<1.0,
     label+" logical viewport matches target size")
    verify(absf(h-(float(layout["viewport"].y)-ad_h))<1.0,
     label+" native ad reserve is separate")
    verify(board.position.x>=-1.0 and board.end.x<=width+1.0,label+" board fits viewport width")
    verify(board.position.y>=0.0 and board.end.y<h-90.0,label+" entire board stays above controls and ad")
    verify(layout["pause"].end.y<=board.position.y+8.0,label+" small pause button above gameboard")
    verify(layout["mode_switch"].end.y<=board.position.y+8.0,label+" small mode toggle above gameboard")
    if mode_index==0:
     verify(board.size.x>=width*.70,label+" puzzle uses most available width")
     verify(layout["tray"].size()==3,label+" three real draggable pieces")
     for tray in layout["tray"]:
      verify(tray.position.y>=board.end.y+2.0 and tray.end.y<=h-94.0,
       label+" all pieces remain between board and footer")
    else:
     verify(board.size.y>=board.size.x*1.78,label+" true tall 10x18 field")
     verify(layout["next"].position.x>=board.end.x,label+" NEXT cannot cover field")
     verify(layout["hold"].end.x<=width+1.0,label+" HOLD remains touchable")
   app.mode=0
   app.set_native_banner_height(0.0)
 # Exact native pixel conversion must round UP, with a physical separator.
 verify(Dock.logical_reservation(120.0,Vector2(432,960),Vector2(1080,2400))==57.0,
  "120 physical banner px reserves 48 logical pixels plus 9px neon separation")
 verify(Dock.logical_reservation(0.0,Vector2(432,960),Vector2(1080,2400))==0.0,
  "no ad means no wasted screen space")
 verify(Dock.logical_reservation(120.0,Vector2(432,960),Vector2.ZERO)==0.0,
  "invalid native dimensions cannot display overlay advertising")
 var safe_big:=Rect2(Vector2.ZERO,Vector2(432,960))
 verify(Dock.can_reserve(safe_big,57.0),"normal portrait screen supports isolated banner")
 verify(not Dock.can_reserve(Rect2(Vector2.ZERO,Vector2(320,568)),80.0),
  "compact phone skips an unsafe banner instead of covering the game")
 var sep:Rect2=Dock.dock_rect(safe_big,57.0)
 verify(absf(sep.position.y-903.0)<.01 and absf(sep.end.y-960.0)<.01,
  "native ad area is at the bottom of safe gameplay and exactly separated")
 verify(not sep.intersects(Rect2(Vector2(0,0),Vector2(432,903))),
  "banner dock never intersects the playable canvas")
 # A native banner must be hidden before loading, and only shown after
 # the independently measured game-safe dock has been reserved.
 var ad_source:=FileAccess.get_file_as_string("res://ads/AdMobRuntime.gd.txt")
 verify(ad_source.contains("banner.hide()") and
   ad_source.find("banner.hide()",ad_source.find("func _load_banner")) <
   ad_source.find("banner.load_ad(",ad_source.find("func _load_banner")),
  "native banner is hidden before any ad request")
 verify(ad_source.contains("game.reserve_native_banner_pixels(px)") and
   ad_source.contains("banner.show()"),
  "native banner only shows after its physical height is reserved")
 # Game interactions never enter the external ad dock.
 app.set_native_banner_height(64.0)
 app.mode=0
 var before_moves:int=app.puzzle.moves
 var outside:Vector2=Vector2(200,630)
 if app._layout()["safe"].end.y<=outside.y:
  app._press(outside)
  verify(not app.touching,"touch inside banner dock never reaches gameplay")
  verify(app.puzzle.moves==before_moves,"ad touches never play puzzle moves")
 app.set_native_banner_height(0.0)
 app.queue_free()
 await process_frame
 await process_frame
 if faults.is_empty():
  print("ALL NOVAGRID RESPONSIVE LAYOUT AND BANNER-DOCK TESTS PASSED")
  quit(0)
 else:
  printerr("%d NOVAGRID RESPONSIVE LAYOUT FAILURES"%faults.size())
  quit(1)
