extends SceneTree
## Prevent resurrecting superseded native/texture-based legacy render paths.
var errors:Array[String]=[]

func check(ok:bool,description:String)->void:
 if not ok:
  errors.append(description)
  printerr("NEON CLEANUP ERROR: "+description)

func _initialize()->void:
 call_deferred("_run")

func _run()->void:
 var main_source:String=FileAccess.get_file_as_string("res://scripts/Main.gd")
 var welcome_source:String=FileAccess.get_file_as_string("res://scripts/Welcome.gd")
 var skin_source:String=FileAccess.get_file_as_string("res://scripts/NeonSkin.gd")
 check(main_source.length()>40000,"actual playable engine stays intact")
 check(welcome_source.length()>10000,"all native destination screens stay intact")
 check(skin_source.length()>4500,"shared detailed neon components available")
 for func_name in ["_legacy_layout","_neon_puzzle_layout","_draw_neon_puzzle_values","_draw_neon_settings","_reference_blockpuzzle_layout","_premium_numeric","_reference_puzzle_hud","_draw_reference_puzzle_progress","_reference_blockfall_layout","_reference_live_hud","_draw_reference_progress","_draw_header","_draw_tabs","_draw_clean_fall_well"]:
  check(not main_source.contains("func "+func_name+"("),
   "retired visual renderer stays removed: "+func_name)
 check(main_source.contains("NeonSkin.panel(self,") and
  welcome_source.contains("NeonSkin.mode_button(self,"),
  "game and launcher share one current neon design system")
 check(welcome_source.contains('NeonSkin.logo(self,'),
  "two-tone Orbitron wordmark remains the only live logo")
 check(main_source.contains("func _draw_cosmic() -> void:"),
  "new responsive live gameplay drawing stays active")
 if errors.is_empty():
  print("ALL NOVAGRID LEGACY UI REMOVAL REGRESSION TESTS PASSED")
  quit(0)
 else:
  quit(1)
