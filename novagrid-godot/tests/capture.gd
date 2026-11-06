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
 # Capture the actual GPU-rendered 3D bevelled mesh, not a painted mockup.
 var crystal:Texture2D = app.crystal3d.texture_for(3)
 if crystal == null:
  printerr("Real 3D crystal render target was not created.")
  quit(1)
  return
 var crystal_image:Image = crystal.get_image()
 if crystal_image == null or crystal_image.is_empty():
  printerr("Real 3D crystal texture is empty.")
  quit(1)
  return
 # Reject the exact transparent-3D regression seen during the first pass.
 var visible_pixels:int = 0
 for yy in range(0,crystal_image.get_height(),4):
  for xx in range(0,crystal_image.get_width(),4):
   if crystal_image.get_pixel(xx,yy).a > .25:
    visible_pixels += 1
 if visible_pixels < 250:
  printerr("Rendered 3D crystal is invisible: only %d visible sample pixels" % visible_pixels)
  quit(1)
  return
 err = crystal_image.save_png("res://build/novagrid-3d-crystal-proof.png")
 if err != OK:
  printerr("3D crystal proof cannot be saved: ",err)
  quit(1)
  return
 print("REAL 3D CRYSTAL RENDERED: ",crystal_image.get_width(),"x",crystal_image.get_height())
 print("REAL GODOT SCREENSHOTS SAVED")
 quit(0)
