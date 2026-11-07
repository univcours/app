extends Node
## Persistent settings shared by Welcome and both gameplay scenes.
## Separate from scores so restarting a game never resets audio choices.
const AudioScript = preload("res://scripts/Audio.gd")
const SETTINGS_PATH := "user://novagrid-audio-settings.cfg"
var settings_path:String=SETTINGS_PATH
var audio:Node
var start_mode:int=0
var sounds_enabled:bool=true
var music_enabled:bool=true

func _ready() -> void:
 load_audio_settings()
 # One sound bank for the entire native app: switching scenes must not
 # regenerate two full procedural soundtracks on the Android CPU.
 audio=AudioScript.new()
 audio.name="NovaGridSharedAudio"
 add_child(audio)
 audio.sounds_enabled=sounds_enabled
 audio.music_enabled=music_enabled

func load_audio_settings() -> void:
 var config:=ConfigFile.new()
 if config.load(settings_path)!=OK:
  return
 sounds_enabled=bool(config.get_value("audio","sounds",true))
 music_enabled=bool(config.get_value("audio","music",true))

func update_audio_settings(sounds:bool,music:bool) -> void:
 sounds_enabled=sounds
 music_enabled=music
 var config:=ConfigFile.new()
 config.set_value("audio","sounds",sounds_enabled)
 config.set_value("audio","music",music_enabled)
 var result:int=config.save(settings_path)
 if result!=OK:
  push_warning("NovaGrid audio settings could not be saved: %d" % result)
