extends Node2D
## NovaGrid native Godot 4.5 game UI.
## Gameplay, glass blocks, drag/drop, visual FX, saves and sounds run on Godot.
const PuzzleScript = preload("res://scripts/Puzzle.gd")
const HintSolver = preload("res://scripts/HintSolver.gd")
const FallingScript = preload("res://scripts/Falling.gd")
const AudioScript = preload("res://scripts/Audio.gd")
const VisualsScript = preload("res://scripts/Visuals.gd")
const ProgressionScript = preload("res://scripts/Progression.gd")

const SaveStore = preload("res://scripts/SaveStore.gd")
const SafeArea = preload("res://scripts/SafeArea.gd")
const BannerDock = preload("res://scripts/BannerDock.gd")
const Campaign = preload("res://scripts/Campaign.gd")
const Typography = preload("res://scripts/Typography.gd")
const NeonSkin = preload("res://scripts/NeonSkin.gd")

const GEM_COLORS = [
 Color("#192850"), Color("#ff287f"), Color("#ffbe17"), Color("#13c7fa"),
 Color("#963aff"), Color("#11db60"), Color("#ff751c"), Color("#127bff")
]
const SKY = Color("#070923")
# User-approved 941x1672 reference art is an optional real Godot texture.
# The original procedural shader remains the safe fallback in source-only clones.
const EXACT_FALL_SKIN = "res://assets/skins/blockfall_playable_chrome.png"
const PUZZLE_COSMIC_SKIN = "res://assets/skins/blockpuzzle_cosmic_backdrop.png"
# Dedicated live 9x9 playable art matching the reference Blockfall chrome.
const EXACT_PUZZLE_CHROME = "res://assets/skins/blockpuzzle_playable_chrome.png"
# User-approved 941x1672 Block Puzzle reference, with sample blocks removed.
# The art retains the EXACT neon title, galaxy, glass interface and 3 tray frames.
const NEON_PUZZLE_SKIN = "res://assets/skins/neon_exact/neon_block_puzzle_empty_941x1672.png"
const NEON_CANVAS = Vector2(941.0,1672.0)
const NEON_GEM_PATHS = ["",
 "res://assets/skins/neon_exact/gem_1.png",
 "res://assets/skins/neon_exact/gem_2.png",
 "res://assets/skins/neon_exact/gem_3.png",
 "res://assets/skins/neon_exact/gem_4.png",
 "res://assets/skins/neon_exact/gem_5.png",
 "res://assets/skins/neon_exact/gem_6.png",
 "res://assets/skins/neon_exact/gem_7.png"]
const PUZZLE_CHROME_CANVAS = Vector2(941.0,2091.0)
const SKIN_CANVAS = Vector2(941.0,1672.0)
# Exact seven candy faces cut from the approved AI-generated reference.
# Each is a transparent native texture placed by the REAL game engine.
const REFERENCE_CANDY_PATHS = [
 "",
 "res://assets/skins/gems/candy_1_ruby.png",
 "res://assets/skins/gems/candy_2_gold.png",
 "res://assets/skins/gems/candy_3_turquoise.png",
 "res://assets/skins/gems/candy_4_grapes.png",
 "res://assets/skins/gems/candy_5_emerald.png",
 "res://assets/skins/gems/candy_6_citrus.png",
 "res://assets/skins/gems/candy_7_sapphire.png"
]
# Shared premium Cosmic Candy arcade palette used for BOTH live modes.
const GLOW_BLUE = Color("#39ebff")
const GLOW_PINK = Color("#ff6df1")
const GLOW_PURPLE = Color("#a55cff")
const GLOW_GOLD = Color("#ffe48a")
var entry:String="classic"
var stage:int=1
var campaign=Campaign.new()
var challenge_run:Dictionary={}
var classic_save:Dictionary={}
var challenge_won:bool=false
var settings_open:bool=false
var puzzle
var falling
var audio
var visuals
var progress
var gem_styles: Array = []
var panel_styles: Dictionary = {}
var board_tile_styles: Dictionary = {}
var mode := 0
var paused := false
var selected := -1
var active_hint:Dictionary = {}
var bomb_armed := false
var restart_confirm := false
var reward_offer_open := false
var reward_ad_in_progress := false
var reward_credit_given := false
var touching := false
var dragging := false
var pressed_at := Vector2.ZERO
var touch_at := Vector2.ZERO
var visual_pointer := Vector2.ZERO
var press_clock := 0.0
var horizontal_anchor := 0.0
var soft_clock := 0.0
var touch_moved := false
var falling_touch_valid := false
var fall_display := Vector2(3,0)
var fall_drawn_drops := -1
var fall_accum := 0.0
var save_clock := 0.0
var clock := 0.0
var banner_height := 0.0 # Dedicated ad dock, never part of gameplay safe rectangle.
var native_ads: Node = null
var skin_fall:Texture2D = null
var skin_puzzle:Texture2D = null
var skin_puzzle_chrome:Texture2D = null
var skin_neon_puzzle:Texture2D = null
var neon_gem_textures:Array[Texture2D]=[]
var exact_candy_textures:Array[Texture2D]=[]

func set_native_banner_height(px:float) -> void:
 # Logical dock height; set to zero on no-fill/consent denial.
 banner_height=maxf(0.0,px)
 queue_redraw()

func reserve_native_banner_pixels(physical_px:int) -> bool:
 # Reserve BEFORE requesting/showing the native banner to avoid one-frame
 # overlap. Reject unsupported tiny screens instead of hiding game controls.
 var view:Vector2=get_viewport_rect().size
 var native_window:Vector2=Vector2(DisplayServer.window_get_size())
 var safe:Rect2=SafeArea.content_rect(view)
 var needed:float=BannerDock.logical_reservation(float(physical_px),view,native_window)
 if not BannerDock.can_reserve(safe,needed):
  set_native_banner_height(0.0)
  return false
 set_native_banner_height(needed)
 return true

func _native_ad_dock_changed() -> void:
 if native_ads!=null and native_ads.has_method("refresh_banner_dock"):
  native_ads.call("refresh_banner_dock")
 queue_redraw()

func _draw_native_ad_dock(layout:Dictionary) -> void:
 # This solid background and neon separator are behind Android's native
 # AdView; no Godot button/board/popup can occupy this dedicated area.
 if banner_height<=0.0:return
 var safe_whole:Rect2=SafeArea.content_rect(layout["viewport"])
 var dock:Rect2=BannerDock.dock_rect(safe_whole,banner_height)
 draw_rect(dock,Color("#03091b"),true)
 draw_line(dock.position+Vector2(0,1),dock.position+Vector2(dock.size.x,1),
  Color("#10bde3",.42),4.0,true)
 draw_line(dock.position,dock.position+Vector2(dock.size.x,0),
  Color("#52eaff",.90),1.3,true)
var stars: Array = []
var fragments: Array = []
var shockwaves: Array = []
var headlines: Array = []
var flash := 0.0
var shake := 0.0

func _ready() -> void:
 get_tree().quit_on_go_back=false
 puzzle = PuzzleScript.new()
 falling = FallingScript.new()
 audio = AudioScript.new()
 add_child(audio)
 progress = ProgressionScript.new()
 visuals = VisualsScript.new()
 add_child(visuals)
 visuals.configure(GEM_COLORS)
 # All default screens are native responsive geometry, never flattened art.
 for gem in GEM_COLORS:
  var style := StyleBoxFlat.new()
  style.bg_color = gem.lightened(.10)
  style.border_color = gem.lightened(.62)
  style.set_corner_radius_all(5)
  style.set_border_width_all(1)
  style.shadow_color = Color(gem.r,gem.g,gem.b,.33)
  style.shadow_size = 3
  style.shadow_offset = Vector2(0,1)
  gem_styles.append(style)
 _load_game()
 visuals.set_theme(progress.active_theme)
 var gen := RandomNumberGenerator.new()
 gen.seed = 20261106
 for i in 110:
  stars.append({"x": gen.randf(), "y": gen.randf(),
   "radius": gen.randf_range(0.4,1.7), "phase": gen.randf_range(0,TAU)})
 var session:Node=get_node_or_null("/root/Session")
 if session!=null:
  mode=int(session.get("start_mode"))
  entry=String(session.get("entry"))
  stage=int(session.get("stage"))
 _start_challenge()
 audio.select_music("puzzle" if mode==0 else "falling")
 get_viewport().size_changed.connect(_native_ad_dock_changed)
 # The optional real AdMob Android bridge is installed before Gradle export.
 if OS.get_name()=="Android" and ResourceLoader.exists("res://ads/AdMobRuntime.gd"):
  var ad_script:Script=load("res://ads/AdMobRuntime.gd")
  if ad_script!=null:
   native_ads=ad_script.new()
   add_child(native_ads)
   native_ads.call("start",self)
 set_process(true)
 queue_redraw()

func _process(delta:float) -> void:
 clock += delta
 if falling!=null:
  var target:Vector2=Vector2(falling.active)
  if falling.drops!=fall_drawn_drops or mode!=1:
   fall_display=target
   fall_drawn_drops=falling.drops
  else:
   fall_display=fall_display.lerp(target,clampf(delta*20.0,0.0,1.0))
 visual_pointer=visual_pointer.lerp(touch_at,clampf(delta*19.0,0.0,1.0))
 if mode==1 and touching and falling_touch_valid and not paused and not falling.over and not falling.rescue_pending:
  if clock-press_clock>.24 and not touch_moved:
   soft_clock+=delta
   if soft_clock>=.075:
    soft_clock=0.0
    _fall_soft_drop(false)
 flash = maxf(0.0,flash-delta*2.1)
 shake = maxf(0.0,shake-delta*3.0)
 for idx in range(shockwaves.size()-1,-1,-1):
  var ring:Dictionary = shockwaves[idx]
  ring["age"] = float(ring["age"]) + delta
  if float(ring["age"]) >= float(ring["duration"]):
   shockwaves.remove_at(idx)
  else:
   shockwaves[idx] = ring
 for idx in range(headlines.size()-1,-1,-1):
  var heading:Dictionary = headlines[idx]
  heading["age"] = float(heading["age"]) + delta
  heading["pos"] = Vector2(heading["pos"]) - Vector2(0,delta*44.0)
  if float(heading["age"]) > .92:
   headlines.remove_at(idx)
  else:
   headlines[idx] = heading
 for idx in range(fragments.size()-1,-1,-1):
  var f: Dictionary = fragments[idx]
  f["life"] = float(f["life"])-delta
  f["pos"] = Vector2(f["pos"])+Vector2(f["speed"])*delta
  f["speed"] = Vector2(f["speed"])*(1.0-delta*1.1)+Vector2(0,delta*48.0)
  f["rotation"] = float(f["rotation"])+float(f["spin"])*delta
  if float(f["life"])<=0.0:
   fragments.remove_at(idx)
  else:
   fragments[idx] = f
 if mode==1 and not paused and not falling.over and not falling.rescue_pending:
  # Proper lock delay from the rebuilt Blockfall engine.
  if falling.advance_lock(delta):
   _fall_locked()
  fall_accum += delta
  if fall_accum >= falling.fall_interval():
   fall_accum = 0
   if falling.tick():
    _fall_locked()
 save_clock += delta
 if save_clock > 8:
  save_clock = 0
  _save_game()
 queue_redraw()

