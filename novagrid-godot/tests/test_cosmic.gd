extends SceneTree
## Native Cosmic Edition integration checks. Run with isolated XDG data dirs.
const SafeArea=preload("res://scripts/SafeArea.gd")
const SaveStore=preload("res://scripts/SaveStore.gd")
const Campaign=preload("res://scripts/Campaign.gd")
const Puzzle=preload("res://scripts/Puzzle.gd")
var passed:int=0
var failed:int=0

func check(value:bool,label:String) -> void:
 if value:passed+=1
 else:
  failed+=1
  printerr("COSMIC FAIL: ",label)

func same(left:Variant,right:Variant) -> bool:
 # JSON numbers decode as floats, while in-memory counters are integers.
 return JSON.parse_string(JSON.stringify(left))==JSON.parse_string(JSON.stringify(right))

func _initialize() -> void:
 call_deferred("_run")

func _write_raw(path:String,text:String) -> void:
 var file:=FileAccess.open(path,FileAccess.WRITE)
 check(file!=null,"open fixture "+path)
 if file:
  file.store_string(text)
  file.close()

func _tap(app,point:Vector2) -> void:
 app._press(point)
 app._release(point)

func _open(entry:String="classic",stage:int=1):
 var session:Node=root.get_node("Session")
 session.set("start_mode",1 if entry=="blockfall" else 0)
 session.set("entry",entry)
 session.set("stage",stage)
 var scene:PackedScene=load("res://scenes/Main.tscn")
 var app=scene.instantiate()
 root.add_child(app)
 app.set_process(false)
 return app

func _dispose(app) -> void:
 app.audio.music_player.stop()
 app.audio.music_player.stream=null
 for player in app.audio.fx_players:
  player.stop()
  player.stream=null
 root.remove_child(app)
 app.free()

func _safe_areas() -> void:
 var logical:=Vector2(432,960)
 check(SafeArea.content_rect(logical)==Rect2(Vector2.ZERO,logical),"desktop default safe area uses whole viewport")
 var physical:=Vector2(1440,3200)
 var safe:=Rect2(0,120,1440,2960)
 var expected:=Rect2(0,36,432,888)
 check(SafeArea.content_rect(logical,physical,safe).is_equal_approx(expected),"S22-like physical insets convert into logical coordinates")
 safe=Rect2(60,120,1320,2960)
 var area:Rect2=SafeArea.content_rect(logical,physical,safe)
 check(area.position.is_equal_approx(Vector2(18,36)) and area.end.is_equal_approx(Vector2(414,924)),"both side and top/bottom cutouts preserved")
 check(SafeArea.content_rect(logical,Vector2(0,3200),safe)==Rect2(Vector2.ZERO,logical),"invalid physical dimensions fall back safely")
 check(SafeArea.content_rect(logical,physical,Rect2())==Rect2(Vector2.ZERO,logical),"missing safe rectangle falls back safely")
 var clipped:Rect2=SafeArea.content_rect(logical,physical,Rect2(-50,-50,1540,3300))
 check(clipped.is_equal_approx(Rect2(Vector2.ZERO,logical)),"out-of-window safe coordinates clamp to viewport")
 for dims in [Vector2(320,568),Vector2(360,640),Vector2(432,960),Vector2(600,1024)]:
  var mapped:Rect2=SafeArea.content_rect(dims,physical,Rect2(40,120,1360,2900))
  check(Rect2(Vector2.ZERO,dims).encloses(mapped),"converted safe rectangle fits "+str(dims))
  check(mapped.position.y>0 and mapped.end.y<dims.y,"navigation/status insets stay excluded "+str(dims))

func _save_storage() -> void:
 for suffix in ["",".bak",".tmp"]:
  DirAccess.remove_absolute(ProjectSettings.globalize_path(SaveStore.PATH+suffix))
 check(SaveStore.read().is_empty(),"missing save opens a fresh profile")
 var first:Dictionary={"puzzle":{"score":120},"unknown_extension":{"keep":[1,2,3]}}
 var second:Dictionary={"puzzle":{"score":240},"unknown_extension":{"keep":[1,2,3]}}
 check(SaveStore.write(first)==OK,"first atomic save succeeds")
 check(same(SaveStore.read(),first),"first save round trips unknown fields")
 check(SaveStore.write(second)==OK,"replacement atomic save succeeds")
 check(same(SaveStore.read(),second),"replacement is current")
 check(same(SaveStore._read_path(SaveStore.PATH+".bak"),first),"previous valid generation retained as backup")
 check(not FileAccess.file_exists(SaveStore.PATH+".tmp"),"successful atomic rename consumes temporary file")
 _write_raw(SaveStore.PATH,"{broken json")
 check(same(SaveStore.read(),first),"corrupt main JSON recovers last good backup")
 check(SaveStore.write(second)==OK,"recovering save can replace corrupt main")
 check(same(SaveStore._read_path(SaveStore.PATH+".bak"),first),"corrupt main never overwrites good backup")
 _write_raw(SaveStore.PATH,"[]")
 check(same(SaveStore.read(),first),"wrong top-level JSON type falls back to backup")
 _write_raw(SaveStore.PATH+".bak","null")
 check(SaveStore.read().is_empty(),"both corrupt generations recover to fresh state")

