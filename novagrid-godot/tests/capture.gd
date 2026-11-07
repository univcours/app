extends SceneTree
## Capture the ACTUAL Godot renderer, not a mockup or generated concept image.
## Usage: xvfb-run -a godot --path novagrid-godot --script res://tests/capture.gd
func _initialize() -> void:
 call_deferred("_capture")

func _capture() -> void:
 DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://build"))
 var packed = load("res://scenes/Main.tscn")
 var app = packed.instantiate()
 root.add_child(app)
 # A real run with pieces locked onto the board makes screenshots representative.
 for n in 15:
  var played := false
  for slot in 3:
   if played:
    break
   var shape: Array = app.puzzle.tray[slot]
   if shape.is_empty():
    continue
   for y in range(8,-1,-1):
    if played:
     break
    for x in 9:
     if app.puzzle.fits(shape,Vector2i(x,y)):
      app.puzzle.place(slot,Vector2i(x,y))
      app.progress.placed_piece()
      if app.puzzle.last_cleared>0:
       app.progress.cleared_lines(app.puzzle.last_groups,app.puzzle.combo)
      played = true
      break
  if not played or app.puzzle.over:
   break
 await create_timer(.3).timeout
 var screenshot:Image = root.get_texture().get_image()
 # Visual regression: reject washed-out white mockup-like cubes. The
 # approved reference contains richly saturated, glowing glass gemstones.
 var puzzle_rect:Rect2=app._layout()["board"]
 var tile_size:float=puzzle_rect.size.x/9.0
 var max_saturation:float=0.0
 for yy in 9:
  for xx in 9:
   if int(app.puzzle.cells[yy][xx])<=0:
    continue
   var px:Vector2i=Vector2i(puzzle_rect.position+Vector2((xx+.5)*tile_size,(yy+.5)*tile_size))
   var color:Color=screenshot.get_pixelv(px)
   var vivid:float=maxf(color.r,maxf(color.g,color.b))-minf(color.r,minf(color.g,color.b))
   max_saturation=maxf(max_saturation,vivid)
 if max_saturation<.38:
  printerr("Crystal visual QA failed: colors look washed out: ",max_saturation)
  quit(1)
  return
 print("CRYSTAL COLOR SATURATION QA PASSED: ",max_saturation)
 var err:int = screenshot.save_png("res://build/novagrid-real-puzzle.png")
 if err!=OK:
  printerr("Unable to capture Block Puzzle: ",err)
  quit(1)
  return
 app.mode = 1
 for n in 7:
  if app.falling.over:
   break
  var direction:int=-1 if n%2==0 else 1
  for step in (n%3)+1:
   app.falling.move(direction)
  app.falling.hard_drop()
  app.progress.locked_falling_piece()
  if app.falling.last_lines>0:
   app.progress.cleared_lines(app.falling.last_lines,app.falling.combo)
 await create_timer(.3).timeout
 screenshot = root.get_texture().get_image()
 err = screenshot.save_png("res://build/novagrid-real-blockfall.png")
 if err!=OK:
  printerr("Unable to capture Blockfall: ",err)
  quit(1)
  return
 if app.audio.fx_players.size()!=6 or app.audio.music_tracks.size()!=2:
  printerr("Audio engine not initialized")
  quit(1)
  return
 # Trigger the SAME real explosion/announcement functions used by gameplay.
 # This is an FX QA screenshot, not an invented score or a gameplay clear.
 app.mode=0
 var center:Vector2=app._layout()["board"].get_center()
 app._burst(center,70,Color("#ff74ea"))
 app._announce("NOVA FEVER!",center+Vector2(0,-55),Color("#ffe4ff"))
 await create_timer(.07).timeout
 screenshot=root.get_texture().get_image()
 err=screenshot.save_png("res://build/novagrid-real-glass-fx.png")
 if err!=OK:
  printerr("Unable to capture live particle effects: ",err)
  quit(1)
  return
 app.queue_free()
 await process_frame
 await process_frame
 print("REAL GODOT SCREENSHOTS SAVED")
 quit(0)