func _exit_tree() -> void:
 _save_game()

func _draw() -> void:
 _draw_cosmic()
 _draw_native_ad_dock(_layout())

func _neon_puzzle_frame(viewport:Vector2,h:float) -> Rect2:
 # Uniform scale = truly square cells and NO distortion of the approved art.
 var scale:float=minf(viewport.x/NEON_CANVAS.x,h/NEON_CANVAS.y)
 var size:Vector2=NEON_CANVAS*scale
 return Rect2(Vector2((viewport.x-size.x)*.5,(h-size.y)*.5),size)


func _puzzle_chrome_frame(viewport:Vector2,h:float) -> Rect2:
 # Uniform scale preserves square 9x9 cells, never stretches on tall/short phones.
 var scale:float=minf(viewport.x/PUZZLE_CHROME_CANVAS.x,
  h/PUZZLE_CHROME_CANVAS.y)
 var size:Vector2=PUZZLE_CHROME_CANVAS*scale
 return Rect2(Vector2((viewport.x-size.x)*.5,(h-size.y)*.5),size)


func _draw_sky(layout:Dictionary) -> void:
 var bounds:Vector2=layout["viewport"]
 # Real-time layered nebula accents behind playable board, NOT a static
 # screenshot. The galaxy shader continues animating underneath.
 var glows:Array=[
  {"p":Vector2(.02,.12),"r":142.0,"c":GLOW_PINK},
  {"p":Vector2(.90,.30),"r":175.0,"c":GLOW_BLUE},
  {"p":Vector2(.12,.82),"r":210.0,"c":GLOW_PURPLE},
  {"p":Vector2(.94,.95),"r":190.0,"c":GLOW_PINK}
 ]
 for item in glows:
  var normalized:Vector2=item["p"]
  var center:Vector2=Vector2(bounds.x*normalized.x,bounds.y*normalized.y)
  var hue:Color=item["c"]
  for step in 5:
   var radius:float=float(item["r"])*(1.0-float(step)*.14)
   draw_circle(center,radius,Color(hue.r,hue.g,hue.b,.014))
 _draw_cosmic_planet(Vector2(bounds.x*.035,73.0+sin(clock*.10)*5.0),
  32.0,Color("#9d36ff"),Color("#fe63ff"))
 _draw_cosmic_planet(Vector2(bounds.x*1.075,bounds.y*.76+cos(clock*.085)*7.0),
  74.0,Color("#2459e8"),Color("#7d49ff"))
 _draw_cosmic_planet(Vector2(bounds.x*.90,bounds.y*.23),
  18.0,Color("#ec3bc9"),Color("#ff9bea"))
 for item in stars:
  var x:float=float(item["x"])*bounds.x+sin(clock*.11+float(item["phase"]))*5.0
  var y:float=fposmod(float(item["y"])*bounds.y+clock*(2.0+float(item["radius"])*2.0),bounds.y)
  var radius:float=float(item["radius"])
  var brightness:float=.48+.36*sin(clock*.73+float(item["phase"]))
  var col:=Color(.85,.94,1.0,clampf(brightness,.12,.94))
  draw_circle(Vector2(x,y),radius,col)
  if radius>1.28:
   draw_line(Vector2(x-3.5,y),Vector2(x+3.5,y),Color(.57,.78,1.0,.35),.9,true)
   draw_line(Vector2(x,y-3.5),Vector2(x,y+3.5),Color(.88,.65,1.0,.31),.9,true)
 # Luminous moving galactic orbit, subtle enough behind the real gameplay.
 var previous:Vector2=Vector2.ZERO
 for i in 81:
  var angle:float=float(i)/80.0*TAU
  var point:Vector2=Vector2(bounds.x*.52+cos(angle)*bounds.x*.92,
   bounds.y*.50+sin(angle)*bounds.y*.23)
  if i>0:
   draw_line(previous,point,Color(.64,.37,1.0,.11),1.4,true)
  previous=point
 # Large corner glints, restrained so no player's tile looks highlighted.
 _sparkle(Vector2(bounds.x*.11,bounds.y*.16),GLOW_GOLD,5.0)
 _sparkle(Vector2(bounds.x*.91,bounds.y*.10),GLOW_BLUE,4.0)
 _sparkle(Vector2(bounds.x*.08,bounds.y*.91),GLOW_PINK,5.0)

func _draw_cosmic_planet(center:Vector2,radius:float,base:Color,light:Color) -> void:
 for glow in range(7,0,-1):
  var halo_radius:float=radius+float(glow)*7.0
  draw_circle(center,halo_radius,Color(light.r,light.g,light.b,.014))
 draw_circle(center,radius,Color(base.r*.18,base.g*.14,base.b*.28,.96))
 draw_circle(center+Vector2(-radius*.12,-radius*.18),radius*.78,
  Color(base.r,base.g,base.b,.54))
 draw_circle(center+Vector2(-radius*.3,-radius*.33),radius*.39,
  Color(light.r,light.g,light.b,.26))
 draw_arc(center,radius,0.0,TAU,64,Color(light.r,light.g,light.b,.83),1.5,true)
 var previous:=Vector2.ZERO
 for i in 73:
  var a:float=float(i)/72.0*TAU
  var ring:Vector2=Vector2(cos(a)*radius*1.68,sin(a)*radius*.36).rotated(-.32)
  var pt:Vector2=center+ring
  if i>0:
   draw_line(previous,pt,Color(light.r,light.g,light.b,.55),1.55,true)
  previous=pt

func _label(text:String,pos:Vector2,size:int=16,color:Color=Color.WHITE,
 alignment:HorizontalAlignment=HORIZONTAL_ALIGNMENT_LEFT,width:float=-1.0) -> void:
 Typography.draw_neon(self,text,pos,size,color,alignment,width)

func _sparkle(pos:Vector2,tint:Color,extent:float=5.0) -> void:
 draw_circle(pos,extent*1.8,Color(tint.r,tint.g,tint.b,.11))
 draw_line(pos-Vector2(extent*1.5,0),pos+Vector2(extent*1.5,0),
  Color(tint.r,tint.g,tint.b,.57),1.1,true)
 draw_line(pos-Vector2(0,extent*1.7),pos+Vector2(0,extent*1.7),
  Color(tint.r,tint.g,tint.b,.70),1.1,true)
 draw_circle(pos,maxf(1.1,extent*.25),Color("#ffffff"))


func _premium_title(message:String,at:Vector2,large:int,width:float,accent:Color) -> void:
 # Multi-pass additive-looking typography without bundling third-party fonts.
 _label(message,at+Vector2(1.8,3.0),large,
  Color(accent.r,accent.g,accent.b,.66),HORIZONTAL_ALIGNMENT_CENTER,width)
 _label(message,at+Vector2(-.9,-.8),large,
  Color("#a2ccff"),HORIZONTAL_ALIGNMENT_CENTER,width)
 _label(message,at,large,Color("#ffffff"),
  HORIZONTAL_ALIGNMENT_CENTER,width)


func _glass_panel(rect:Rect2,fill:Color=Color("#081337"),outline:Color=Color("#00ddff")) -> void:
 NeonSkin.panel(self,rect,outline,fill,18,Time.get_ticks_msec()*.001)

func _button(rect:Rect2,title:String,active:bool=false,small:bool=false) -> void:
 var hue:Color=GLOW_BLUE if active else GLOW_PINK
 NeonSkin.panel(self,rect,hue,Color("#081737"),15,Time.get_ticks_msec()*.001,active)
 var fontsize:int=12 if small else 17
 _label(title,Vector2(rect.position.x,rect.position.y+rect.size.y*.65),
  fontsize,Color("#f7fbff"),HORIZONTAL_ALIGNMENT_CENTER,rect.size.x)