func _campaign() -> void:
 var campaign=Campaign.new()
 check(Campaign.TOTAL_STAGES==3,"native campaign exposes three verified handcrafted missions")
 check(Campaign.stage_config(0).is_empty() and Campaign.stage_config(4).is_empty(),"out-of-range stages rejected")
 for level in range(1,4):
  var config:Dictionary=Campaign.stage_config(level)
  check(config["level"]==level and config["name"]==Campaign.NAMES[level-1],"stage identity "+str(level))
  var board:Array=Campaign.initial_board(level)
  check(board.size()==9 and board[0].size()==9,"mission starts with a 9x9 board "+str(level))
 var p=Puzzle.new()
 var config:Dictionary=Campaign.stage_config(1)
 var run:Dictionary={"specials":int(config["special_target"]),"max_combo":0}
 p.moves=int(config["min_moves"])
 p.score=int(config["score_target"])
 check(Campaign.won(1,p,run),"all stage objectives permit victory")
 p.moves-=1
 check(not Campaign.won(1,p,run),"score alone cannot bypass minimum moves")
 p.moves+=1
 p.score-=1
 check(not Campaign.won(1,p,run),"move objective cannot bypass score target")
 p.score+=1
 check(not Campaign.won(1,p,{"specials":0}),"special objective is mandatory")
 check(Campaign.rank_result(1,p,run)==1,"minimum legitimate result awards one star")
 p.score=int(config["score_target"]*1.3)
 check(Campaign.rank_result(1,p,run)==2,"higher score awards two stars")
 p.score=int(config["score_target"]*1.7)
 run["max_combo"]=3
 check(Campaign.rank_result(1,p,run)==3,"high score and combo award three stars")
 check(campaign.record_result(2,p,run)==0 and campaign.unlocked==1,"locked stage cannot award or unlock")
 check(campaign.record_result(1,p,run)==3 and campaign.unlocked==2,"first victory unlocks exactly next mission")
 p.score=int(config["score_target"])
 run["max_combo"]=0
 check(campaign.record_result(1,p,run)==1 and int(campaign.completed["1"])==3,"replay keeps previous better star rank")
 for level in [2,3]:
  config=Campaign.stage_config(level)
  p.moves=int(config["min_moves"])
  p.score=int(config["score_target"])
  run={"specials":int(config["special_target"]),"max_combo":0}
  check(campaign.record_result(level,p,run)>0,"sequential mission can be completed "+str(level))
 check(campaign.unlocked==3 and campaign.completed.size()==3,"last mission does not create phantom fourth mission")
 var copy=Campaign.new()
 check(copy.restore(JSON.parse_string(JSON.stringify(campaign.snapshot()))) and copy.completed==campaign.completed,"campaign save round trip preserves ranks")
 check(copy.restore({"version":1,"unlocked":14000,"completed":{}}) and copy.unlocked==1,"unverified unlocked field cannot bypass recorded victories")
 check(copy.restore({"version":1,"completed":{"1":2,"3":3}}) and copy.unlocked==2 and not copy.completed.has("3"),"noncontiguous corrupt completion never unlocks skipped mission")
 check(not copy.restore({"version":3,"completed":{"1":3}}),"retired web campaign version cannot imply native completion")
 for level in range(1,4):
  p.reset()
  p.cells=Campaign.initial_board(level)
  if level==1:
   p.cells[6][6]=4
  var original:Array=p.cells.duplicate(true)
  p.score=100
  p.last_groups=0
  var unchanged:Dictionary=Campaign.apply_turn(level,p,{"specials":1,"max_combo":0})
  check(p.score==100 and p.cells==original and unchanged["specials"]==1,"non-clearing turn triggers no special "+str(level))
  p.last_groups=2
  p.combo=2
  var applied:Dictionary=Campaign.apply_turn(level,p,{"specials":0,"max_combo":0})
  check(applied["max_combo"]==2 and p.best>=p.score,"special records combo and best score "+str(level))
  if level==1:
   check(applied["specials"]==2 and p.score==130 and p.cells==original,"Crystal Bloom earns per-clear bonus without deleting extra cells")
  elif level==2:
   check(applied["specials"]==1 and applied["removed"]==5 and p.score==200,"Rocket Rush clears densest line and awards exact bonus")
  else:
   check(applied["specials"]==1 and applied["removed"]==3 and p.score==196,"Nebula Guardian clears densest 3x3 patch and awards exact bonus")

