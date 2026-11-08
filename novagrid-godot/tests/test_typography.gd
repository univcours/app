extends SceneTree
## Font regression: the only fonts bundled and used in NovaGrid.
const Typography = preload("res://scripts/Typography.gd")
var failures:Array[String]=[]

func check(condition:bool,label:String) -> void:
 if not condition:
  failures.append(label)
  printerr("TYPOGRAPHY FAIL: "+label)

func _initialize() -> void:
 call_deferred("_run")

func _run() -> void:
 check(Typography.ORBITRON!=null,"Orbitron title typeface loaded")
 check(Typography.OXANIUM!=null,"Oxanium menu typeface loaded")
 check(Typography.INTER!=null,"Inter body typeface loaded")
 check(Typography.font_for("NovaGrid",59)==Typography.ORBITRON,"logo uses Orbitron")
 check(Typography.font_for("Classic",25)==Typography.OXANIUM,"mode uses Oxanium")
 check(Typography.font_for("Score",13)==Typography.INTER,"small HUD uses Inter")
 check(Typography.covers(Typography.INTER,"Réglages"),"Inter supports French accents")
 check(Typography.covers(Typography.OXANIUM,"Blockfall"),"Oxanium supports buttons")
 check(Typography.covers(Typography.ORBITRON,"NovaGrid"),"Orbitron supports logo")
 for path in ["res://assets/fonts/Orbitron.ttf","res://assets/fonts/Oxanium.ttf",
   "res://assets/fonts/Inter.ttf","res://assets/fonts/OFL-Orbitron.txt",
   "res://assets/fonts/OFL-Oxanium.txt","res://assets/fonts/OFL-Inter.txt"]:
  check(FileAccess.file_exists(path),"required font or OFL license exists: "+path)
 var gdpaths:Array=["res://scripts/Main.gd","res://scripts/Welcome.gd"]
 for path in gdpaths:
  var file:=FileAccess.open(path,FileAccess.READ)
  check(file!=null,"can read "+path)
  if file==null: continue
  var source:String=file.get_as_text()
  check(not source.contains("ThemeDB.fallback_font"),"no Godot default font in "+path)
  check(not source.contains("draw_string(font,"),"no direct default text drawing in "+path)
  check(source.contains("Typography.draw_neon(self,"),"rendered text uses approved fonts in "+path)
  check(source.contains('preload("res://scripts/Typography.gd")'),"typography policy imported by "+path)
 var root_dir:=DirAccess.open("res://assets/fonts")
 check(root_dir!=null,"the exclusive font directory can be read")
 if root_dir!=null:
  var actual:Array[String]=[]
  for name in root_dir.get_files():
   if name.get_extension().to_lower() in ["ttf","otf"]:
    actual.append(name)
  actual.sort()
  check(actual==["Inter.ttf","Orbitron.ttf","Oxanium.ttf"],"exactly three fonts bundled")
 if failures.is_empty():
  print("ALL NOVAGRID EXCLUSIVE THREE-FONT TYPOGRAPHY TESTS PASSED")
  quit(0)
 else:
  printerr("%d EXCLUSIVE TYPOGRAPHY TEST FAILURES"%failures.size())
  quit(1)
