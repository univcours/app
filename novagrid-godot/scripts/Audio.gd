extends Node
## NovaGrid Neon Audio v2: entirely new, original premium synth production.
## No external copyrighted tracks, sound packs, or network services.
const RATE:int=32000
const AUDIO_SETTINGS_PATH:String="user://novagrid-audio.cfg"
static var shared_samples:Dictionary={}
var fx_players:Array[AudioStreamPlayer]=[]
var fx_cursor:int=0
var music_player:AudioStreamPlayer
var sounds:Dictionary={}
var music_tracks:Dictionary={}
var sounds_enabled:bool=true
var music_enabled:bool=true
var current_mode:String="menu"

func _ready()->void:
 var settings:=ConfigFile.new()
 if settings.load(AUDIO_SETTINGS_PATH)==OK:
  sounds_enabled=bool(settings.get_value("audio","effects",true))
  music_enabled=bool(settings.get_value("audio","music",true))
 for i in 8:
  var player:=AudioStreamPlayer.new()
  player.name="NovaNeonFX%02d"%i
  player.volume_db=-11.5
  add_child(player)
  fx_players.append(player)
 music_player=AudioStreamPlayer.new()
 music_player.name="NovaNeonOriginalScore"
 music_player.volume_db=-20.0
 add_child(music_player)
 if not shared_samples.is_empty():
  sounds=shared_samples.get("effects",{}).duplicate()
  music_tracks=shared_samples.get("music",{}).duplicate()
  return
 # Distinct synthesized timbres, pitch envelopes, harmonic spectra and tails.
 sounds={
  "tap":_tone(730.0,.094,.26,1.33,.08),
  "confirm":_tone(925.0,.20,.38,1.52,.06),
  "cancel":_tone(420.0,.15,.27,.67,.09),
  "popup":_tone(555.0,.25,.34,1.82,.12),
  "close":_tone(670.0,.14,.25,.71,.08),
  "toggle":_tone(1120.0,.11,.28,1.36,.02),
  "pick":_tone(410.0,.15,.39,1.56,.05),
  "place":_tone(235.0,.26,.57,.65,.21),
  "rotate":_tone(690.0,.12,.36,1.27,.08),
  "invalid":_tone(195.0,.22,.39,.58,.36),
  "clear":_tone(950.0,.35,.62,1.69,.21),
  "combo":_tone(1090.0,.56,.76,1.96,.19),
  "fever":_tone(1390.0,.66,.74,1.62,.24),
  "reward":_tone(1160.0,.42,.63,1.74,.10),
  "victory":_tone(800.0,.85,.70,2.08,.16),
  "unlock":_tone(640.0,.59,.57,1.88,.08),
  "lose":_tone(290.0,.60,.48,.40,.24),
  "falling_move":_tone(335.0,.048,.16,.92,.028),
  "falling_rotate":_tone(760.0,.11,.31,1.24,.085),
  "falling_soft":_tone(215.0,.055,.17,.82,.055),
  "falling_lock":_tone(125.0,.27,.64,.60,.40),
  "drag":_tone(380.0,.065,.14,1.04,.02)
 }
 sounds["puzzle_shatter"]=_shards(1000.0,.45,.67,false)
 sounds["puzzle_big_shatter"]=_shards(1350.0,.65,.84,false)
 sounds["falling_shatter"]=_shards(485.0,.48,.85,true)
 sounds["falling_big_shatter"]=_shards(610.0,.69,.97,true)
 music_tracks["menu"]=_score("menu")
 music_tracks["puzzle"]=_score("puzzle")
 music_tracks["falling"]=_score("falling")
 # Settings keeps the mellow menu mix without a music restart.
 music_tracks["settings"]=music_tracks["menu"]
 shared_samples={"effects":sounds.duplicate(),"music":music_tracks.duplicate()}

func _wav(pcm:PackedByteArray,loop:bool=false)->AudioStreamWAV:
 var wav:=AudioStreamWAV.new()
 wav.format=AudioStreamWAV.FORMAT_16_BITS
 wav.mix_rate=RATE
 wav.stereo=false
 wav.data=pcm
 if loop:
  wav.loop_mode=AudioStreamWAV.LOOP_FORWARD
  wav.loop_begin=0
  wav.loop_end=int(pcm.size()/2)
 return wav

func _tone(hz:float,length:float,power:float,glide:float,grain:float)->AudioStreamWAV:
 var frames:int=maxi(128,int(RATE*length))
 var pcm:=PackedByteArray()
 pcm.resize(frames*2)
 for i in frames:
  var t:float=float(i)/RATE
  var u:float=clampf(t/length,0.0,1.0)
  # Integrating the frequency sweep avoids discontinuous sine phase artifacts.
  var phase:float=TAU*hz*(t+.5*(glide-1.0)*t*u)
  var envelope:float=pow(maxf(0.0,1.0-u),1.45)*minf(1.0,t*1300.0)
  var glass:float=sin(phase)*.64+sin(phase*2.011)*.21+sin(phase*3.037)*.11
  var bell:float=sin(phase*4.071)*.055*exp(-u*8.0)
  var strike:float=sin(t*TAU*hz*7.0)*.27*exp(-t*42.0)
  var grit:float=(sin(i*2.137)+sin(i*4.193)*.46)*grain*exp(-u*11.0)
  var sub:float=sin(TAU*hz*.501*t)*.10*exp(-u*4.8)
  var value:float=(glass+bell+strike+grit+sub)*envelope*power
  value=value/(1.0+absf(value)*.47)
  pcm.encode_s16(i*2,int(clampf(value,-1,1)*32760))
 return _wav(pcm)

