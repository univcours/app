extends SceneTree
## Candy UI must remain an original, cached, drawn-at-runtime UI system.
## Checks do not alter player saves or require a phone/keyboard.
const CandyUI=preload("res://scripts/CandyUI.gd")
const MainScene=preload("res://scenes/Main.tscn")
const WelcomeScene=preload("res://scenes/Welcome.tscn")
var errors:Array[String]=[]

func check(value:bool,message:String) -> void:
 if not value:
  errors.append(message)
  printerr("CANDY UI FAIL: "+message)

func _initialize() -> void:
 call_deferred("_run")

func _run() -> void:
 CandyUI.reset_style_cache()
 var a:StyleBoxFlat=CandyUI._panel_style(Color("#5e2479"),Color("#ff92d3"),true)
 var b:StyleBoxFlat=CandyUI._panel_style(Color("#5e2479"),Color("#ff92d3"),true)
 check(a==b,"glossy panel StyleBox must be cached, not reallocated each frame")
 check(a.corner_radius_top_left>=20,"candy cards need rounded jelly silhouette")
 check(a.border_width_top>=3,"candy card edges need thick sugary outline")
 check(a.shadow_size>=8,"candy cards need physical visual depth")
 check(CandyUI.PINK.r>CandyUI.PINK.g,"candy pink accent must be saturated")
 # Confirm actual scenes can draw the same shared candy components.
 var home=WelcomeScene.instantiate()
 var game=MainScene.instantiate()
 game.saves_enabled=false
 root.add_child(home)
 await process_frame
 check(home.has_method("_glass") and home.has_method("_label"),"home has Candy UI text/cards")
 home.free()
 root.add_child(game)
 await process_frame
 check(game.has_method("_glass_panel") and game.has_method("_button") and game.has_method("_label"),
  "gameplay has Candy HUD, buttons and popup component")
 game.free()
 if errors.is_empty():
  print("ALL NOVAGRID CANDY UI TESTS PASSED")
  quit(0)
 else:
  quit(1)