func _main_integration() -> void:
 # Audio synthesis/streams have their own suite. Start these UI integration
 # fixtures muted so rapid scene teardown does not race the dummy mixer.
 var audio_preferences:=ConfigFile.new()
 audio_preferences.set_value("audio","effects",false)
 audio_preferences.set_value("audio","music",false)
 check(audio_preferences.save("user://novagrid-audio.cfg")==OK,"isolate UI test audio preferences")
 var original=Puzzle.new()
 original.cells[4][4]=3
 original.score=345
 original.best=500
 original.moves=7
 var classic:Dictionary=original.save_state()
 check(SaveStore.write({"puzzle":classic,"unknown_extension":{"preserved":true}})==OK,"seed Classic profile")
 var app=_open("daily")
 check(app.entry=="daily" and app.mode==0,"Daily opens real Classic rules in challenge mode")
 check(same(app.classic_save,classic),"Daily retains untouched Classic run")
 var daily_start:Dictionary=app.puzzle.save_state()
 var daily_rng:int=app.puzzle.rng.state
 app._new_challenge()
 check(app.puzzle.save_state()==daily_start and app.puzzle.rng.state==daily_rng,"daily seed reproduces same initial pieces and RNG state")
 app.puzzle.tray[0]=[Vector2i.ZERO]
 check(app.puzzle.place(0,Vector2i(1,1)),"Daily has playable placement mechanics")
 app._save_game()
 var disk:Dictionary=SaveStore.read()
 check(same(disk["puzzle"],classic),"challenge save cannot replace Classic board or score")
 check(disk["unknown_extension"]["preserved"],"game saves retain unknown extension data")
 var resumable:Dictionary=app.puzzle.save_state()
 var resume_rng:int=app.puzzle.rng.state
 _dispose(app)
 app=_open("daily")
 check(same(app.puzzle.save_state(),resumable) and app.puzzle.rng.state==resume_rng,"Daily resumes its own board, counters and random sequence")
 var before:int=app.progress.stars
 app.puzzle.total_lines=6
 app.puzzle.score=720
 app._challenge_turn()
 check(app.challenge_won and app.progress.stars==before+25,"daily completion earns exactly twenty-five stars")
 app._challenge_turn()
 check(app.progress.stars==before+25,"same-day completion cannot collect twice")
 app._save_game()
 _dispose(app)
 app=_open("daily")
 check(app.challenge_won,"daily victory presentation survives reopening")
 before=app.progress.stars
 app._new_challenge()
 app.puzzle.total_lines=6
 app._challenge_turn()
 check(app.progress.stars==before,"replayed daily reward stays claimed after restart")
 app._save_game()
 _dispose(app)
 app=_open("classic")
 check(same(app.puzzle.save_state(),classic),"returning to Classic restores original run")
 var layout:Dictionary=app._layout()
 _tap(app,layout["pause"].get_center())
 check(app.paused and app.settings_open,"pause button opens settings and stops gameplay")
 var boxes:Array[Rect2]=app._settings_boxes(layout)
 var sound_before:bool=app.audio.sounds_enabled
 _tap(app,boxes[0].get_center())
 check(app.audio.sounds_enabled!=sound_before and app.settings_open,"sound setting responds while paused")
 _tap(app,boxes[0].get_center())
 var quality_before:bool=app.visuals.reduced_effects
 _tap(app,boxes[2].get_center())
 check(app.visuals.reduced_effects!=quality_before,"low-effects setting changes actual visual quality")
 var preferences:=ConfigFile.new()
 check(preferences.load("user://novagrid-visual.cfg")==OK and bool(preferences.get_value("graphics","reduced_effects",quality_before))!=quality_before,"quality preference persisted")
 _tap(app,boxes[2].get_center())
 _tap(app,boxes[3].get_center())
 check(not app.paused and not app.settings_open,"Resume closes settings and returns to playable board")
 app.mode=1
 app.falling.reset()
 app.touching=true
 app.dragging=true
 var falling_before:Dictionary=app.falling.snapshot()
 app._notification(Node.NOTIFICATION_APPLICATION_PAUSED)
 check(app.paused and not app.touching and not app.dragging,"Android background pauses and cancels active gestures")
 app._process(1.0)
 check(app.falling.snapshot()==falling_before,"paused background time cannot move or lock active tetromino")
 var saved:Dictionary=SaveStore.read()
 check(same(saved["falling"]["active"],falling_before["active"]),"background lifecycle saves exact falling position")
 app.paused=false
 app._notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
 check(app.paused,"focus loss also pauses")
 for dims in [Vector2i(320,568),Vector2i(360,640),Vector2i(393,852),Vector2i(432,960),Vector2i(600,1024)]:
  root.content_scale_size=dims
  root.size=dims
  await process_frame
  for ad in [0.0,64.0]:
   app.set_native_banner_height(ad)
   for mode in 2:
    app.mode=mode
    layout=app._layout()
    var viewport:=Rect2(Vector2.ZERO,Vector2(dims))
    var board:Rect2=layout["board"]
    var safe:Rect2=layout["safe"]
    var label:String=str(dims)+" mode%d ad%d"%[mode,int(ad)]
    check(viewport.encloses(safe) and is_equal_approx(safe.end.y,float(dims.y)-ad),"ad reserve stays outside safe gameplay "+label)
    check(safe.encloses(board) and board.has_area(),"whole usable board fits safe content "+label)
    check(not board.intersects(layout["pause"]) and not board.intersects(layout["mode_switch"]),"header controls cannot cover cells "+label)
    check(not board.intersects(layout["progress"]) and not board.intersects(layout["audio"]),"footer controls cannot cover cells "+label)
    if mode==0:
     check(is_equal_approx(board.size.x,board.size.y) and layout["tray"].size()==3,"square 9x9 board and three trays "+label)
     for tray in layout["tray"]:
      check(safe.encloses(tray) and not tray.intersects(board) and not tray.intersects(layout["audio"]),"tray visible outside board/footer "+label)
     for point in [Vector2i(0,0),Vector2i(4,4),Vector2i(8,8)]:
      var pos:Vector2=board.position+(Vector2(point)+Vector2(.5,.5))*board.size/9.0
      check(app._origin_from_position(pos,false,board,[Vector2i.ZERO])==point,"precise tap-to-cell mapping "+label+str(point))
     check(app._origin_from_position(board.position-Vector2(.1,.1),false,board,[Vector2i.ZERO])==Vector2i(-1,-1),"outside edge never snaps into board "+label)
    else:
     check(is_equal_approx(board.size.y/board.size.x,1.8),"10x18 falling cells stay square "+label)
     check(safe.encloses(layout["next"]) and safe.encloses(layout["hold"]),"next and hold remain visible "+label)
     check(not board.intersects(layout["next"]) and not board.intersects(layout["hold"]),"next and hold never overlap falling cells "+label)
 root.content_scale_size=Vector2i(432,960)
 root.size=Vector2i(432,960)
 app.set_native_banner_height(0)
 _dispose(app)
 app=_open("stage",3)
 check(app.entry=="classic" and same(app.puzzle.save_state(),classic),"direct locked-stage entry safely returns to saved Classic")
 _dispose(app)
 app=_open("stage",1)
 check(app.entry=="stage" and same(app.classic_save,classic),"unlocked stage keeps Classic isolated")
 app.puzzle.moves=6
 app.puzzle.score=260
 app.puzzle.last_groups=2
 app._challenge_turn()
 check(app.challenge_won and app.campaign.unlocked==2,"stage victory integrates objectives and sequential unlock")
 app._save_game()
 check(same(SaveStore.read()["puzzle"],classic),"stage victory never replaces Classic board")
 _dispose(app)
 app=_open("stage",2)
 check(app.entry=="stage" and app.puzzle.cells==Campaign.initial_board(2),"newly unlocked second mission starts its real handcrafted board")
 _dispose(app)

