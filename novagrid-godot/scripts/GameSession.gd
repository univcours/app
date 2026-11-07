extends Node
## Persistent settings shared by Welcome and both gameplay scenes.
## Separate from scores so restarting a game never resets audio choices.
const SETTINGS_PATH := "user://novagrid-audio-settings.cfg"
var start_mode:int=0
var sounds_enabled:bool=true
var music_enabled:bool=true

func _ready() -> void:
 load_audio_settings()

func load_audio_settings() -> void:
 var config:=ConfigFile.new()
 if config.load(SETTINGS_PATH)!=OK:
  return
 sounds_enabled=bool(config.get_value("audio","sounds",true))
 music_enabled=bool(config.get_value("audio","music",true))

func update_audio_settings(sounds:bool,music:bool) -> void:
 sounds_enabled=sounds
 music_enabled=music
 var config:=ConfigFile.new()
 config.set_value("audio","sounds",sounds_enabled)
 config.set_value("audio","music",music_enabled)
 var result:int=config.save(SETTINGS_PATH)
 if result!=OK:
  push_warning("NovaGrid audio settings could not be saved: %d" % result)
