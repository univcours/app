extends SceneTree
## Real OpenGL framebuffers at 432x960. No composed or generated screenshots.
var failures:int=0
func _initialize() -> void:call_deferred("_run")
func snap(name:String) -> void:
 await process_frame
 await RenderingServer.frame_post_draw
 var img:Image=root.get_texture().get_image()
 if img.get_size()!=Vector2i(432,960) or img.is_empty():
  failures+=1
  push_error("Unexpected framebuffer dimensions")
 var error:Error=img.save_png("res://build/"+name+".png")
 if error!=OK:
  failures+=1
  push_error("Capture failed: "+name)
 print("CAPTURE "+name+" "+str(img.get_size()))
func _run() -> void:
 var cfg:=ConfigFile.new()
 cfg.set_value("audio","effects",false)
 cfg.set_value("audio","music",false)
 cfg.save("user://novagrid-audio.cfg")
 root.size=Vector2i(432,960)
 root.content_scale_size=root.size
 DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://build"))
 var ignore:=FileAccess.open("res://build/.gdignore",FileAccess.WRITE)
 ignore.close()
 var home=load("res://scenes/Welcome.tscn").instantiate()
 root.add_child(home)
 await create_timer(.5).timeout
 await snap("01-main-menu")
 home.screen="daily"
 await snap("04-daily-challenge")
 home.screen="map"
 await snap("06-galaxy-stages")
 home.screen="settings"
 await snap("07-settings")
 home.queue_free()
 await process_frame
 var app=load("res://scenes/Main.tscn").instantiate()
 root.add_child(app)
 # Populate via actual legal engine placements, seeded to reproduce QA.
 app.puzzle.rng.seed=81108
 app.puzzle.reset()
 for n in 14:
  var placed:bool=false
  for slot in 3:
   if placed:break
   for y in range(8,-1,-1):
    if placed:break
    for x in 9:
     if app.puzzle.fits(app.puzzle.tray[slot],Vector2i(x,y)):
      app.puzzle.place(slot,Vector2i(x,y))
      placed=true
      break
  if not placed:break
 app.paused=false
 await create_timer(.2).timeout
 await snap("02-classic-populated")
 # Genuine row completion through the actual touch release handler.
 app.puzzle.reset()
 for x in 8:app.puzzle.cells[4][x]=2
 app.puzzle.tray[0]=[Vector2i.ZERO]
 app.selected=0
 var board:Rect2=app._layout()["board"]
 var point:Vector2=board.position+Vector2(8.5,4.5)*board.size.x/9.0
 app._press(point)
 app._release(point)
 if app.puzzle.last_groups!=1 or app.fragments.is_empty():
  failures+=1
  push_error("Real line-clear capture did not clear a line")
 await create_timer(.08).timeout
 await snap("03-classic-line-clear")
 app.mode=1
 app.falling.rng.seed=78
 app.falling.reset()
 for n in 7:
  for step in (n%4):app.falling.move(-1 if n%2==0 else 1)
  app.falling.hard_drop()
 app.paused=false
 await create_timer(.2).timeout
 await snap("05-blockfall-active")
 # Test actual crystal output, distinct saturated colors in rendered tiles.
 var samples:Array=[]
 var layout:Dictionary=app._layout()
 app.mode=0
 app.puzzle.reset()
 app.fragments.clear()
 app.shockwaves.clear()
 app.headlines.clear()
 app.flash=0
 for i in range(1,8):app.puzzle.cells[3][i]=i
 app.paused=false
 await process_frame
 await RenderingServer.frame_post_draw
 var rendered:Image=root.get_texture().get_image()
 board=app._layout()["board"]
 for i in range(1,8):
  var color:Color=rendered.get_pixelv(Vector2i(board.position+Vector2(i+.5,3.5)*board.size.x/9.0))
  samples.append(color)
  print("CRYSTAL ",i," ",color," saturation=",color.s)
  if color.s<.45 or color.v<.25:
   failures+=1
   push_error("Crystal shader lacks vivid color: "+str(i))
 if (samples[0] as Color).is_equal_approx(samples[2]):failures+=1
 # Coarse software-rendered frame times are diagnostics, not device FPS claims.
 var begin:int=Time.get_ticks_usec()
 for i in 60:await process_frame
 var ms:float=float(Time.get_ticks_usec()-begin)/60000.0
 app.visuals.sky_material.set_shader_parameter("reduced_effects",true)
 await process_frame
 var low_begin:int=Time.get_ticks_usec()
 for i in 60:await process_frame
 var low_ms:float=float(Time.get_ticks_usec()-low_begin)/60000.0
 var report:Dictionary={"engine":Engine.get_version_info()["string"],"viewport":[432,960],
  "renderer":RenderingServer.get_video_adapter_name(),"software_frame_ms":ms,"software_low_effects_frame_ms":low_ms,
  "screenshots":7,"failed":failures}
 var file:=FileAccess.open("res://build/render-report.json",FileAccess.WRITE)
 file.store_string(JSON.stringify(report,"  "))
 app.queue_free()
 await process_frame
 print("COSMIC CAPTURE RESULT: "+JSON.stringify(report))
 quit(0 if failures==0 else 1)
