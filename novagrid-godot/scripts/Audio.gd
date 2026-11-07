extends Node
## Original procedural electronic soundtrack / layered audio. Created locally at
## runtime: no licensed files, copyrighted melodies, external APIs or downloads.
const RATE := 22050
const AUDIO_SETTINGS_PATH := "user://novagrid-audio.cfg"
static var shared_samples:Dictionary = {}
var fx_players: Array[AudioStreamPlayer] = []
var fx_cursor := 0
var music_player: AudioStreamPlayer
var sounds: Dictionary = {}
var music_tracks: Dictionary = {}
var sounds_enabled := true
var music_enabled := true
var current_mode := "puzzle"

func _ready() -> void:
 var settings:=ConfigFile.new()
 if settings.load(AUDIO_SETTINGS_PATH)==OK:
  sounds_enabled=bool(settings.get_value("audio","effects",true))
  music_enabled=bool(settings.get_value("audio","music",true))
 for i in 6:
  var player := AudioStreamPlayer.new()
  player.name = "GlassFX%02d" % i
  player.volume_db = -10.0
  add_child(player)
  fx_players.append(player)
 music_player = AudioStreamPlayer.new()
 music_player.name = "OriginalGalaxyMusic"
 music_player.volume_db = -16.0
 add_child(music_player)
 if not shared_samples.is_empty():
  sounds=shared_samples.get("effects",{}).duplicate()
  music_tracks=shared_samples.get("music",{}).duplicate()
  return
 sounds = {
  "tap": _make_effect(620.0,.076,.30,1.15,.12),
  "pick": _make_effect(495.0,.11,.31,1.72,.04),
  "place": _make_effect(255.0,.21,.55,.61,.17),
  "rotate": _make_effect(725.0,.085,.35,1.18,.05),
  "invalid": _make_effect(174.0,.17,.39,.72,.28),
  "clear": _make_effect(880.0,.31,.65,1.65,.22),
  "combo": _make_effect(1120.0,.47,.72,2.12,.27),
  "fever": _make_effect(1250.0,.61,.70,1.7,.26),
  "lose": _make_effect(240.0,.48,.46,.49,.18)
 }
 # Two intentionally distinct modes: delicate crystal chimes vs hard arcade impacts.
 sounds["puzzle_shatter"]=_shatter(985.0,.36,.62,false)
 sounds["puzzle_big_shatter"]=_shatter(1290.0,.52,.74,false)
 sounds["falling_move"]=_make_effect(325.0,.035,.20,.95,.025)
 sounds["falling_rotate"]=_make_effect(790.0,.075,.28,.82,.12)
 sounds["falling_soft"]=_make_effect(205.0,.05,.19,.75,.11)
 sounds["falling_lock"]=_make_effect(135.0,.19,.62,.68,.37)
 sounds["falling_shatter"]=_shatter(445.0,.43,.90,true)
 sounds["falling_big_shatter"]=_shatter(610.0,.60,.95,true)
 music_tracks["puzzle"] = _compose(false)
 music_tracks["falling"] = _compose(true)
 shared_samples={"effects":sounds.duplicate(),"music":music_tracks.duplicate()}

func _make_effect(hz:float,duration:float,gain:float,glide:float,noise:float) -> AudioStreamWAV:
 var count := int(float(RATE)*duration)
 var buffer := PackedByteArray()
 buffer.resize(count*2)
 for i in count:
  var t := float(i)/float(RATE)
  var ratio := t/duration
  var envelope := pow(maxf(0.0,1.0-ratio),1.75)*minf(1.0,t*420.0)
  var pitch := hz*(1.0+(glide-1.0)*ratio)
  var wobble := sin(t*28.0)*.005
  var phase := TAU*pitch*t*(1.0+wobble)
  var harmonic := sin(phase)*.72+sin(phase*2.01)*.20+sin(phase*3.98)*.08
  var dust := sin(t*18437.0+sin(t*36337.0)*1.3)*noise
  var shimmer := sin(phase*4.0)*.09*pow(1.0-ratio,2.3)
  var sample_value := (harmonic+shimmer+dust)*envelope*gain
  buffer.encode_s16(i*2,int(clampf(sample_value,-1.0,1.0)*32760.0))
 var wav := AudioStreamWAV.new()
 wav.format=AudioStreamWAV.FORMAT_16_BITS
 wav.mix_rate=RATE
 wav.stereo=false
 wav.data=buffer
 return wav

func _shatter(hz:float,length:float,power:float,heavy:bool) -> AudioStreamWAV:
 # Layered original impact transient, broadband brittle crack, dozens of
 # randomized high-pitch shard resonances and decaying cosmic glass debris.
 var count:int=int(float(RATE)*length)
 var pcm:=PackedByteArray()
 pcm.resize(count*2)
 var gen:=RandomNumberGenerator.new()
 gen.seed=7331 if heavy else 2998
 var shard_rates: Array=[]
 var shard_offsets: Array=[]
 for i in 15:
  shard_rates.append(hz*gen.randf_range(.74,3.6))
  shard_offsets.append(gen.randf_range(0.0,.12))
 for i in count:
  var t:float=float(i)/float(RATE)
  var p:float=t/length
  var initial_impact:float=sin(TAU*(78.0 if heavy else 192.0)*t)*exp(-t*(22.0 if heavy else 39.0))
  var breaking:float=sin(t*23971.0+sin(t*36203.0)*2.3)*exp(-t*10.0)
  var shards:float=0.0
  for j in shard_rates.size():
   var local_t:float=t-float(shard_offsets[j])
   if local_t>=0.0:
    var note:float=float(shard_rates[j])
    var phase:float=TAU*note*local_t
    shards+=sin(phase)*exp(-local_t*(17.0+float(j%7)*3.0))
  var grit:float=sin(t*11887.0)*sin(t*6743.0)*pow(1.0-p,3.0)
  var sample_value:float=(initial_impact*.49+breaking*.20+shards*.072+grit*.10)*power
  sample_value=sample_value/(1.0+absf(sample_value)*.38)
  pcm.encode_s16(i*2,int(clampf(sample_value,-1.0,1.0)*32760.0))
 var wav:=AudioStreamWAV.new()
 wav.format=AudioStreamWAV.FORMAT_16_BITS
 wav.mix_rate=RATE
 wav.stereo=false
 wav.data=pcm
 return wav