func _draw_progress_hud(layout:Dictionary) -> void:
 # Premium rank ribbon anchored outside the playable cells and native ad dock.
 var rect:Rect2=layout["progress"]
 var y:float=rect.position.y
 _glass_panel(rect,Color("#081337"),GLOW_PINK)
 if rect.size.y>35.0:
  # Compact screens: rank, XP bar, mission are three separate rows.
  _label("LV %d · %s"%[progress.level,progress.rank_name()],
   rect.position+Vector2(9,14),11,Color("#f1fbff"))
  _label("★ %d · %dd streak"%[progress.stars,progress.streak],
   rect.position+Vector2(0,14),10,GLOW_GOLD,
   HORIZONTAL_ALIGNMENT_RIGHT,rect.size.x-9)
  var track:=Rect2(rect.position+Vector2(9,19),
   Vector2(rect.size.x-18,5))
  draw_rect(track,Color("#162a55"),true)
  draw_rect(Rect2(track.position,Vector2(track.size.x*progress.level_progress(),
   track.size.y)),GLOW_BLUE,true)
  var task:Dictionary=progress.next_mission()
  _label("%s %d/%d"%[task["label"],task["progress"],task["target"]],
   rect.position+Vector2(9,35),11,Color("#c5e9ff"),
   HORIZONTAL_ALIGNMENT_LEFT,rect.size.x-114)
  _label(progress.theme_name(),rect.position+Vector2(rect.size.x-116,35),10,
   Color("#a7d8ff"),HORIZONTAL_ALIGNMENT_RIGHT,106)
  return
 _label("✦ LV %d · %s" % [progress.level,progress.rank_name()],
  Vector2(rect.position.x+9,y+12),11,Color("#f0f9ff"))
 _label("★ %d  ·  %dd streak" % [progress.stars,progress.streak],
  Vector2(rect.position.x,y+12),10,GLOW_GOLD,
  HORIZONTAL_ALIGNMENT_RIGHT,rect.size.x-10)
 var track:=Rect2(rect.position+Vector2(9,16),Vector2(rect.size.x-18,4))
 draw_rect(track,Color("#152b61"),true)
 var fill:=Rect2(track.position,
  Vector2(track.size.x*progress.level_progress(),track.size.y))
 draw_rect(fill,GLOW_BLUE,true)
 draw_line(track.position,Vector2(track.end.x,track.position.y),
  Color("#ffffff",.45),1.0,true)
 var mission:Dictionary=progress.next_mission()
 _label("%s  %d/%d  ·  %s (TAP)" %
  [mission["label"],mission["progress"],mission["target"],progress.theme_name()],
  Vector2(rect.position.x+9,y+27),8,Color("#c3e9ff"))

func _draw_back_button(rect:Rect2) -> void:
 # Identical tactile blue-glass back button in both Puzzle and Blockfall.
 _glass_panel(rect,Color("#081737"),GLOW_BLUE)
 var center:Vector2=rect.get_center()+Vector2(0.0,1.0)
 var arm:float=maxf(4.0,minf(rect.size.x,rect.size.y)*.19)
 var stroke:float=maxf(2.0,minf(rect.size.x,rect.size.y)*.065)
 var pivot:=center+Vector2(-arm*.5,0.0)
 draw_line(pivot+Vector2(arm*.70,-arm),pivot,Color("#b6c9ff"),stroke+1.0,true)
 draw_line(pivot,pivot+Vector2(arm*.70,arm),Color("#b6c9ff"),stroke+1.0,true)
 draw_line(pivot+Vector2(arm*.65,-arm),pivot,Color.WHITE,stroke,true)
 draw_line(pivot,pivot+Vector2(arm*.65,arm),Color.WHITE,stroke,true)


func _gem(rect:Rect2,color_id:int,ghost:bool=false,moving:bool=false) -> void:
 # Animated Candy Glass in both game modes. Seven vivid base hues receive
 # a moving two-tone rim, gentle breath glow and specular highlights.
 if color_id<=0:return
 var tint:Color=GEM_COLORS[clampi(color_id,1,7)]
 var second:Color=GEM_COLORS[1+posmod(color_id+2,7)]
 var tile:Rect2=rect.grow(-maxf(.7,rect.size.x*.025))
 var phase:float=clock*3.6+tile.position.x*.037+tile.position.y*.043
 var pulse:float=.65+.25*sin(phase)
 var mixed:Color=tint.lerp(second,.12+.14*(.5+.5*sin(phase*.7)))
 if ghost:
  draw_rect(tile,Color(mixed.r,mixed.g,mixed.b,.14+.08*pulse),true)
  draw_rect(tile,mixed.lightened(.34),false,1.6)
  return
 var texture:Texture2D=visuals.get_gem_texture(color_id)
 if texture!=null:
  draw_texture_rect(texture,tile,false)
 else:
  draw_rect(tile,Color(tint.r,tint.g,tint.b,.82),true)
  draw_rect(tile.grow(-tile.size.x*.1),tint.lightened(.24),false,2)
 draw_rect(tile.grow(.75),Color(mixed.r,mixed.g,mixed.b,.36+.24*pulse),
  false,1.4 if not moving else 2.2)
 var sweep:float=fposmod(clock*.67+tile.position.x*.004+tile.position.y*.006,1.0)
 var x0:float=tile.position.x+3+sweep*tile.size.x*.55
 draw_line(Vector2(x0,tile.position.y+3),
  Vector2(minf(tile.end.x-3,x0+tile.size.x*.24),tile.position.y+3),
  Color(1,1,1,.32+.20*pulse),1.4,true)
 if moving and not visuals.reduced_effects:
  for radius in 2:
   draw_rect(tile.grow(2.4+radius*2.1),
    Color(mixed.r,mixed.g,mixed.b,.18/(radius+1)),false,2.1,true)
  draw_line(tile.position+Vector2(3,tile.size.y*.24),
   tile.position+Vector2(3,tile.size.y*.73),
   Color(second.r,second.g,second.b,.65*pulse),2.2,true)

func _board_back(board_rect:Rect2,cols:int,rows:int) -> float:
 # Identical luxury neon system in Puzzle and Blockfall, but each has its
 # own accent. Real 9x9 and 10x18 grids are left fully interactive.
 var accent:Color=GLOW_BLUE if mode==0 else GLOW_PINK
 var secondary:Color=GLOW_PINK if mode==0 else GLOW_BLUE
 var outer:=board_rect.grow(5.0)
 var breathe:float=.68+.20*sin(clock*1.45)
 draw_rect(outer.grow(10.0),Color(accent.r,accent.g,accent.b,.10*breathe),false,8.0)
 draw_rect(outer.grow(5.0),Color(secondary.r,secondary.g,secondary.b,.18*breathe),false,4.0)
 _glass_panel(outer,Color("#080c2c"),accent)
 draw_rect(board_rect,Color("#080e2c"),true)
 var cell:float=board_rect.size.x/float(cols)
 var cell_h:float=board_rect.size.y/float(rows)
 for y in rows:
  for x in cols:
   var rect:=Rect2(board_rect.position+Vector2(x*cell,y*cell_h),
    Vector2(cell,cell_h))
   var back:Color=Color("#0f1b43") if (x+y)%2==0 else Color("#0b1638")
   draw_rect(rect.grow(-.55),back,true)
   draw_rect(rect.grow(-.70),Color(.30,.31,.66,.27),false,.70)
 # Directional dual-color prism-edge highlights.
 draw_line(outer.position+Vector2(13,1),outer.position+Vector2(outer.size.x-13,1),
  GLOW_BLUE,2.6,true)
 draw_line(outer.position+Vector2(2,13),outer.position+Vector2(2,outer.size.y-13),
  Color(GLOW_PURPLE.r,GLOW_PURPLE.g,GLOW_PURPLE.b,.94),2.3,true)
 draw_line(outer.position+Vector2(13,outer.size.y-1),
  Vector2(outer.end.x-13,outer.end.y-1),GLOW_PINK,2.7,true)
 draw_line(Vector2(outer.end.x-2,outer.position.y+13),
  Vector2(outer.end.x-2,outer.end.y-13),GLOW_BLUE,2.3,true)
 for corner in [outer.position,Vector2(outer.end.x,outer.position.y),
  outer.end,Vector2(outer.position.x,outer.end.y)]:
  _sparkle(corner,secondary,4.4)
 return cell

func _draw_puzzle(layout:Dictionary) -> void:
 var board:Rect2=layout["board"]
 var neon:bool=skin_neon_puzzle!=null and float(layout["height"])>=650.0
 var reference:bool=neon or (skin_puzzle_chrome!=null and float(layout["height"])>=760.0)
 var cell:float=board.size.x/9.0 if reference else _board_back(board,9,9)
 var cell_y:float=board.size.y/9.0
 for y in 9:
  for x in 9:
   var id:int=int(puzzle.cells[y][x])
   if id>0:
    _gem(Rect2(board.position+Vector2(x*cell,y*cell_y),Vector2(cell,cell_y)),id)
 # The hint is a preview, never a move: only a deliberate tap places a piece.
 if not active_hint.is_empty() and selected==int(active_hint.get("slot",-1)) and not dragging:
  var hint_origin:Vector2i=active_hint.get("origin",Vector2i(-1,-1))
  var hinted_shape:Array=puzzle.tray[selected]
  if puzzle.fits(hinted_shape,hint_origin):
   var hinted_color:int=int(puzzle.tray_colors[selected])
   for point in hinted_shape:
    var target:Vector2i=hint_origin+point
    var hint_tile:=Rect2(board.position+Vector2(target.x*cell,target.y*cell_y),
     Vector2(cell,cell_y))
    _gem(hint_tile,hinted_color,true)
    draw_rect(hint_tile.grow(-2.5),GLOW_GOLD,false,2.4)
   _label("HINT  ·  TAP GOLD CELLS",board.position+Vector2(0,19),11,
    GLOW_GOLD,HORIZONTAL_ALIGNMENT_CENTER,board.size.x)
 if bomb_armed and board.has_point(touch_at):
  var target:=Vector2i(clampi(int((touch_at.x-board.position.x)/cell),0,8),
   clampi(int((touch_at.y-board.position.y)/cell_y),0,8))
  for yy in range(maxi(0,target.y-1),mini(9,target.y+2)):
   for xx in range(maxi(0,target.x-1),mini(9,target.x+2)):
    var tile:=Rect2(board.position+Vector2(xx*cell,yy*cell_y),
     Vector2(cell,cell_y))
    draw_rect(tile.grow(-1),
     Color(.99,.26,.79,.40 if puzzle.cells[yy][xx]>0 else .16),true)
    draw_rect(tile.grow(-1),GLOW_PINK,false,1.4)
 if selected>=0 and selected<puzzle.tray.size() and not puzzle.tray[selected].is_empty():
  var near:Vector2=touch_at-Vector2(0,52) if dragging else touch_at
  if board.has_point(near):
   var origin:Vector2i=_origin_from_position(near,dragging,board,puzzle.tray[selected])
   if puzzle.fits(puzzle.tray[selected],origin):
    var preview_color:int=int(puzzle.tray_colors[selected])
    for p in puzzle.tray[selected]:
     var q:Vector2i=origin+p
     _gem(Rect2(board.position+Vector2(q.x*cell,q.y*cell_y),
      Vector2(cell,cell_y)),preview_color,true)
 # Full-width play area: 3 touchable glass trays, not small inert artwork.
 var colors:Array=puzzle.tray_colors
 for i in 3:
  var tray_rect:Rect2=layout["tray"][i]
  var gem_id:int=int(colors[i])
  var highlight:Color=GEM_COLORS[gem_id]
  var active:bool=i==selected
  if not reference:
   _glass_panel(tray_rect,Color("#142151") if active else Color("#10183f"),
    GLOW_PINK if active else Color("#417bc7"))
  if reference and not neon:
   draw_rect(tray_rect.grow(-5.0),Color(.014,.026,.105,.48),true)
  if active:
   draw_rect(tray_rect.grow(2.0),Color(highlight.r,highlight.g,highlight.b,.84),false,2.6)
  var shape:Array=puzzle.tray[i]
  if shape.is_empty():
   continue
  var bounds:Vector2i=puzzle.shape_size(shape)
  var micro:float=minf((tray_rect.size.x-13.0)/float(bounds.x),
   (tray_rect.size.y-9.0)/float(bounds.y))
  micro=minf(micro,42.0)
  var offset:Vector2=tray_rect.position+(tray_rect.size-
   Vector2(micro*bounds.x,micro*bounds.y))*.5
  var lift:float=-1.5-1.5*sin(clock*6.0+float(i)) if active else 0.0
  for p in shape:
   _gem(Rect2(offset+Vector2(p.x*micro,p.y*micro+lift),
    Vector2(micro,micro)),gem_id,false,active)
 if not reference and layout["height"]>=760.0:
  _label("✦  DRAG CRYSTALS  ·  CLEAR LINES  ·  COMBO BLAST  ✦",
   Vector2(0,layout["height"]-117.0),10,Color("#c5f8ff"),
   HORIZONTAL_ALIGNMENT_CENTER,layout["viewport"].x)
 if dragging and selected>=0 and not puzzle.tray[selected].is_empty():
  var s:Array=puzzle.tray[selected]
  var shape_size:Vector2i=puzzle.shape_size(s)
  var left:Vector2=visual_pointer-Vector2(shape_size.x*cell*.5,shape_size.y*cell_y*.5+54)
  for p in s:
   _gem(Rect2(left+Vector2(p.x*cell,p.y*cell_y),
    Vector2(cell,cell_y)),int(colors[selected]),false,true)

