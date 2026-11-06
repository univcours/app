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
 for n in 18:
  var played := false
  for slot in 3:
   if played:
    break
   var shape: Array = app.puzzle.tray[slot]
   if shape.is_empty():
    continue
   for y in 12:
    if played:
     break
    for x in 10:
     if app.puzzle.fits(shape,Vector2i(x,y)):
      app.puzzle.place(slot,Vector2i(x,y))
      played = true
      break
  if not played or app.puzzle.over:
   break
 await create_timer(.3).timeout
 var screenshot:Image = root.get_texture().get_image()
 var err:int = screenshot.save_png("res://build/novagrid-real-puzzle.png")
 if err!=OK:
  printerr("Unable to capture Block Puzzle: ",err)
  quit(1)
  return
 app.mode = 1
 for n in 11:
  if app.falling.over:
   break
  app.falling.move(-1 if n%2==0 else 1)
  app.falling.hard_drop()
 await create_timer(.3).timeout
 screenshot = root.get_texture().get_image()
 err = screenshot.save_png("res://build/novagrid-real-blockfall.png")
 if err!=OK:
  printerr("Unable to capture Blockfall: ",err)
  quit(1)
  return
 print("REAL GODOT SCREENSHOTS SAVED")
 quit(0)
