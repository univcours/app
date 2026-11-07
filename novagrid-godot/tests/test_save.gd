extends SceneTree
## Save crash-recovery integration test. All files live in an isolated
## test namespace; neither Play Store data nor real Godot preview progress
## can be modified by running QA from the editor.
const PREFIX="user://novagrid-qa-save-do-not-sync.json"
var failures:Array=[]

func check(ok:bool,label:String) -> void:
 if not ok:
  failures.append(label)
  printerr("SAVE RECOVERY FAIL: "+label)

func _initialize() -> void:
 call_deferred("_run")

func _clean_files() -> void:
 for suffix in ["",".tmp",".bak"]:
  var file_path:String=PREFIX+suffix
  if FileAccess.file_exists(file_path):
   DirAccess.remove_absolute(ProjectSettings.globalize_path(file_path))

func _run() -> void:
 _clean_files()
 var packed:PackedScene=load("res://scenes/Main.tscn")
 var app=packed.instantiate()
 app.saves_enabled=false # Disable actual user saves when the test scene enters.
 root.add_child(app)
 app.save_path=PREFIX
 app.saves_enabled=true
 app.puzzle.score=125
 app._save_game()
 check(not app._read_snapshot(PREFIX).is_empty(),"first snapshot saved")
 app.puzzle.score=250
 app._save_game()
 var backup:Dictionary=app._read_snapshot(PREFIX+".bak")
 check(not backup.is_empty(),"previous valid snapshot backed up")
 if not backup.is_empty():
  check(int(backup["puzzle"]["score"])==125,"backup contains previous real progress")
 var broken:FileAccess=FileAccess.open(PREFIX,FileAccess.WRITE)
 if broken!=null:
  broken.store_string("{truncated...")
  broken.flush()
  broken=null
 app.puzzle.score=999
 app._load_game()
 check(app.puzzle.score==125,"fallback restores previous verified backup after corruption")
 app.saves_enabled=false
 app.free()
 _clean_files()
 if failures.is_empty():
  print("ALL NOVAGRID SAVE RECOVERY TESTS PASSED")
  quit(0)
 else:
  quit(1)