func _draw_falling(layout:Dictionary) -> void:
 var board:Rect2=layout["board"]
 var reference:bool=skin_fall!=null and float(layout["height"])>=760.0
 # The restored approved illustration includes a clean neon 10x18 field.
 # Never draw a secondary checkerboard or double border over it.
 var cell:float=board.size.x/10.0 if reference else _board_back(board,10,18)
 var cell_h:float=board.size.y/18.0
 var ghost:Vector2i=Vector2i(falling.active.x,falling.ghost_row())
 for y in 18:
  for x in 10:
   var id:int=falling.cell_at(x,y)
   if id>0:
    _gem(Rect2(board.position+Vector2(x*cell,y*cell_h),
     Vector2(cell,cell_h)),id)
 # A pending rescue freezes the blocked piece until the earned explosion
 # frees the spawn. Do not render it on top of settled glass cells.
 if not falling.rescue_pending:
  for p in falling.piece:
   var pos:Vector2i=ghost+p
   if pos.y>=0 and pos.y<18 and falling.board[pos.y][pos.x]==0:
    _gem(Rect2(board.position+Vector2(pos.x*cell,pos.y*cell_h),
     Vector2(cell,cell_h)),falling.kind+1,true)
  for p in falling.piece:
   var pos:Vector2=fall_display+Vector2(p)
   if pos.y>=0 and pos.y<18:
    _gem(Rect2(board.position+Vector2(pos.x*cell,pos.y*cell_h),
     Vector2(cell,cell_h)),falling.kind+1,false,true)
 var next_rect:Rect2=layout["next"]
 var hold_rect:Rect2=layout["hold"]
 if reference:
  # NEXT was cleaned in the original artwork, retain its bright chrome.
  _draw_side_piece(next_rect,falling.next_kind)
  if falling.hold_kind>=0:
   _draw_side_piece(hold_rect,falling.hold_kind)
  if falling.hold_used:
   draw_rect(hold_rect.grow(-6.0),Color(.02,.03,.10,.42),true)
  return
 _label("✦ NEXT",Vector2(next_rect.position.x,next_rect.position.y-10),14,
  Color("#ffd3ff"),HORIZONTAL_ALIGNMENT_CENTER,next_rect.size.x)
 _glass_panel(next_rect,Color("#090f39"),GLOW_PINK)
 _draw_side_piece(next_rect,falling.next_kind)
 _label("✦ HOLD",Vector2(hold_rect.position.x,hold_rect.position.y-10),14,
  Color("#8ef5ff"),HORIZONTAL_ALIGNMENT_CENTER,hold_rect.size.x)
 _glass_panel(hold_rect,Color("#08143d"),GLOW_BLUE)
 if falling.hold_kind>=0:
  _draw_side_piece(hold_rect,falling.hold_kind)
 else:
  _sparkle(hold_rect.get_center(),GLOW_BLUE,8.0)
 if falling.hold_used:
  draw_rect(hold_rect.grow(-2.0),Color(.06,.09,.20,.43),true)
 var gap:float=minf(39.0,maxf(8.0,board.end.y-hold_rect.end.y-85.0))
 var combo:=Rect2(Vector2(next_rect.position.x,hold_rect.end.y+gap),
  Vector2(next_rect.size.x,85.0))
 _glass_panel(combo,Color("#420d60"),GLOW_PINK)
 _label("COMBO",Vector2(combo.position.x,combo.position.y+23),14,
  Color("#f5d5ff"),HORIZONTAL_ALIGNMENT_CENTER,combo.size.x)
 _label("x%d" % falling.combo,Vector2(combo.position.x+1,combo.position.y+68),
  29,Color("#c67842"),HORIZONTAL_ALIGNMENT_CENTER,combo.size.x)
 _label("x%d" % falling.combo,Vector2(combo.position.x,combo.position.y+66),
  29,GLOW_GOLD,HORIZONTAL_ALIGNMENT_CENTER,combo.size.x)
 _sparkle(combo.position+Vector2(combo.size.x*.27,32),GLOW_GOLD,3.0)
 _sparkle(combo.position+Vector2(combo.size.x*.73,32),GLOW_GOLD,3.0)
 if layout["height"]>=760.0:
  _label("SWIPE ↔ MOVE   ·   TAP ROTATE   ·   SWIPE ↓ DROP",
   Vector2(0,layout["height"]-117.0),9,
   Color("#fff2bd"),HORIZONTAL_ALIGNMENT_CENTER,layout["viewport"].x)

func _draw_side_piece(panel:Rect2,kind_id:int) -> void:
 if kind_id<0 or kind_id>=falling.FORMS.size():
  return
 var form:Array=falling.FORMS[kind_id]
 var max_x:int=0
 var max_y:int=0
 for p in form:
  max_x=maxi(max_x,int(p[0]))
  max_y=maxi(max_y,int(p[1]))
 var micro:float=minf((panel.size.x-9)/float(max_x+1),(panel.size.y-10)/float(max_y+1))
 micro=minf(micro,25.0)
 var start:Vector2=panel.position+(panel.size-Vector2(micro*(max_x+1),micro*(max_y+1)))*.5
 for p in form:
  _gem(Rect2(start+Vector2(int(p[0])*micro,int(p[1])*micro),Vector2(micro,micro)),kind_id+1)

func _draw_shockwaves() -> void:
 # Compact, transparent neon rings: never flood a playable board.
 for ring in shockwaves:
  var pct:float=clampf(float(ring["age"])/float(ring["duration"]),0.0,1.0)
  var radius:float=6.0+minf(72.0,float(ring["radius"]))*pow(pct,.70)
  var tint:Color=ring["color"]
  tint.a=maxf(0.0,(1.0-pct)*.32)
  draw_arc(ring["pos"],radius,0,TAU,44,tint,2.8*(1.0-pct)+.7,true)
  if pct<.56:
   tint.a*=.32
   draw_arc(ring["pos"],radius*.68,0,TAU,36,tint,1.25,true)
 for i in headlines.size():
  var heading:Dictionary=headlines[i]
  var age:float=clampf(float(heading["age"])/.92,0.0,1.0)
  var tint:Color=heading["color"]
  tint.a=pow(1.0-age,1.45)
  var pos:Vector2=Vector2(heading["pos"])+Vector2(0,(i-(headlines.size()-1)*.5)*26.0)
  var message:String=String(heading["text"])
  _label(message,pos-Vector2(150,0)+Vector2(1,2),17,
   Color(.05,.02,.19,tint.a*.5),HORIZONTAL_ALIGNMENT_CENTER,300)
  _label(message,pos-Vector2(150,0),17,tint,HORIZONTAL_ALIGNMENT_CENTER,300)

func _draw_fragments() -> void:
 # 4 distinct candy particles: glossy bubble / sprinkle / prism / sparkle.
 # Motion is deterministic once spawned and fully inside Godot CanvasItem.
 for f in fragments:
  var life:float=clampf(float(f["life"])/float(f["original"]),0,1)
  var color:Color=f["color"]
  color.a=life
  var center:Vector2=f["pos"]
  var size:float=float(f["radius"])*life
  if size<.35:continue # Avoid degenerate polygons as fragments fade out.
  var angle:float=float(f["rotation"])
  var axis:=Vector2(cos(angle),sin(angle))
  var across:=Vector2(-axis.y,axis.x)
  var kind:int=int(f.get("type",0))
  if kind==0:
   var triangle:=PackedVector2Array([
    center+axis*size*1.8,
    center-axis*size*.9+across*size*.70,
    center-axis*size*.9-across*size*.70])
   draw_colored_polygon(triangle,color)
   if size>1.3:
    draw_line(triangle[0],triangle[1],Color(1,1,1,life*.59),.85,true)
  elif kind==1:
   # Raised sugar bubble, bright translucent rim and white glaze dot.
   draw_circle(center,size,Color(color.r,color.g,color.b,life*.73))
   draw_arc(center,size*.77,PI*.82,TAU*.9,13,
    Color(1,1,1,life*.52),maxf(.65,size*.13),true)
   draw_circle(center-across*size*.29-axis*size*.26,size*.18,Color(1,1,1,life*.78))
  elif kind==2:
   var poly:=PackedVector2Array([
    center-axis*size*1.15-across*size*.42,
    center+axis*size*1.15-across*size*.42,
    center+axis*size*1.15+across*size*.42,
    center-axis*size*1.15+across*size*.42])
   draw_colored_polygon(poly,color)
   draw_line(poly[0],poly[1],Color(1,1,1,life*.66),maxf(.55,size*.1),true)
  else:
   var shine:=Color(1,1,1,life*.8)
   draw_line(center-axis*size*1.35,center+axis*size*1.35,shine,1.2,true)
   draw_line(center-across*size*1.35,center+across*size*1.35,shine,1.2,true)
   draw_circle(center,size*.24,color)


