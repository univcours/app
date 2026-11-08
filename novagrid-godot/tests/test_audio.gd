extends SceneTree
## Native audio regression: scene transitions retain user's preferences, while
## reusable original music/sound samples do not regenerate on every home/game hop.
const Audio = preload("res://scripts/Audio.gd")
var failures:Array[String]=[]

func verify(condition:bool,description:String)->void:
 if not condition:
  failures.append(description)
  printerr("AUDIO FAIL: "+description)

func _initialize()->void:
 call_deferred("_run")

func _run()->void:
 var first=Audio.new()
 root.add_child(first)
 verify(first.fx_players.size()==8,"eight overlapping, polyphonic FX channels exist")
 verify(first.music_tracks.size()==4,"menu, classic, blockfall and settings music routing exists")
 verify(first.sounds.has("puzzle_shatter") and first.sounds.has("falling_shatter"),
  "separate puzzle and falling effects exist")
 verify(first.music_tracks["menu"]!=first.music_tracks["puzzle"] and first.music_tracks["puzzle"]!=first.music_tracks["falling"],
  "menu, puzzle and blockfall have distinct original tracks")
 verify(first.sounds.has("victory") and first.sounds.has("unlock") and first.sounds.has("popup"),
  "victory, unlock and premium UI FX are real samples")
 verify((first.sounds["tap"] as AudioStreamWAV).mix_rate==32000,
  "all premium sounds use the upgraded 32kHz synthesis rate")
 var original_sound:bool=first.sounds_enabled
 var original_music:bool=first.music_enabled
 first.toggle_sound()
 first.toggle_music("puzzle")
 var second=Audio.new()
 root.add_child(second)
 verify(second.sounds_enabled!=original_sound,"sound setting survives recreated Godot scene")
 verify(second.music_enabled!=original_music,"music setting survives recreated Godot scene")
 verify(first.sounds["place"]==second.sounds["place"],
  "second scene reuses the same cached WAV resource")
 verify(first.music_tracks["falling"]==second.music_tracks["falling"],
  "second scene reuses soundtrack instead of doing expensive synthesis")
 second.toggle_sound()
 second.toggle_music("falling")
 verify(second.sounds_enabled==original_sound and second.music_enabled==original_music,
  "previous user preference restored after regression test")
 first.queue_free()
 second.queue_free()
 await process_frame
 await process_frame
 if failures.is_empty():
  print("ALL NOVAGRID AUDIO PERSISTENCE AND CACHE TESTS PASSED")
  quit(0)
 else:
  printerr("%d NOVAGRID AUDIO FAILURES"%failures.size())
  quit(1)
