extends SceneTree
## Audio preferences must survive Galaxy -> Puzzle -> Blockfall -> Galaxy.
## Uses an isolated test file; never overwrites the owner's real preferences.
const SessionScript=preload("res://scripts/GameSession.gd")
const PREF_TEST_PATH="user://novagrid-audio-test-settings.cfg"
var failures:Array=[]

func check(value:bool,reason:String) -> void:
 if not value:
  failures.append(reason)
  printerr("AUDIO SETTINGS FAIL: "+reason)

func _initialize() -> void:
 call_deferred("_run")

func _run() -> void:
 var full_path:String=ProjectSettings.globalize_path(PREF_TEST_PATH)
 if FileAccess.file_exists(PREF_TEST_PATH):
  DirAccess.remove_absolute(full_path)
 var first=SessionScript.new()
 first.settings_path=PREF_TEST_PATH
 first.update_audio_settings(false,true)
 check(FileAccess.file_exists(PREF_TEST_PATH),"test preferences written to isolated disk file")
 var second=SessionScript.new()
 second.settings_path=PREF_TEST_PATH
 second.load_audio_settings()
 check(not second.sounds_enabled and second.music_enabled,"muted effects survive a fresh session")
 second.update_audio_settings(true,false)
 var third=SessionScript.new()
 third.settings_path=PREF_TEST_PATH
 third.load_audio_settings()
 check(third.sounds_enabled and not third.music_enabled,"muted music survives a fresh session")
 check(third.start_mode==0,"default launches Block Puzzle")
 first.free()
 second.free()
 third.free()
 if FileAccess.file_exists(PREF_TEST_PATH):
  DirAccess.remove_absolute(full_path)
 if failures.is_empty():
  print("ALL NOVAGRID AUDIO PERSISTENCE TESTS PASSED")
  quit(0)
 else:
  quit(1)