func _can_watch_ad_for_blast() -> bool:
 if native_ads==null or not native_ads.has_method("can_offer_rewarded"):
  return false
 var charges:int=puzzle.bombs if mode==0 else falling.rescues
 return charges<2 and bool(native_ads.call("can_offer_rewarded"))

func grant_ad_rescue() -> void:
 # Called ONLY from AdMob on_user_earned_reward, never merely on ad show.
 if not reward_ad_in_progress or reward_credit_given:
  return
 reward_credit_given=true
 var awarded:bool=puzzle.grant_rewarded_blast() if mode==0 else falling.grant_rewarded_blast()
 if not awarded:
  return
 if (mode==0 and puzzle.needs_rescue()) or (mode==1 and falling.rescue_pending):
  bomb_armed=true
 reward_offer_open=false
 selected=-1
 flash=.35
 _announce("REWARD EARNED: +1 BLAST!",_layout()["board"].get_center(),GLOW_GOLD)
 audio.effect("reward")
 _save_game()
 queue_redraw()

func rewarded_ad_finished(earned:bool) -> void:
 # Skipped/failed ads do not grant anything.
 reward_ad_in_progress=false
 reward_credit_given=false
 reward_offer_open=false
 paused=false
 if not earned:
  _announce("NO REWARD - AD NOT COMPLETED",_layout()["board"].get_center(),GLOW_PINK)
 queue_redraw()

func _draw_modal(layout:Dictionary) -> void:
 var viewport:Vector2 = layout["viewport"]
 var game_height:float=float(layout["height"])
 draw_rect(Rect2(Vector2.ZERO,Vector2(viewport.x,game_height)),Color(.01,.015,.08,.75),true)
 var modal := Rect2(Vector2(viewport.x*.09,game_height*.34),
  Vector2(viewport.x*.82,222))
 _glass_panel(modal,Color("#061335"),GLOW_PINK)
 var title := "OPTIONAL REWARD AD" if reward_offer_open else "RESTART RUN?" if restart_confirm else "PAUSED" if paused else "GAME OVER"
 _label(title,Vector2(modal.position.x,modal.position.y+56),24,
  Color("#fff2ff"),HORIZONTAL_ALIGNMENT_CENTER,modal.size.x)
 var score:int = puzzle.score if mode==0 else falling.score
 var detail:String="WATCH AD TO EARN +1 BLAST" if reward_offer_open else "SCORE  %d" % score
 _label(detail,Vector2(modal.position.x,modal.position.y+88),
  14 if reward_offer_open else 16,Color("#cbe9ff"),HORIZONTAL_ALIGNMENT_CENTER,modal.size.x)
 var action := "WATCH AD FOR +1 BLAST" if reward_offer_open else "REPLAY NOW" if restart_confirm else "▶ RESUME" if paused else "↻ PLAY AGAIN"
 _button(Rect2(modal.position+Vector2(27,107),Vector2(modal.size.x-54,36)),action,true)
 if reward_offer_open or paused:
  var secondary:String="NOT NOW" if reward_offer_open else "CANCEL" if restart_confirm else "↻ NEW RUN"
  _button(Rect2(modal.position+Vector2(27,148),Vector2(modal.size.x-54,27)),secondary,false,true)
 elif _can_watch_ad_for_blast():
  _button(Rect2(modal.position+Vector2(27,148),Vector2(modal.size.x-54,27)),
   "WATCH AD  ·  +1 BLAST",false,true)
 _button(Rect2(modal.position+Vector2(27,184),Vector2(modal.size.x-54,28)),"⌂  GALAXY HOME",false,true)

func _origin_from_position(pos:Vector2,centered:bool,board:Rect2,shape:Array) -> Vector2i:
 var cell:Vector2=Vector2(board.size.x/9.0,board.size.y/9.0)
 var local:Vector2=(pos-board.position)/cell
 if centered:
  var bounds:Vector2i = puzzle.shape_size(shape)
  return Vector2i(int(round(local.x-float(bounds.x)*.5)),
   int(round(local.y-float(bounds.y)*.5)))
 return Vector2i(int(floor(local.x)),int(floor(local.y)))

func _input(event:InputEvent) -> void:
 if event is InputEventScreenTouch and event.index==0:
  if event.pressed:
   _press(event.position)
  else:
   _release(event.position)
  get_viewport().set_input_as_handled()
 elif event is InputEventScreenDrag and event.index==0:
  _move_pointer(event.position)
  get_viewport().set_input_as_handled()
 elif not OS.has_feature("mobile") and event is InputEventMouseButton and event.button_index==MOUSE_BUTTON_LEFT:
  if event.pressed:
   _press(event.position)
  else:
   _release(event.position)
 elif not OS.has_feature("mobile") and event is InputEventMouseMotion and touching:
  _move_pointer(event.position)
 elif event is InputEventKey and event.pressed and not event.echo:
  if event.keycode==KEY_ESCAPE:
   paused = not paused
   settings_open=paused
  elif mode==1 and not paused:
   match event.keycode:
    KEY_LEFT: _fall_move(-1)
    KEY_RIGHT: _fall_move(1)
    KEY_UP: _fall_rotate()
    KEY_DOWN: _fall_soft_drop()
    KEY_SPACE: _fall_hard_drop()
  queue_redraw()

func _press(pos:Vector2) -> void:
 if banner_height>0.0 and not _layout()["safe"].has_point(pos):
  return # Native ad dock is never a Godot interaction area.
 touching = true
 pressed_at = pos
 touch_at = pos
 visual_pointer=pos
 dragging = false
 touch_moved=false
 press_clock=clock
 horizontal_anchor=pos.x
 soft_clock=0.0
 var layout:Dictionary = _layout()
 falling_touch_valid=mode==1 and layout["board"].has_point(pos)
 if paused or (mode==0 and puzzle.over) or (mode==1 and falling.over):
  return
 if mode==0:
  for i in layout["tray"].size():
   if layout["tray"][i].has_point(pos) and not puzzle.tray[i].is_empty():
    bomb_armed=false
    active_hint.clear()
    selected = i
    audio.effect("pick")
    return

func _move_pointer(pos:Vector2) -> void:
 if not touching:
  return
 if banner_height>0.0 and not _layout()["safe"].has_point(pos):
  return # Never drag gameplay beneath the live ad.
 touch_at=pos
 if pos.distance_to(pressed_at)>11.0:
  dragging=true
  touch_moved=true
 if mode==1 and falling_touch_valid and not paused and not falling.over and not falling.rescue_pending:
  var board:Rect2=_layout()["board"]
  var threshold:float=board.size.x/10.0*.72
  while touch_at.x-horizontal_anchor>threshold:
   _fall_move(1)
   horizontal_anchor+=threshold
  while horizontal_anchor-touch_at.x>threshold:
   _fall_move(-1)
   horizontal_anchor-=threshold
 queue_redraw()

