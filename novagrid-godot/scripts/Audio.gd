extends Node
## Original procedural electronic soundtrack / layered audio. Created locally at
## runtime: no licensed files, copyrighted melodies, external APIs or downloads.
const RATE := 22050
var fx_players: Array[AudioStreamPlayer] = []
var fx_cursor := 0
var music_player: AudioStreamPlayer
var sounds: Dictionary = {}
var music_tracks: Dictionary = {}
var sounds_enabled := true
var music_enabled := true
var current_mode := "puzzle"

func _ready() -> void:
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
 music_tracks["puzzle"] = _compose(false)
 music_tracks["falling"] = _compose(true)

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

func _compose(fast:bool) -> AudioStreamWAV:
 # Composed from original minor-key progression, electronic arpeggiated
 # chords, moving subbass, gated pads, kick, clap/snare and crisp hi-hats.
 # 16 bars looping perfectly at 4 beats per bar.
 var beat := .31 if fast else .37
 var steps := 64
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

func toggle_sound() -> void:
 sounds_enabled=not sounds_enabled