func _semantic_save_recovery() -> void:
 var p=Puzzle.new()
 p.tray[0]=[Vector2i.ZERO]
 p.place(0,Vector2i(2,3))
 var good:Dictionary={"puzzle":p.save_state()}
 SaveStore.write(good)
 var damaged:Dictionary=good.duplicate(true)
 damaged["puzzle"]["cells"]=[[99]]
 SaveStore.write(damaged)
 var app=_open()
 check(same(app.puzzle.save_state(),p.save_state()),"valid JSON with corrupt board recovers semantic backup")
 _dispose(app)

func _android_back() -> void:
 var app=_open()
 app._notification(Node.NOTIFICATION_WM_GO_BACK_REQUEST)
 check(app.paused and app.settings_open,"Android system back pauses into settings")
 app._notification(Node.NOTIFICATION_WM_GO_BACK_REQUEST)
 check(not app.paused and not app.settings_open,"second Android back resumes without quitting")
 _dispose(app)

func _run() -> void:
 _safe_areas()
 _save_storage()
 _campaign()
 await _main_integration()
 _semantic_save_recovery()
 _android_back()
 await create_timer(.1).timeout
 print("NOVAGRID COSMIC: %d passed, %d failed"%[passed,failed])
 quit(0 if failed==0 else 1)