func _release(pos:Vector2) -> void:
 if not touching:
  return
 touching=false
 touch_at=pos
 var layout:Dictionary=_layout()
 if banner_height>0.0 and not layout["safe"].has_point(pos):
  dragging=false
  queue_redraw()
  return # Cancel a gesture ending in the ad dock.
 if settings_open:
  _settings_action(pos,layout)
  return
 if challenge_won:
  if layout["finish"].has_point(pos) or layout["mode_switch"].has_point(pos):
   _save_game()
   get_tree().change_scene_to_file("res://scenes/Welcome.tscn")
  return
 if not paused and layout["pause"].has_point(pos):
  paused=true
  settings_open=true
  touching=false
  audio.effect("tap")
  return
 # The back button works during live gameplay, pause and game-over.
 if layout["mode_switch"].has_point(pos) and layout["mode_switch"].has_point(pressed_at):
  audio.effect("tap")
  _save_game()
  var error:int=get_tree().change_scene_to_file("res://scenes/Welcome.tscn")
  if error!=OK:
   printerr("NovaGrid: cannot return to main menu: ",error)
  return
 if paused and not restart_confirm and not reward_offer_open and not reward_ad_in_progress and mode==0 and skin_neon_puzzle!=null and not puzzle.over:
  var w:float=layout["viewport"].x
  var h:float=float(layout["height"])
  var panel:=Rect2(Vector2(w*.1,h*.30),Vector2(w*.8,295))
  if Rect2(panel.position+Vector2(22,57),Vector2(panel.size.x-44,43)).has_point(pos):
   audio.toggle_sound()
  elif Rect2(panel.position+Vector2(22,109),Vector2(panel.size.x-44,43)).has_point(pos):
   audio.toggle_music("puzzle")
  elif Rect2(panel.position+Vector2(22,166),Vector2(panel.size.x-44,40)).has_point(pos):
   paused=false
  elif Rect2(panel.position+Vector2(22,220),Vector2(panel.size.x-44,43)).has_point(pos):
   _save_game()
   get_tree().change_scene_to_file("res://scenes/Welcome.tscn")
  queue_redraw()
  return
 if paused or (mode==0 and puzzle.over) or (mode==1 and falling.over):
  var viewport:Vector2=layout["viewport"]
  var modal:=Rect2(Vector2(viewport.x*.09,float(layout["height"])*.34),Vector2(viewport.x*.82,222.0))
  var primary:=Rect2(modal.position+Vector2(27,107),Vector2(modal.size.x-54,36))
  var restart:=Rect2(modal.position+Vector2(27,148),Vector2(modal.size.x-54,27))
  var home:=Rect2(modal.position+Vector2(27,184),Vector2(modal.size.x-54,28))
  if home.has_point(pos):
   _save_game()
   get_tree().change_scene_to_file("res://scenes/Welcome.tscn")
   return
  if reward_offer_open:
   if primary.has_point(pos):
    if _can_watch_ad_for_blast():
     reward_ad_in_progress=true
     reward_credit_given=false
     if bool(native_ads.call("show_rewarded_for_rescue")):
      reward_offer_open=false
      paused=reward_ad_in_progress # True unless SDK fails synchronously.
     else:
      reward_ad_in_progress=false
      reward_offer_open=false
      paused=false
      _announce("REWARD AD UNAVAILABLE",layout["board"].get_center(),GLOW_PINK)
    else:
     reward_offer_open=false
     paused=false
   elif restart.has_point(pos):
    reward_offer_open=false
    paused=false
   audio.effect("tap")
  elif not paused and restart.has_point(pos) and _can_watch_ad_for_blast():
   # The game-over button itself clearly describes the optional reward.
   reward_ad_in_progress=true
   reward_credit_given=false
   if bool(native_ads.call("show_rewarded_for_rescue")):
    paused=reward_ad_in_progress
    audio.effect("tap")
   else:
    reward_ad_in_progress=false
  elif primary.has_point(pos):
   if restart_confirm or not paused:
    _restart_mode()
   else:
    paused=false
   audio.effect("confirm")
  elif paused and restart.has_point(pos):
   if restart_confirm:
    restart_confirm=false
    paused=false
   else:
    _restart_mode()
   audio.effect("tap")
  queue_redraw()
  return
 if not paused and not (puzzle.over if mode==0 else falling.over) and layout["replay"].has_point(pos) and layout["replay"].has_point(pressed_at):
  restart_confirm=true
  settings_open=false
  paused=true
  selected=-1
  bomb_armed=false
  audio.effect("popup")
  queue_redraw()
  return
 if layout["progress"].has_point(pos) and layout["progress"].has_point(pressed_at):
  if progress.unlocked_themes()>1:
   visuals.set_theme(progress.active_theme+1 if progress.active_theme+1<progress.unlocked_themes() else 0)
   var theme_name:String=progress.cycle_theme()
   _announce(theme_name+" GALAXY",Vector2(layout["viewport"].x*.5,layout["height"]*.5),Color("#c4f8ff"))
   audio.effect("reward")
   _save_game()
  else:
   _announce("NEXT GALAXY AT LEVEL 4",Vector2(layout["viewport"].x*.5,layout["height"]*.5),Color("#bdeaff"))
  return
 if mode==0 and layout["hint"].has_point(pos) and layout["hint"].has_point(pressed_at):
  _toggle_hint()
  return
 if layout["bomb"].has_point(pos) and layout["bomb"].has_point(pressed_at):
  active_hint.clear()
  var charges:int=puzzle.bombs if mode==0 else falling.rescues
  if charges>0:
   bomb_armed=true if ((mode==1 and falling.rescue_pending) or (mode==0 and puzzle.needs_rescue())) else not bomb_armed
   selected=-1
   audio.effect("tap")
  elif _can_watch_ad_for_blast():
   # Show a separate, explicit opt-in screen before the SDK is allowed
   # to display a full-screen rewarded ad. Cancel leaves the game intact.
   reward_offer_open=true
   settings_open=false
   paused=true
   selected=-1
   audio.effect("tap")
  else:
   _announce("CLEAR 4 LINES TO EARN A BLAST",layout["board"].get_center(),Color("#ffe0a7"))
  return
 if layout["pause"].has_point(pos):
  paused=true
  audio.effect("tap")
  return
 if layout["audio"].has_point(pos) and layout["audio"].has_point(pressed_at):
  audio.toggle_sound()
  return
 if layout["music"].has_point(pos) and layout["music"].has_point(pressed_at):
  audio.toggle_music("puzzle" if mode==0 else "falling")
  return
 if native_ads!=null and layout["privacy"].has_point(pos) and layout["privacy"].has_point(pressed_at):
  native_ads.call("show_privacy_options")
  return

 if mode==1 and layout["hold"].has_point(pos) and layout["hold"].has_point(pressed_at):
  if falling.hold_piece():
   if falling.rescue_pending:
    bomb_armed=true
    _announce("BLOCKED! TAP BOARD TO BLAST",layout["board"].get_center(),GLOW_PINK)
   fall_display=Vector2(falling.active)
   fall_drawn_drops=falling.drops
   audio.effect_for("falling","rotate")
   _save_game()
  else:
   audio.effect("invalid")
  return
 if mode==0:
  _release_puzzle(pos,layout)
 else:
  _release_falling(pos,layout)
 queue_redraw()

func _toggle_hint() -> void:
 # A transparent, free suggestion; no random draws, rewards, score or save.
 if mode!=0 or paused or puzzle.over or challenge_won:
  return
 if not active_hint.is_empty():
  active_hint.clear()
  selected=-1
 else:
  bomb_armed=false
  active_hint=HintSolver.best_move(puzzle,selected)
  if active_hint.is_empty():
   _announce("NO LEGAL MOVE · USE A BLAST",_layout()["board"].get_center(),GLOW_PINK)
  else:
   selected=int(active_hint["slot"])
   var groups:int=int(active_hint["groups"])
   var message:String="HINT · PIECE %d · %d CLEARS"%[selected+1,groups] if groups>0 else "HINT · PIECE %d"%[selected+1]
   _announce(message,_layout()["board"].get_center()-Vector2(0,45),GLOW_GOLD)
  audio.effect("tap")
 queue_redraw()

func _restart_mode() -> void:
 # Replay changes only this run. The permanent record and earned XP survive.
 paused=false
 settings_open=false
 restart_confirm=false
 active_hint.clear()
 reward_offer_open=false
 reward_ad_in_progress=false
 reward_credit_given=false
 selected=-1
 bomb_armed=false
 touching=false
 dragging=false
 flash=0.0
 shake=0.0
 shockwaves.clear()
 headlines.clear()
 fragments.clear()
 # Interstitials only after completed rounds; never on Pause/New Run.
 var completed:bool=(puzzle.over if mode==0 else falling.over)
 if completed and native_ads!=null:
  native_ads.call("maybe_show_interstitial")
 if mode==0:
  puzzle.reset()
  if entry=="daily" or entry=="stage":_new_challenge()
  selected=-1
  bomb_armed=false
 else:
  falling.reset()
  fall_display=Vector2(falling.active)
  fall_drawn_drops=falling.drops
  fall_accum=0
 _save_game()

func _release_puzzle(pos:Vector2,layout:Dictionary) -> void:
 var board:Rect2=layout["board"]
 if bomb_armed:
  if board.has_point(pos):
   var cell:float=board.size.x/9.0
   var cell_y:float=board.size.y/9.0
   var target:=Vector2i(clampi(int((pos.x-board.position.x)/cell),0,8),
    clampi(int((pos.y-board.position.y)/cell_y),0,8))
   var removed:int=puzzle.detonate_bomb(target)
   if removed>0:
    active_hint.clear()
    bomb_armed=false
    selected=-1
    var impact:Vector2=board.position+Vector2((target.x+.5)*cell,(target.y+.5)*cell_y)
    audio.effect_for("puzzle","big_shatter")
    _burst(impact,55+removed*5,Color("#ff62db"))
    _announce("CRYSTAL BURST!  %d GEMS" % removed,impact-Vector2(0,45),Color("#ffe7ff"))
    flash=.78
    shake=.46
    _save_game()
   else:
    _announce("TAP CRYSTALS TO BURST",board.get_center(),Color("#ffb6d8"))
  return
 var drop:Vector2 = pos-Vector2(0,52) if dragging else pos
 if selected>=0 and selected<puzzle.tray.size() and board.has_point(drop):
  var shape:Array = puzzle.tray[selected]
  if not shape.is_empty():
   var origin:Vector2i = _origin_from_position(drop,dragging,board,shape)
   if puzzle.place(selected,origin):
    active_hint.clear()
    _challenge_turn()
    var count:int = puzzle.last_cleared
    audio.effect_for("puzzle","big_shatter" if count>10 else "shatter" if count>0 else "place")
    progress.placed_piece()
    if puzzle.last_groups>0:
     progress.cleared_lines(puzzle.last_groups,puzzle.combo)
    if puzzle.last_bomb_award>0:
     _announce("RARE BOMB EARNED!",board.get_center()-Vector2(0,75),Color("#ffe27d"))
     audio.effect("fever")
    _reward_feedback(board.get_center())
    if count>0:
     flash=.28 if count<20 else .7
     shake=.25
     for yy in 9:
      for xx in 9:
       if int(puzzle.previous.get("cells",puzzle.cells)[yy][xx])>0 and puzzle.cells[yy][xx]==0:
        _burst(board.position+Vector2((xx+.5)*board.size.x/9.0,(yy+.5)*board.size.y/9.0),3,GEM_COLORS[int(puzzle.previous["cells"][yy][xx])])
     var combo_message:String="COSMIC COMBO x%d  +%d" % [puzzle.last_groups,puzzle.last_gained] if puzzle.last_groups>1 else "CRYSTAL CLEAR  +%d" % puzzle.last_gained
     _announce(combo_message,board.get_center()+Vector2(0,-12),Color("#91f7ff"))
    if puzzle.fever_moves==5:
     audio.effect("fever")
     _burst(board.get_center(),33,Color("#ff7aff"))
     _announce("NOVA FEVER!",board.get_center(),Color("#ff95e7"))
    if puzzle.needs_rescue():
     bomb_armed=true
     _announce("NO MOVE  -  USE YOUR EARNED BLAST",
      board.get_center()-Vector2(0,36),GLOW_PINK)
    if puzzle.over:
     audio.effect("lose")
    selected=-1
    _save_game()
   else:
    audio.effect("invalid")
  return

