extends SceneTree
## All Android launchers and Godot editor must use the approved cosmic icon.
var failures:Array[String]=[]

func check(condition:bool,description:String)->void:
 if not condition:
  failures.append(description)
  printerr("NOVAGRID ICON FAIL: "+description)

func _initialize()->void:
 call_deferred("_run")

func _run()->void:
 var assets:Dictionary={
  "res://assets/icons/NovaGrid-Godot-Icon-512.png":512,
  "res://assets/icons/NovaGrid-Android-Main-192.png":192,
  "res://assets/icons/NovaGrid-Android-Adaptive-Foreground-432.png":432,
  "res://assets/icons/NovaGrid-Android-Adaptive-Background-432.png":432,
  "res://assets/icons/NovaGrid-Android-Adaptive-Monochrome-432.png":432
 }
 for path in assets:
  var image:Image=Image.load_from_file(path)
  check(image!=null and not image.is_empty(),"icon image loads: "+path)
  if image!=null and not image.is_empty():
   check(image.get_width()==assets[path] and image.get_height()==assets[path],
    "expected square dimensions for "+path)
 var icon_path:String=String(ProjectSettings.get_setting("application/config/icon",""))
 check(icon_path=="res://assets/icons/NovaGrid-Godot-Icon-512.png",
  "Godot project and editor use approved icon, not legacy SVG")
 var cfg:String=FileAccess.get_file_as_string("res://export_presets.cfg")
 for name in [
  "launcher_icons/main_192x192",
  "launcher_icons/adaptive_foreground_432x432",
  "launcher_icons/adaptive_background_432x432",
  "launcher_icons/adaptive_monochrome_432x432"
 ]:
  check(cfg.contains(name+"="),"Android export explicitly specifies "+name)
 check(not cfg.contains('launcher_icons/main_192x192=""'),
  "Android cannot fall back to the old default icon")
 check(FileAccess.file_exists("res://assets/icons/NovaGrid-Godot-Icon-512.png"),
  "export_all_resources includes the icon artwork")
 if failures.is_empty():
  print("ALL NOVAGRID APP ICON TESTS PASSED")
  quit(0)
 else:
  printerr("%d ICON TEST FAILURES"%failures.size())
  quit(1)
