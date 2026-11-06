extends Node
## Original procedural music and glassy UI sound effects. No copyrighted audio.
## PCM files are synthesized once at startup; sample playback is very cheap.
var fx_player: AudioStreamPlayer
var music_player: AudioStreamPlayer
var sounds: Dictionary = {}
var music_tracks: Dictionary = {}
var sounds_enabled := true
var music_enabled := true

func _ready() -> void:
 fx_player = AudioStreamPlayer.new()
 fx_player.volume_db = -8.0
 add_child(fx_player)
 music_player = AudioStreamPlayer.new()
 music_player.volume_db = -18.0
 add_child(music_player)
 sounds = {
  "tap": _tone(520.0,0.055,0.30,1.10),
  "pick": _tone(430.0,0.09,0.36,1.5),
  "place": _tone(275.0,0.15,0.53,1.1),
  "rotate": _tone(635.0,0.09,0.32,0.8),
  "invalid": _tone(145.0,0.13,0.36,1.6),
  "clear": _tone(720.0,0.24,0.59,1.35),
  "combo": _tone(980.0,0.37,0.71,1.9),
  "fever": _tone(1250.0,0.5,0.48,1.65),
  "lose": _tone(190.0,0.38,0.46,1.0)
 }
 music_tracks["puzzle"] = _song(false)
 music_tracks["falling"] = _song(true)

func _tone(freq:float,length:float,amplitude:float,glide:float) -> AudioStreamWAV:
 var rate := 22050
 var count := int(float(rate)*length)
 var bytes := PackedByteArray()
 bytes.resize(count*2)
 for i in count:
  var t := float(i)/float(rate)
  var progress := t/length
  var env := pow(1.0-progress,2.3)*minf(1.0,t*300.0)
  var phase := TAU*freq*t*(1.0+(glide-1.0)*0.25*progress)
  var signal := sin(phase)*0.76+sin(2.0*phase)*0.19+sin(3.0*phase)*0.05
  bytes.encode_s16(i*2,int(clampf(signal*amplitude*env,-1.0,1.0)*32760.0))
 var sample := AudioStreamWAV.new()
 sample.format = AudioStreamWAV.FORMAT_16_BITS
 sample.mix_rate = rate
 sample.stereo = false
 sample.data = bytes
 return sample

func _song(faster:bool) -> AudioStreamWAV:
 var rate := 16000
 var beat := 0.26 if faster else 0.38
 var bars := 32
 var count := int(float(rate)*beat*float(bars))
 var data := PackedByteArray()
 data.resize(count*2)
 var major: Array = [220.0,261.625,329.628,392.0,440.0,392.0,329.628,261.625]
 var minor: Array = [196.0,233.082,293.665,349.228,392.0,349.228,293.665,233.082]
 var notes: Array = minor if faster else major
 for i in count:
  var t := float(i)/float(rate)
  var step := int(t/beat)
  var fraction := fmod(t,beat)/beat
  var pitch: float = notes[step%notes.size()]
  var envelope := pow(1.0-fraction,1.5)*0.3
  var chord := sin(TAU*pitch*t)*envelope+sin(TAU*(pitch/2.0)*t)*0.08
  var high := sin(TAU*(pitch*2.0)*t)*pow(1.0-fraction,3.0)*0.08
  var kick := 0.18*sin(TAU*(52.0-20.0*fraction)*t)*exp(-fraction*20.0) if step%4==0 else 0.0
  var sample: float = clampf((chord+high+kick)*0.4,-1.0,1.0)
  data.encode_s16(i*2,int(sample*32760.0))
 var wav := AudioStreamWAV.new()
 wav.format = AudioStreamWAV.FORMAT_16_BITS
 wav.mix_rate = rate
 wav.stereo = false
 wav.data = data
 wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
 wav.loop_begin = 0
 wav.loop_end = count
 return wav

func effect(kind:String) -> void:
 if not sounds_enabled or not sounds.has(kind):
  return
 fx_player.stream = sounds[kind]
 fx_player.play()

func select_music(mode:String) -> void:
 if not music_enabled:
  music_player.stop()
  return
 music_player.stream = music_tracks.get(mode,music_tracks.get("puzzle"))
 music_player.play()

func toggle_music(mode:String) -> void:
 music_enabled = not music_enabled
 select_music(mode)

func toggle_sound() -> void:
 sounds_enabled = not sounds_enabled