func _reward_feedback(center:Vector2) -> void:
 if progress.last_reward!="":
  _announce(progress.last_reward,center+Vector2(0,-87),Color("#ffe48a"))
  progress.last_reward=""

func _fall_move(dx:int) -> void:
 if falling.move(dx):
  audio.effect_for("falling","move")

func _fall_rotate() -> void:
 if falling.rotate():
  audio.effect_for("falling","rotate")

func _fall_soft_drop(audible:bool=true) -> void:
 var locked:bool=falling.soft_drop()
 if locked:
  _fall_locked()
 elif audible:
  audio.effect_for("falling","soft")

func _fall_hard_drop() -> void:
 if falling.over or falling.rescue_pending:
  return
 falling.hard_drop()
 _fall_locked()
 fall_accum=0.0

func _fall_locked() -> void:
 progress.locked_falling_piece()
 if falling.last_rescue_award>0:
  _announce("BLAST EARNED!",_layout()["board"].get_center()-Vector2(0,72),GLOW_GOLD)
  audio.effect("reward")
 if falling.last_lines>0:
  progress.cleared_lines(falling.last_lines,falling.combo)
  flash=.22+falling.last_lines*.1
  shake=.12+falling.last_lines*.06
  _burst(_layout()["board"].get_center(),20+falling.last_lines*9,Color("#86e8ff"))
  var clear_names:Array=["","SINGLE","DOUBLE","TRIPLE","SUPERNOVA"]
  var falling_message:String="BLOCKFALL COMBO x%d  +%d" % [falling.last_lines,falling.last_gained] if falling.last_lines>1 else "QUANTUM CLEAR  +%d" % falling.last_gained
  falling_message=String(clear_names[mini(4,falling.last_lines)])+"  +%d"%falling.last_gained
  _announce(falling_message,_layout()["board"].get_center(),Color("#b2f9ff"))
  audio.effect_for("falling","big_shatter" if falling.last_lines>=3 else "shatter")
 else:
  audio.effect_for("falling","lock")
 _reward_feedback(_layout()["board"].get_center())
 if falling.rescue_pending:
  bomb_armed=true
  _announce("NO ROOM  -  TAP BOARD TO RESCUE",_layout()["board"].get_center(),GLOW_PINK)
 elif falling.over:
  audio.effect("lose")
 _save_game()

func _release_falling(pos:Vector2,layout:Dictionary) -> void:
 if not falling_touch_valid or falling.over:
  return
 var board:Rect2=layout["board"]
 if falling.rescue_pending or bomb_armed:
  if board.has_point(pos) and falling.can_rescue():
   var dim:Vector2=board.size/Vector2(10,18)
   var target:=Vector2i(clampi(int((pos.x-board.position.x)/dim.x),0,9),
    clampi(int((pos.y-board.position.y)/dim.y),0,17))
   var removed:int=falling.detonate_rescue(target)
   if removed>0:
    bomb_armed=falling.rescue_pending
    audio.effect("falling_big_shatter")
    var impact:Vector2=board.position+Vector2((target.x+.5)*dim.x,(target.y+.5)*dim.y)
    _burst(impact,24+removed*4,GLOW_PINK)
    _announce("CANDY RESCUE!",impact-Vector2(0,33),GLOW_BLUE)
    flash=.58
    if falling.over:audio.effect("lose")
    _save_game()
   else:
    _announce("TAP OCCUPIED CELLS TO BLAST",board.get_center(),GLOW_PINK)
  return
 var displacement:Vector2=pos-pressed_at
 var elapsed:float=maxf(.01,clock-press_clock)
 var cell:float=board.size.x/10.0
 if displacement.y>cell*2.3:
  # Quick downward swipe = instant hard drop. No buttons obstruct the board.
  _fall_hard_drop()
 elif displacement.y>cell*.70:
  # Shorter swipe = a controlled soft drop.
  var steps:int=clampi(int(displacement.y/cell),1,6)
  for i in steps:
   if falling.over:
    break
   _fall_soft_drop(i==0)
 elif displacement.length()<cell*.42 and elapsed<.28:
  _fall_rotate()

func _announce(message:String,at:Vector2,color:Color) -> void:
 for i in range(headlines.size()-1,-1,-1):
  if String(headlines[i].get("text",""))==message:headlines.remove_at(i)
 headlines.append({"text":message,"pos":at,"age":0.0,"color":color})
 if headlines.size()>2:headlines.pop_front()

func _burst(center:Vector2,count:int,color:Color) -> void:
 shockwaves.append({"pos":center,"color":color,"age":0.0,"duration":.52,"radius":72.0})
 if shockwaves.size()>4:
  shockwaves.pop_front()
 var gen:=RandomNumberGenerator.new()
 gen.randomize()
 var candy_colors=[
  Color("#ff3d85"),Color("#ffce2c"),Color("#23eaf5"),
  Color("#a950ff"),Color("#75ff57"),Color("#ff9632"),
  Color("#ffffff")]
 for i in (mini(count,8) if visuals.reduced_effects else count):
  var angle:float=gen.randf_range(0,TAU)
  var velocity:Vector2=Vector2(cos(angle),sin(angle))*gen.randf_range(52,248)
  var visual_color:Color=candy_colors[gen.randi_range(0,candy_colors.size()-1)]
  if i%7==0:
   visual_color=color.lightened(.23)
  fragments.append({"pos":center,"speed":velocity,
   "life":gen.randf_range(.32,.92),"original":.92,
   "radius":gen.randf_range(1.7,5.3),"color":visual_color,
   "rotation":gen.randf_range(0.0,TAU),"spin":gen.randf_range(-10.0,10.0),
   "type":gen.randi_range(0,3)})
 if fragments.size()>230:
  fragments=fragments.slice(fragments.size()-230)

func _load_game() -> void:
 var data:Dictionary=SaveStore.read()
 var backup:Dictionary=SaveStore._read_path(SaveStore.PATH+".bak")
 for key in ["puzzle","falling","progression","campaign"]:
  if not data.has(key):continue
  var model=puzzle if key=="puzzle" else falling if key=="falling" else progress if key=="progression" else campaign
  var method:String="load_state" if key=="puzzle" else "restore"
  var restored:bool=data[key] is Dictionary and bool(model.call(method,data[key]))
  if not restored and backup.get(key) is Dictionary:
   model.call(method,backup[key])

func _save_game() -> void:
 if puzzle==null or falling==null:return
 var data:Dictionary=SaveStore.read()
 if entry=="daily" or entry=="stage":
  var challenge:Dictionary={"entry":entry,"stage":stage,"day":progress._today(),
   "puzzle":puzzle.save_state(),"run":challenge_run,"won":challenge_won,
   "rng_state":str(puzzle.rng.state)}
  data["challenge_"+entry]=challenge
  data["puzzle"]=classic_save
 else:
  data["puzzle"]=puzzle.save_state()
 data["falling"]=falling.snapshot()
 data["progression"]=progress.snapshot()
 data["campaign"]=campaign.snapshot()
 var result:Error=SaveStore.write(data)
 if result!=OK:push_error("NovaGrid save failed: %s"%error_string(result))

func _layout() -> Dictionary:
 var viewport:Vector2=get_viewport_rect().size
 var safe:Rect2=SafeArea.content_rect(viewport)
 safe.size.y=maxf(0.0,safe.size.y-banner_height)
 var w:float=safe.size.x
 var h:float=safe.size.y
 var margin:float=16.0
 # Classic adds a sixth HUD action; Blockfall retains the original five.
 var action_count:int=6 if mode==0 else 5
 var action_width:float=maxf(36.0,minf(72.0,
  (w-32.0-6.0*float(action_count-1))/float(action_count)))
 var header:float=clampf(h*.22,132.0,194.0)
 var side:float=clampf(w*.205,66.0,96.0)
 var board:Rect2
 var tray:Array=[]
 if mode==0:
  var tray_h:float=clampf(h*.10,58.0,112.0)
  var dimension:float=minf(w-2*margin,h-header-tray_h-132.0)
  board=Rect2(safe.position+Vector2((w-dimension)*.5,header),Vector2.ONE*dimension)
  var tray_w:float=(w-2*margin-24)/3.0
  for i in 3:
   tray.append(Rect2(Vector2(safe.position.x+margin+i*(tray_w+12),board.end.y+(16 if h<730 else 26)),Vector2(tray_w,tray_h)))
 else:
  var cell:float=minf((w-3*margin-side)/10.0,(h-header-166.0)/18.0)
  board=Rect2(safe.position+Vector2(margin,header),Vector2(10,18)*cell)
 var next:=Rect2(Vector2(board.end.x+12,board.position.y+24),Vector2(side,88))
 var hold:=Rect2(Vector2(next.position.x,next.end.y+48),Vector2(side,88))
 var back:=Rect2(safe.position+Vector2(16,16),Vector2(44,44))
 var pause_button:=Rect2(Vector2(safe.end.x-60,safe.position.y+16),Vector2(44,44))
 return {"viewport":viewport,"safe":safe,"height":safe.end.y,"gutter":margin,"header_scale":1.0,
  "board":board,"tray":tray,"buttons":[],"tabs":[],"next":next,"hold":hold,
  "mode_switch":back,"pause":pause_button,"pause_visual":pause_button,
  "audio":Rect2(safe.position.x+16,safe.end.y-104,action_width,44),
  "music":Rect2(safe.position.x+16+(action_width+6),safe.end.y-104,action_width,44),
  "privacy":Rect2(safe.position.x+16+2*(action_width+6),safe.end.y-104,action_width,44),
  "hint":Rect2(safe.position.x+16+3*(action_width+6),safe.end.y-104,action_width,44) if mode==0 else Rect2(Vector2(-100,-100),Vector2.ZERO),
  "replay":Rect2(safe.position.x+16+(4 if mode==0 else 3)*(action_width+6),safe.end.y-104,action_width,44),
  "bomb":Rect2(safe.position.x+16+(5 if mode==0 else 4)*(action_width+6),safe.end.y-104,action_width,44),
  "bomb_visual":Rect2(safe.position.x+16+(5 if mode==0 else 4)*(action_width+6),safe.end.y-104,action_width,44),
  "progress":Rect2(safe.position.x+16,safe.end.y-50,w-32,42),
  "finish":Rect2(safe.position.x+46,safe.position.y+h*.5+28,w-92,48)}