func effect_for(mode:String,kind:String) -> void:
 var key:String=mode+"_"+kind
 if not sounds.has(key):
  key=kind
 effect(key)

func _compose(fast:bool) -> AudioStreamWAV:
 # Composed from original minor-key progression, electronic arpeggiated
 # chords, moving subbass, gated pads, kick, clap/snare and crisp hi-hats.
 # 16 bars looping perfectly at 4 beats per bar.
 var beat := .31 if fast else .37
 var steps := 32
 var count := int(float(RATE)*beat*float(steps))
 var data := PackedByteArray()
 data.resize(count*2)
 var roots: Array = [196.0,174.61,155.56,174.61] if fast else [220.0,196.0,174.61,196.0]
 var arp_order := [0,2,1,3,1,2,0,2]
 for i in count:
  var t := float(i)/float(RATE)
  var beat_id := int(t/beat)
  var bar: int = int(beat_id/4)
  var phase:float = fmod(t,beat)
  var frac:float = phase/beat
  var root_hz:float = roots[bar%4]
  var chord:float = root_hz*1.5 if bar%4!=2 else root_hz*1.498
  var note:float = root_hz
  match arp_order[beat_id%8]:
   1: note=chord
   2: note=root_hz*2.0
   3: note=root_hz*3.0
  var beat_envelope := pow(maxf(0.0,1.0-frac),1.7)
  # Fast, sparkling upper synth arpeggio.
  var lead:float = (sin(TAU*note*t)+sin(TAU*note*2.004*t)*.17)*beat_envelope*.16
  # Four voice warm detuned cosmic pad, gated softly between beats.
  var pad:float=(sin(TAU*(root_hz/2.0)*t)+sin(TAU*(root_hz*.752)*t)*.42+sin(TAU*(chord*.5)*t)*.48)*.064
  pad *= .62+.30*sin(TAU*(1.0/(beat*8.0))*t)
  # Rounded sidechained subbass; strikes at each even beat.
  var bass_env:float = pow(maxf(0.0,1.0-frac),1.4)
  var bass:float = sin(TAU*(root_hz*.5)*t)*bass_env*.18
  # Four-on-the-floor 54Hz kick with falling pitch and exponential decay.
  var kick:float = sin(TAU*(61.0*phase-27.0*phase*phase))*.38*exp(-frac*13.0)
  # Backbeat clap/snare noise on beats two and four.
  var snare:float = 0.0
  if beat_id%4==1 or beat_id%4==3:
   snare = sin(float(i)*2.297+sin(float(i)*.641))*exp(-frac*22.0)*.16
  # Constant 8th-note hi-hat tick.
  var sub:float=fmod(phase,beat*.5)/(beat*.5)
  var hat:float=sin(float(i)*2.712+float(beat_id)*17.0)*exp(-sub*35.0)*.045
  # Small syncopated upper fifth shines every fourth bar.
  var accent:float=sin(TAU*note*4.0*t)*.07*beat_envelope if beat_id%8==7 else 0.0
  var sidechain:float=1.0-.25*exp(-frac*18.0)
  var mix_value:float=(lead+pad+bass+accent)*sidechain+kick+snare+hat
  # Soft saturation instead of hard clipping.
  mix_value=mix_value/(1.0+absf(mix_value)*.82)
  data.encode_s16(i*2,int(clampf(mix_value*.87,-1.0,1.0)*32760.0))
 var wav := AudioStreamWAV.new()
 wav.format=AudioStreamWAV.FORMAT_16_BITS
 wav.mix_rate=RATE
 wav.stereo=false
 wav.data=data
 wav.loop_mode=AudioStreamWAV.LOOP_FORWARD
 wav.loop_begin=0
 wav.loop_end=count
 return wav

func effect(kind:String) -> void:
 if not sounds_enabled or not sounds.has(kind) or fx_players.is_empty():
  return
 var player:AudioStreamPlayer=fx_players[fx_cursor]
 fx_cursor=(fx_cursor+1)%fx_players.size()
 player.stream=sounds[kind]
 player.play()

func select_music(mode:String) -> void:
 current_mode=mode
 if not music_enabled:
  music_player.stop()
  return
 music_player.stream=music_tracks.get(mode,music_tracks["puzzle"])
 music_player.play()

func toggle_music(mode:String) -> void:
 music_enabled=not music_enabled
 select_music(mode)
 _save_preferences()

func toggle_sound() -> void:
 sounds_enabled=not sounds_enabled
 _save_preferences()

func _save_preferences() -> void:
 var settings:=ConfigFile.new()
 settings.set_value("audio","effects",sounds_enabled)
 settings.set_value("audio","music",music_enabled)
 if settings.save(AUDIO_SETTINGS_PATH)!=OK:
  push_warning("NovaGrid audio preferences could not be saved")