func _shards(hz:float,length:float,power:float,heavy:bool)->AudioStreamWAV:
 var frames:int=maxi(256,int(RATE*length))
 var pcm:=PackedByteArray()
 pcm.resize(frames*2)
 var random:=RandomNumberGenerator.new()
 random.seed=76631 if heavy else 38701
 var pitches:Array[float]=[]
 var offsets:Array[float]=[]
 for i in 18:
  pitches.append(hz*random.randf_range(.63,3.9))
  offsets.append(random.randf_range(0,.11))
 for i in frames:
  var t:float=float(i)/RATE
  var u:float=t/length
  var impact:float=sin(TAU*(94.0 if heavy else 209.0)*t)*exp(-t*(20 if heavy else 43))*.52
  var crackle:float=(sin(i*2.47)+sin(i*5.19)*.6)*exp(-t*14.0)*.13
  var sparkle:float=0.0
  for n in pitches.size():
   var local:float=t-offsets[n]
   if local>=0:
    sparkle+=sin(TAU*pitches[n]*local)*exp(-local*(19.0+(n%6)*3.0))
  var fade:float=pow(maxf(0.0,1.0-u),.50)
  var value:float=(impact+crackle+sparkle*.057)*power*fade
  value=value/(1.0+absf(value)*.56)
  pcm.encode_s16(i*2,int(clampf(value,-1,1)*32760))
 return _wav(pcm)

func _score(kind:String)->AudioStreamWAV:
 # Three original and deliberately distinct loops: starfield ambience,
 # crystal strategy, and fast falling-block electronic pulse.
 var tempo:float=.52 if kind=="menu" else .38 if kind=="puzzle" else .30
 var steps:int=24 if kind=="menu" else 32
 var length:float=tempo*steps
 var frames:int=int(RATE*length)
 var pcm:=PackedByteArray()
 pcm.resize(frames*2)
 var roots:Array=[174.61,155.56,146.83,164.81] if kind=="menu" else (
  [220.0,196.0,174.61,196.0] if kind=="puzzle" else
  [174.61,164.81,146.83,155.56])
 var arp:Array[int]=[0,2,1,3,1,2,0,1]
 for i in frames:
  var t:float=float(i)/RATE
  var beat:int=int(t/tempo)
  var tick:float=fposmod(t,tempo)
  var unit:float=tick/tempo
  var root:float=roots[(beat/4)%roots.size()]
  var high:float=root*(2.0 if arp[beat%8]==1 else 1.5 if arp[beat%8]==2 else 3.0 if arp[beat%8]==3 else 1.0)
  var shimmer:float=sin(TAU*high*t+sin(t*1.9)*.02)
  var chime:float=(shimmer+sin(TAU*high*2.008*t)*.22)*pow(1.0-unit,1.9)
  var pad:float=(sin(TAU*root*.5*t)+sin(TAU*root*.752*t)*.36
   +sin(TAU*root*.998*t)*.23)*(.045 if kind=="menu" else .061)
  pad*=.85+.15*sin(TAU*t/(tempo*8))
  var bass:float=sin(TAU*root*.25*t)*pow(1.0-unit,1.35)*(
   .075 if kind=="menu" else .115)
  var rhythm:float=0.0
  if kind!="menu":
   var kick:float=sin(TAU*(72*tick-24*tick*tick))*.25*exp(-unit*13)
   var snare:float=0.0
   if beat%4==1 or beat%4==3:
    snare=(sin(i*2.313)+sin(i*3.117)*.4)*exp(-unit*20)*.12
   var hats:float=sin(i*2.77+beat*9.1)*exp(-fposmod(unit*2,1)*27)*.034
   rhythm=kick+snare+hats
  var lead:float=chime*(.09 if kind=="menu" else .16 if kind=="puzzle" else .20)
  var soft:float=pad+bass+lead+rhythm
  # Seamless loop crossfade near endpoints, no clipped click on the repeat.
  var seam:float=minf(1.0,minf(t,length-t)*15.0)
  var value:float=soft*seam
  value=value/(1.0+absf(value)*.72)
  pcm.encode_s16(i*2,int(clampf(value,-1,1)*32760))
 return _wav(pcm,true)

func effect_for(mode:String,kind:String)->void:
 var key:String=mode+"_"+kind
 effect(key if sounds.has(key) else kind)

func effect(kind:String)->void:
 if not sounds_enabled or not sounds.has(kind) or fx_players.is_empty():return
 var player:AudioStreamPlayer=fx_players[fx_cursor]
 fx_cursor=(fx_cursor+1)%fx_players.size()
 player.stream=sounds[kind]
 player.pitch_scale=1.0+randf_range(-.018,.018)
 player.play()

func select_music(mode:String)->void:
 current_mode=mode
 if not music_enabled:
  music_player.stop()
  return
 var track:AudioStream=music_tracks.get(mode,music_tracks["menu"])
 if music_player.stream==track and music_player.playing:return
 music_player.stream=track
 music_player.play()

func toggle_music(mode:String)->void:
 music_enabled=not music_enabled
 select_music(mode)
 _save_preferences()

func toggle_sound()->void:
 sounds_enabled=not sounds_enabled
 if sounds_enabled:effect("toggle")
 _save_preferences()

func _save_preferences()->void:
 var settings:=ConfigFile.new()
 settings.set_value("audio","effects",sounds_enabled)
 settings.set_value("audio","music",music_enabled)
 if settings.save(AUDIO_SETTINGS_PATH)!=OK:
  push_warning("NovaGrid audio preferences could not be saved")