func _draw_cosmic() -> void:
 var layout:Dictionary=_layout()
 var safe:Rect2=layout["safe"]
 var w:float=safe.size.x
 _draw_sky(layout)
 draw_rect(Rect2(Vector2.ZERO,layout["viewport"]),Color("#03051d",.53),true)
 _draw_back_button(layout["mode_switch"])
 _button(layout["pause"],"",true)
 NeonSkin.icon(self,"pause",layout["pause"].get_center(),16,GLOW_BLUE)
 var title:String="Classic" if mode==0 else "Blockfall"
 if entry=="daily":title="Daily Challenge"
 if entry=="stage":title="Stage %d"%stage
 _premium_title(title,Vector2(safe.position.x,safe.position.y+47),29,w,GLOW_PURPLE)
 var subtitle:String="9 × 9  ·  Crystal Puzzle" if mode==0 else "10 × 18  ·  Falling Crystals"
 if entry=="daily":subtitle=progress._today()+" UTC  ·  Clear 6 groups"
 if entry=="stage":subtitle=String(campaign.stage_config(stage)["name"])
 _label(subtitle,Vector2(safe.position.x,safe.position.y+73),12,Color("#b2bfff"),HORIZONTAL_ALIGNMENT_CENTER,w)
 var card_y:float=safe.position.y+89
 var card_h:float=maxf(38,minf(72,layout["board"].position.y-card_y-20))
 for i in 2:
  var card:=Rect2(safe.position.x+34+i*(w*.5-22),card_y,w*.5-46,card_h)
  _glass_panel(card,Color("#071737") if i==0 else Color("#160b36"),GLOW_BLUE if i==0 else GLOW_PINK)
  _label("Score" if i==0 else ("Best" if mode==0 else "Level"),card.position+Vector2(0,17),12,Color("#d9deff"),HORIZONTAL_ALIGNMENT_CENTER,card.size.x)
  var value:int=(puzzle.score if mode==0 else falling.score) if i==0 else (puzzle.best if mode==0 else falling.level)
  _label(str(value),card.position+Vector2(0,card_h-10),clampi(int(card_h*.41),16,28),Color.WHITE,HORIZONTAL_ALIGNMENT_CENTER,card.size.x)
 if mode==0:_draw_puzzle(layout)
 else:_draw_falling(layout)
 _button(layout["audio"],"♪" if audio.sounds_enabled else "×",false,true)
 _button(layout["music"],"♫" if audio.music_enabled else "○",false,true)
 if native_ads!=null:_button(layout["privacy"],"PRIVACY",false,true)
 if mode==0:_button(layout["hint"],"HINT",not active_hint.is_empty(),true)
 _button(layout["replay"],"REPLAY",false,true)
 var blast_count:int=puzzle.bombs if mode==0 else falling.rescues
 _button(layout["bomb"],"AD +1" if blast_count==0 and _can_watch_ad_for_blast() else "BLAST %d"%blast_count,bomb_armed,true)
 if mode==0 and puzzle.needs_rescue():
  _label("NO MOVES - USE YOUR BLAST",layout["board"].position+Vector2(0,29),
   14,GLOW_GOLD,HORIZONTAL_ALIGNMENT_CENTER,layout["board"].size.x)
 if mode==1 and falling.rescue_pending:
  _label("BLOCKED - TAP FILLED CELLS",layout["board"].position+Vector2(0,28),
   13,GLOW_PINK,HORIZONTAL_ALIGNMENT_CENTER,layout["board"].size.x)
 _draw_progress_hud(layout)
 if entry=="stage":
  var cfg:Dictionary=campaign.stage_config(stage)
  _label("%d/%d clears · %d/%d score · %d/%d moves"%[int(challenge_run.get("specials",0)),int(cfg["special_target"]),puzzle.score,int(cfg["score_target"]),puzzle.moves,int(cfg["min_moves"])],Vector2(safe.position.x,layout["board"].position.y-7),10,GLOW_GOLD,HORIZONTAL_ALIGNMENT_CENTER,w)
 _draw_shockwaves()
 _draw_fragments()
 if flash>0:draw_rect(layout["board"],Color(.65,.9,1,flash*.12),true)
 if settings_open:_draw_cosmic_settings(layout)
 elif challenge_won:
  draw_rect(Rect2(Vector2.ZERO,layout["viewport"]),Color("#02051b",.85),true)
  var stars:int=campaign.rank_result(stage,puzzle,challenge_run) if entry=="stage" else 3
  _premium_title("STAGE COMPLETE" if entry=="stage" else "DAILY COMPLETE",Vector2(safe.position.x,safe.position.y+safe.size.y*.43),24,w,GLOW_PINK)
  _label("★".repeat(stars),Vector2(safe.position.x,safe.position.y+safe.size.y*.5),40,GLOW_GOLD,HORIZONTAL_ALIGNMENT_CENTER,w)
  _button(layout["finish"],"GALAXY HOME",true)
 elif paused or (puzzle.over if mode==0 else falling.over):_draw_modal(layout)

func _settings_boxes(layout:Dictionary) -> Array[Rect2]:
 var safe:Rect2=layout["safe"]
 var top:float=safe.position.y+safe.size.y*.28
 var result:Array[Rect2]=[]
 for i in 5:result.append(Rect2(safe.position.x+48,top+i*57,safe.size.x-96,45))
 return result

func _draw_cosmic_settings(layout:Dictionary) -> void:
 draw_rect(Rect2(Vector2.ZERO,layout["viewport"]),Color("#03051c",.93),true)
 var boxes:Array[Rect2]=_settings_boxes(layout)
 _premium_title("SETTINGS",Vector2(0,boxes[0].position.y-33),28,layout["viewport"].x,GLOW_PURPLE)
 var labels:Array=["SOUND: "+("ON" if audio.sounds_enabled else "OFF"),"MUSIC: "+("ON" if audio.music_enabled else "OFF"),"EFFECTS: "+("LOW" if visuals.reduced_effects else "FULL"),"RESUME","NEW RUN"]
 for i in boxes.size():_button(boxes[i],labels[i],i==3)
 _draw_back_button(layout["mode_switch"])

func _settings_action(pos:Vector2,layout:Dictionary) -> void:
 if layout["mode_switch"].has_point(pos):
  settings_open=false
  paused=false
  return
 var boxes:Array[Rect2]=_settings_boxes(layout)
 for i in boxes.size():
  if not boxes[i].has_point(pos) or not boxes[i].has_point(pressed_at):continue
  match i:
   0:audio.toggle_sound()
   1:audio.toggle_music("puzzle" if mode==0 else "falling")
   2:
    visuals.reduced_effects=not visuals.reduced_effects
    var cfg:=ConfigFile.new()
    cfg.load("user://novagrid-visual.cfg")
    cfg.set_value("graphics","reduced_effects",visuals.reduced_effects)
    cfg.save("user://novagrid-visual.cfg")
    visuals.sky_material.set_shader_parameter("reduced_effects",visuals.reduced_effects)
    visuals.sky_material.set_shader_parameter("activity",.45 if visuals.reduced_effects else .75)
    visuals.sky_material.set_shader_parameter("motion_speed",0.0 if visuals.reduced_effects else .08)
   3:
    settings_open=false
    paused=false
   4:
    settings_open=false
    paused=false
    _restart_mode()

func _start_challenge() -> void:
 if entry!="daily" and entry!="stage":return
 classic_save=puzzle.save_state()
 if entry=="stage" and (stage<1 or stage>campaign.unlocked):
  entry="classic"
  return
 var data:Dictionary=SaveStore.read()
 var saved:Variant=data.get("challenge_"+entry,{})
 if saved is Dictionary and saved.get("puzzle") is Dictionary and saved.get("run") is Dictionary:
  var same:bool=String(saved.get("day",""))==progress._today() if entry=="daily" else int(saved.get("stage",0))==stage
  var replay_completed_stage:bool=entry=="stage" and bool(saved.get("won",false))
  if same and not replay_completed_stage and puzzle.load_state(saved["puzzle"]):
   challenge_run=saved["run"]
   challenge_won=bool(saved.get("won",false))
   puzzle.rng.state=int(saved.get("rng_state",str(puzzle.rng.state)))
   return
 _new_challenge()

func _new_challenge() -> void:
 puzzle.reset()
 puzzle.best=0
 puzzle.rng.seed=("novagrid-daily-"+progress._today()).hash() if entry=="daily" else ("novagrid-stage-%d"%stage).hash()
 puzzle.reset()
 challenge_run={"specials":0,"max_combo":0}
 challenge_won=false
 if entry=="stage":puzzle.cells=campaign.initial_board(stage)

func _challenge_turn() -> void:
 if entry=="stage":
  challenge_run=campaign.apply_turn(stage,puzzle,challenge_run)
  if campaign.won(stage,puzzle,challenge_run):
   challenge_won=true
   campaign.record_result(stage,puzzle,challenge_run)
 elif entry=="daily" and puzzle.total_lines>=6:
  challenge_won=true
  var data:Dictionary=SaveStore.read()
  var daily:Dictionary=data.get("daily",{}) if data.get("daily",{}) is Dictionary else {}
  if daily.get("reward_day","")!=progress._today():
   progress.stars+=25
   daily["reward_day"]=progress._today()
  daily["best"]=maxi(int(daily.get("best",0)),puzzle.score)
  data["daily"]=daily
  SaveStore.write(data)
 if challenge_won:
  audio.effect("fever")
  _burst(_layout()["board"].get_center(),72,GLOW_GOLD)

func _notification(what:int) -> void:
 if what==NOTIFICATION_WM_GO_BACK_REQUEST and puzzle!=null:
  paused=true
  settings_open=not settings_open
  if not settings_open:paused=false
  touching=false
  dragging=false
  _save_game()
  queue_redraw()
 if what==NOTIFICATION_APPLICATION_PAUSED or what==NOTIFICATION_APPLICATION_FOCUS_OUT:
  if puzzle!=null:
   paused=true
   touching=false
   dragging=false
   _save_game()
