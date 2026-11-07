extends Node2D
## NovaGrid native Godot 4.5 game UI.
## Gameplay, glass blocks, drag/drop, visual FX, saves and sounds run on Godot.
const PuzzleScript = preload("res://scripts/Puzzle.gd")
const FallingScript = preload("res://scripts/Falling.gd")
const AudioScript = preload("res://scripts/Audio.gd")
const VisualsScript = preload("res://scripts/Visuals.gd")
const ProgressionScript = preload("res://scripts/Progression.gd")

const GEM_COLORS = [
 Color("#192850"), Color("#ff287f"), Color("#ffbe17"), Color("#13c7fa"),
 Color("#963aff"), Color("#11db60"), Color("#ff751c"), Color("#127bff")
]
const SKY = Color("#070923")
# User-approved 941x1672 reference art is an optional real Godot texture.
# The original procedural shader remains the safe fallback in source-only clones.
const EXACT_FALL_SKIN = "res://assets/skins/blockfall_exact_reference.png"
const PUZZLE_COSMIC_SKIN = "res://assets/skins/blockpuzzle_cosmic_backdrop.png"
const SKIN_CANVAS = Vector2(941.0,1672.0)
# Shared premium Cosmic Candy arcade palette used for BOTH live modes.
const GLOW_BLUE = Color("#39ebff")
const GLOW_PINK = Color("#ff6df1")
const GLOW_PURPLE = Color("#a55cff")
const GLOW_GOLD = Color("#ffe48a")
var puzzle
var falling
var audio
var visuals
var progress
var font: Font
var gem_styles: Array = []
var panel_styles: Dictionary = {}
var mode := 0
var paused := false
var selected := -1
var bomb_armed := false
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
var banner_height := 0.0 # Reserved only after an actual native banner reports its measured height.
var native_ads: Node = null
var skin_fall:Texture2D = null
var skin_puzzle:Texture2D = null

func set_native_banner_height(px:float) -> void:
 # Reserved for the native AdMob bridge: do not simulate real ad filling here.
 banner_height=clampf(px,0.0,130.0)
 queue_redraw()
var stars: Array = []
var fragments: Array = []
var shockwaves: Array = []
var headlines: Array = []
var flash := 0.0
var shake := 0.0

func _ready() -> void:
 puzzle = PuzzleScript.new()
 falling = FallingScript.new()
 audio = AudioScript.new()
 add_child(audio)
 progress = ProgressionScript.new()
 font = ThemeDB.fallback_font
 visuals = VisualsScript.new()
 add_child(visuals)
 visuals.configure(GEM_COLORS)
 if ResourceLoader.exists(EXACT_FALL_SKIN):
  skin_fall = load(EXACT_FALL_SKIN) as Texture2D
 if ResourceLoader.exists(PUZZLE_COSMIC_SKIN):
  skin_puzzle = load(PUZZLE_COSMIC_SKIN) as Texture2D
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
 audio.select_music("puzzle" if mode==0 else "falling")
 get_viewport().size_changed.connect(queue_redraw)
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
 if mode==1 and touching and falling_touch_valid and not paused and not falling.over:
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
  if float(heading["age"]) > 1.15:
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
 if mode==1 and not paused and not falling.over:
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

func _layout() -> Dictionary:
 var viewport:Vector2=get_viewport_rect().size
 var w:float=viewport.x
 var h:float=viewport.y-banner_height
 var gutter:float=clampf(w*.031,9.0,18.0)
 if mode==1 and skin_fall!=null and h>=760.0:
  return _reference_blockfall_layout(viewport,h)
 var header_scale:float=clampf(h/840.0,.72,1.0)
 var header_end:float=177.0*header_scale
 var board:Rect2
 var tray:Array=[]
 var buttons:Array=[]
 var side_width:float=clampf(w*.194,65.0,85.0)
 if mode==0:
  # A real 9x9 glass grid and three unframed glowing crystal tray shapes.
  var tray_height:float=clampf(h*.078,48.0,75.0)
  var available:float=maxf(80.0,h-header_end-tray_height-115.0)
  var cell:float=maxf(2.0,minf((w-2.0*gutter-10.0)/9.0,available/9.0))
  var size:Vector2=Vector2(cell*9.0,cell*9.0)
  board=Rect2(Vector2((w-size.x)*.5,header_end+minf(20.0,maxf(3.0,(available-size.y)*.10))),size)
  var tray_y:float=board.end.y+11.0
  var tray_w:float=(w-2.0*gutter-18.0)/3.0
  for i in 3:
   tray.append(Rect2(Vector2(gutter+i*(tray_w+9.0),tray_y),Vector2(tray_w,tray_height)))
 else:
  # Leave the real 10x18 board big, with playable NEXT and HOLD at right.
  var available:float=maxf(180.0,h-header_end-121.0)
  var cell:float=maxf(2.0,minf((w-3.0*gutter-side_width)/10.0,available/18.0))
  var size:Vector2=Vector2(cell*10.0,cell*18.0)
  board=Rect2(Vector2(gutter,header_end+minf(12.0,maxf(3.0,(available-size.y)*.10))),size)
 var next_rect:=Rect2(Vector2(board.end.x+gutter,board.position.y+37.0),Vector2(side_width,96.0))
 var hold_rect:=Rect2(Vector2(board.end.x+gutter,board.position.y+minf(187.0,board.size.y*.39)),Vector2(side_width,96.0))
 return {"viewport":viewport,"height":h,"gutter":gutter,"header_scale":header_scale,
  "tabs":[],"board":board,"tray":tray,"buttons":buttons,
  "progress":Rect2(gutter,h-36.0,w-2.0*gutter,29.0),
  "mode_switch":Rect2(gutter,12.0*header_scale,43.0,43.0*header_scale),
  "bomb_visual":Rect2(w-gutter-61.0,146.0,61.0,30.0),
  "pause_visual":Rect2(w-gutter-48.0,80.0,48.0,48.0),
  "bomb":Rect2(w-gutter-61.0,146.0*header_scale,61.0,30.0*header_scale),
  "pause":Rect2(w-gutter-48.0,80.0*header_scale,48.0,48.0*header_scale),
  "audio":Rect2(gutter,round(h-101.0),36.0,34.0),
  "music":Rect2(gutter+42.0,round(h-101.0),36.0,34.0),
  "privacy":Rect2(gutter+84.0,round(h-101.0),72.0,34.0),
  "next":next_rect,"hold":hold_rect}

func _draw() -> void:
 var layout:Dictionary = _layout()
 var h:float=float(layout["height"])
 var w:float=float(layout["viewport"].x)
 var art:Texture2D=skin_fall if mode==1 else skin_puzzle
 if art!=null:
  # Scale actual user-approved artwork as part of the game, not as a mockup.
  draw_texture_rect(art,Rect2(Vector2.ZERO,Vector2(w,h)),false)
  if mode==1:
   _reference_live_hud(layout)
  else:
   draw_set_transform(Vector2.ZERO,0.0,Vector2(1.0,float(layout["header_scale"])))
   _draw_header(layout)
   draw_set_transform(Vector2.ZERO,0.0,Vector2.ONE)
 else:
  _draw_sky(layout)
  draw_set_transform(Vector2.ZERO,0.0,Vector2(1.0,float(layout["header_scale"])))
  _draw_header(layout)
  draw_set_transform(Vector2.ZERO,0.0,Vector2.ONE)
 _draw_tabs(layout)
 _draw_progress_hud(layout)
 var impact := Vector2(sin(clock*67.0),cos(clock*79.0))*shake*9.0
 draw_set_transform(impact)
 if mode==0:
  _draw_puzzle(layout)
 else:
  _draw_falling(layout)
 draw_set_transform(Vector2.ZERO)
 _draw_shockwaves()
 _draw_fragments()
 if flash>0:
  draw_rect(Rect2(Vector2.ZERO,layout["viewport"]),Color(0.6,0.9,1.0,flash*0.15),true)
 if paused or (mode==0 and puzzle.over) or (mode==1 and falling.over):
  _draw_modal(layout)
 if banner_height>0:
  var r := Rect2(Vector2(0,layout["height"]),Vector2(float(layout["viewport"].x),banner_height))
  draw_rect(r,Color("#080f26"),true)
  draw_line(r.position,Vector2(r.end.x,r.position.y),Color("#78dfff"),2.0)

func _reference_blockfall_layout(viewport:Vector2,h:float) -> Dictionary:
 # Touch/gameplay rectangles calibrated from the actual 941x1672 reference.
 # Every position adapts independently to phone width, height and ad dock.
 var sx:float=viewport.x/SKIN_CANVAS.x
 var sy:float=h/SKIN_CANVAS.y
 var board:=Rect2(Vector2(76.0*sx,349.0*sy),
  Vector2(586.0*sx,967.0*sy))
 var next_rect:=Rect2(Vector2(711.0*sx,406.0*sy),
  Vector2(176.0*sx,177.0*sy))
 var hold_rect:=Rect2(Vector2(711.0*sx,667.0*sy),
  Vector2(176.0*sx,165.0*sy))
 var gutter:float=clampf(viewport.x*.031,9.0,18.0)
 return {
  "viewport":viewport,"height":h,"gutter":gutter,"header_scale":1.0,
  "board":board,"tray":[],"buttons":[],"tabs":[],
  "next":next_rect,"hold":hold_rect,
  "progress":Rect2(Vector2(40.0*sx,1528.0*sy),
   Vector2(860.0*sx,85.0*sy)),
  "mode_switch":Rect2(Vector2(39.0*sx,22.0*sy),Vector2(81.0*sx,88.0*sy)),
  "pause_visual":Rect2(Vector2(786.0*sx,163.0*sy),
   Vector2(97.0*sx,92.0*sy)),
  "pause":Rect2(Vector2(786.0*sx,163.0*sy),
   Vector2(97.0*sx,92.0*sy)),
  "audio":Rect2(Vector2(42.0*sx,1421.0*sy),Vector2(76.0*sx,68.0*sy)),
  "music":Rect2(Vector2(129.0*sx,1421.0*sy),Vector2(76.0*sx,68.0*sy)),
  "privacy":Rect2(Vector2(224.0*sx,1430.0*sy),Vector2(105.0*sx,52.0*sy)),
  "bomb":Rect2(),"bomb_visual":Rect2()
 }


func _reference_live_hud(layout:Dictionary) -> void:
 # The reference is treated as professionally illustrated chrome. These
 # value windows are replaced by live gameplay data on every redraw.
 var sx:float=float(layout["viewport"].x)/SKIN_CANVAS.x
 var sy:float=float(layout["height"])/SKIN_CANVAS.y
 var score_box:=Rect2(Vector2(188.0*sx,204.0*sy),
  Vector2(124.0*sx,62.0*sy))
 var level_box:=Rect2(Vector2(563.0*sx,203.0*sy),
  Vector2(110.0*sx,62.0*sy))
 # Dark tint matches the inner-glass panel, masking static screenshot digits.
 draw_rect(score_box,Color("#261044",.985),true)
 draw_rect(level_box,Color("#09265a",.985),true)
 _premium_title(str(falling.score),Vector2(157.0*sx,253.0*sy),28,
  184.0*sx,GLOW_GOLD)
 _premium_title(str(falling.level),Vector2(541.0*sx,252.0*sy),28,
  164.0*sx,GLOW_GOLD)
 var combo_strip:=Rect2(Vector2(83.0*sx,286.0*sy),
  Vector2(337.0*sx,35.0*sy))
 draw_rect(combo_strip,Color("#100a35",.96),true)
 _label("COMBO x%d   ✦  LINES %d" % [falling.combo,falling.lines],
  Vector2(combo_strip.position.x,311.0*sy),13,
  Color("#ffd0ff"))
 # Never rely on fake numbers baked in the art's progression footer.
 _sparkle(Vector2(434.0*sx,295.0*sy),GLOW_BLUE,3.0)


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
 draw_string(font,pos,text,alignment,width,size,color)

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


func _glass_panel(rect:Rect2,fill:Color=Color("#17225b"),outline:Color=Color("#7deaff")) -> void:
 # Cached rounded style; real-time glows remain lightweight on midrange phones.
 var key:String=fill.to_html(true)+":"+outline.to_html(true)
 if not panel_styles.has(key):
  var panel:=StyleBoxFlat.new()
  panel.bg_color=fill
  panel.border_color=outline
  panel.set_corner_radius_all(14)
  panel.set_border_width_all(2)
  panel.shadow_color=Color(outline.r,outline.g,outline.b,.28)
  panel.shadow_size=9
  panel.shadow_offset=Vector2.ZERO
  panel_styles[key]=panel
 draw_rect(rect.grow(4.0),Color(outline.r,outline.g,outline.b,.07),false,3.0)
 draw_style_box(panel_styles[key],rect)
 var pad:float=minf(17.0,rect.size.x*.15)
 if rect.size.x>30.0 and rect.size.y>15.0:
  draw_line(rect.position+Vector2(pad,2.4),
   Vector2(rect.end.x-pad,rect.position.y+2.4),
   Color(1,1,1,.74),1.7,true)
  draw_line(rect.position+Vector2(pad,5.0),
   Vector2(rect.end.x-pad,rect.position.y+5.0),
   Color(outline.r,outline.g,outline.b,.31),1.2,true)
  draw_line(Vector2(rect.position.x+pad,rect.end.y-2.5),
   Vector2(rect.end.x-pad,rect.end.y-2.5),
   Color(outline.r,outline.g,outline.b,.48),1.6,true)
  draw_circle(rect.position+Vector2(10,10),2.1,Color.WHITE)

func _button(rect:Rect2,title:String,active:bool=false,small:bool=false) -> void:
 var hue:Color=GLOW_BLUE if active else GLOW_PURPLE
 var fill:Color=Color("#0953a0") if active else Color("#1b235d")
 _glass_panel(rect,fill,hue)
 if rect.size.x>22.0 and rect.size.y>24.0:
  # Crisp diagonal gloss in the upper third, independent of input hitboxes.
  draw_line(rect.position+Vector2(9,rect.size.y*.33),
   rect.position+Vector2(rect.size.x-9,rect.size.y*.33),
   Color("#e6ffff",.28),1.1,true)
 var fontsize:int=12 if small else 16
 _label(title,Vector2(rect.position.x,rect.position.y+rect.size.y*.66+1),
  fontsize,Color(hue.r,hue.g,hue.b,.52),
  HORIZONTAL_ALIGNMENT_CENTER,rect.size.x)
 _label(title,Vector2(rect.position.x,rect.position.y+rect.size.y*.66),
  fontsize,Color.WHITE,HORIZONTAL_ALIGNMENT_CENTER,rect.size.x)

func _draw_header(layout:Dictionary) -> void:
 var w:float=layout["viewport"].x
 var g:float=layout["gutter"]
 var mode_name:String="BLOCK PUZZLE" if mode==0 else "BLOCKFALL"
 var accent:Color=GLOW_BLUE if mode==0 else GLOW_PINK
 # Bright arcade headline, cosmic underline and gold subtitle.
 _premium_title(mode_name,Vector2(0,44),29,w,accent)
 _label("✦  3D CANDY GALAXY  ✦",Vector2(0,62),11,
  GLOW_GOLD,HORIZONTAL_ALIGNMENT_CENTER,w)
 draw_line(Vector2(w*.36,68),Vector2(w*.64,68),accent,1.7,true)
 _sparkle(Vector2(w*.65,68),GLOW_GOLD,3.0)
 var score:int=puzzle.score if mode==0 else falling.score
 var best:int=puzzle.best if mode==0 else falling.best
 var second_label:String="BEST" if mode==0 else "LEVEL"
 var second_value:String=str(best) if mode==0 else str(falling.level)
 var left_card:=Rect2(Vector2(g,77),Vector2((w-3.0*g-55.0)*.51,57))
 var right_card:=Rect2(Vector2(left_card.end.x+g,77),
  Vector2((w-3.0*g-55.0)*.49,57))
 _glass_panel(left_card,Color("#270d4e"),GLOW_PINK)
 _glass_panel(right_card,Color("#08285a"),GLOW_BLUE)
 _label("SCORE",Vector2(left_card.position.x,left_card.position.y+17),
  12,Color("#f4d9ff"),HORIZONTAL_ALIGNMENT_CENTER,left_card.size.x)
 _label(str(score),Vector2(left_card.position.x+1,left_card.position.y+44),
  26,Color("#e49c45"),HORIZONTAL_ALIGNMENT_CENTER,left_card.size.x)
 _label(str(score),Vector2(left_card.position.x,left_card.position.y+42),
  26,GLOW_GOLD,HORIZONTAL_ALIGNMENT_CENTER,left_card.size.x)
 _label(second_label,Vector2(right_card.position.x,right_card.position.y+17),
  12,Color("#d1f7ff"),HORIZONTAL_ALIGNMENT_CENTER,right_card.size.x)
 _label(second_value,Vector2(right_card.position.x+1,right_card.position.y+44),
  26,Color("#d59149"),HORIZONTAL_ALIGNMENT_CENTER,right_card.size.x)
 _label(second_value,Vector2(right_card.position.x,right_card.position.y+42),
  26,GLOW_GOLD,HORIZONTAL_ALIGNMENT_CENTER,right_card.size.x)
 _button(layout["pause_visual"],"▶" if paused else "Ⅱ",true,false)
 if mode==0:
  var progress_bar:=Rect2(Vector2(g,147),Vector2(w-2.0*g-73.0,10))
  _glass_panel(progress_bar,Color("#221048"),GLOW_PINK)
  var gauge:=Rect2(progress_bar.position+Vector2(2,2),
   Vector2(maxf(0.0,(progress_bar.size.x-4)*float(puzzle.fever)/100.0),progress_bar.size.y-4))
  if gauge.size.x>1.0:
   draw_rect(gauge,Color("#f467f7"),true)
   draw_line(gauge.position,Vector2(gauge.end.x,gauge.position.y),Color("#ffffff",.67),1.2,true)
  _label("FEVER  %d%%" % puzzle.fever,Vector2(g,172),10,GLOW_PINK)
  var bomb:Rect2=layout["bomb_visual"]
  _glass_panel(bomb,Color("#501157") if bomb_armed else Color("#19134a"),
   GLOW_PINK)
  _label("✦  %s" % (str(puzzle.bombs) if puzzle.bombs>0 else "%d%%" % puzzle.bomb_charge()),
   Vector2(bomb.position.x,bomb.position.y+21),13,
   GLOW_GOLD,HORIZONTAL_ALIGNMENT_CENTER,bomb.size.x)
  _label("COMBO x%d  •  LINES %d" % [puzzle.combo,puzzle.total_lines],
   Vector2(g+79,172),10,Color("#f9dcff"))
 else:
  _label("COMBO x%d  ✦  LINES %d" % [falling.combo,falling.lines],
   Vector2(g,171),13,Color("#ffc3f8"))

func _draw_progress_hud(layout:Dictionary) -> void:
 # Premium rank ribbon anchored outside the playable cells and native ad dock.
 var rect:Rect2=layout["progress"]
 var y:float=rect.position.y
 _glass_panel(rect,Color("#0e1744"),GLOW_PURPLE)
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

func _draw_tabs(layout:Dictionary) -> void:
 # A single compact mode switch avoids breaking the hero-screen composition.
 # No directional or on-board movement arrows.
 _button(layout["mode_switch"],"▦" if mode==0 else "✦",false,true)
 _button(layout["audio"],"♪" if audio.sounds_enabled else "×",false,true)
 _button(layout["music"],"♫" if audio.music_enabled else "○",false,true)
 if native_ads!=null:
  _button(layout["privacy"],"PRIVACY",false,true)


func _gem(rect:Rect2,color_id:int,ghost:bool=false) -> void:
 if color_id<=0:
  return
 var base:Color=GEM_COLORS[clampi(color_id,1,GEM_COLORS.size()-1)]
 var middle:Vector2=rect.get_center()
 if ghost:
  # Candy-accurate transparent landing silhouette (not a full ghost cube).
  draw_circle(middle,rect.size.x*.34,Color(base.r,base.g,base.b,.14))
  draw_arc(middle,rect.size.x*.39,0,TAU,22,Color(base.r,base.g,base.b,.70),1.7,true)
  return
 var padding:float=.55 if rect.size.x>=19.0 else .20
 var candy_rect:=rect.grow(-padding)
 # Contact shadow below each physically rendered PBR 3D sweet.
 if rect.size.x>=12.0:
  draw_circle(middle+Vector2(0,rect.size.y*.275),
   rect.size.x*.34,Color(.01,.01,.07,.25))
 if rect.size.x>=20.0:
  draw_circle(middle,rect.size.x*.42,Color(base.r,base.g,base.b,.10))
 var texture:Texture2D=visuals.get_gem_texture(color_id) if visuals else null
 if texture!=null:
  draw_texture_rect(texture,candy_rect,false,Color.WHITE)
 else:
  draw_style_box(gem_styles[clampi(color_id,1,gem_styles.size()-1)],candy_rect)
 # 3D icing has real mesh highlights already; don't paint fake rectangular
 # edges on top of round candies, which would undo the Candy look.


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
 var cell:float=_board_back(board,9,9)
 for y in 9:
  for x in 9:
   var id:int=int(puzzle.cells[y][x])
   if id>0:
    _gem(Rect2(board.position+Vector2(x*cell,y*cell),Vector2(cell,cell)),id)
 if bomb_armed and board.has_point(touch_at):
  var target:=Vector2i(clampi(int((touch_at.x-board.position.x)/cell),0,8),
   clampi(int((touch_at.y-board.position.y)/cell),0,8))
  for yy in range(maxi(0,target.y-1),mini(9,target.y+2)):
   for xx in range(maxi(0,target.x-1),mini(9,target.x+2)):
    var tile:=Rect2(board.position+Vector2(xx*cell,yy*cell),
     Vector2(cell,cell))
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
     _gem(Rect2(board.position+Vector2(q.x*cell,q.y*cell),
      Vector2(cell,cell)),preview_color,true)
 # Full-width play area: 3 touchable glass trays, not small inert artwork.
 var colors:Array=puzzle.tray_colors
 for i in 3:
  var tray_rect:Rect2=layout["tray"][i]
  var gem_id:int=int(colors[i])
  var highlight:Color=GEM_COLORS[gem_id]
  var active:bool=i==selected
  _glass_panel(tray_rect,Color("#142151") if active else Color("#10183f"),
   GLOW_PINK if active else Color("#417bc7"))
  if active:
   draw_rect(tray_rect.grow(3.0),Color(highlight.r,highlight.g,highlight.b,.20),false,3.0)
  var shape:Array=puzzle.tray[i]
  if shape.is_empty():
   continue
  var bounds:Vector2i=puzzle.shape_size(shape)
  var micro:float=minf((tray_rect.size.x-13.0)/float(bounds.x),
   (tray_rect.size.y-9.0)/float(bounds.y))
  micro=minf(micro,30.0)
  var offset:Vector2=tray_rect.position+(tray_rect.size-
   Vector2(micro*bounds.x,micro*bounds.y))*.5
  for p in shape:
   _gem(Rect2(offset+Vector2(p.x*micro,p.y*micro),
    Vector2(micro,micro)),gem_id)
 _label("✦  DRAG CANDIES  ·  CLEAR LINES  ·  COMBO BLAST  ✦",
  Vector2(0,layout["height"]-117.0),10,Color("#c5f8ff"),
  HORIZONTAL_ALIGNMENT_CENTER,layout["viewport"].x)
 if dragging and selected>=0 and not puzzle.tray[selected].is_empty():
  var s:Array=puzzle.tray[selected]
  var shape_size:Vector2i=puzzle.shape_size(s)
  var left:Vector2=visual_pointer-Vector2(shape_size.x*cell*.5,shape_size.y*cell*.5+54)
  for p in s:
   _gem(Rect2(left+Vector2(p.x*cell,p.y*cell),
    Vector2(cell,cell)),int(colors[selected]),true)

func _draw_falling(layout:Dictionary) -> void:
 var board:Rect2=layout["board"]
 var cell:float=_board_back(board,10,18)
 var cell_h:float=board.size.y/18.0
 var ghost:Vector2i=Vector2i(falling.active.x,falling.ghost_row())
 for y in 18:
  for x in 10:
   var id:int=falling.cell_at(x,y)
   if id>0:
    _gem(Rect2(board.position+Vector2(x*cell,y*cell_h),
     Vector2(cell,cell_h)),id)
 for p in falling.piece:
  var pos:Vector2i=ghost+p
  if pos.y>=0 and pos.y<18 and falling.board[pos.y][pos.x]==0:
   # The real upcoming landing position is a luminous hollow tetromino.
   _gem(Rect2(board.position+Vector2(pos.x*cell,pos.y*cell_h),
    Vector2(cell,cell_h)),falling.kind+1,true)
 for p in falling.piece:
  var pos:Vector2=fall_display+Vector2(p)
  if pos.y>=0 and pos.y<18:
   _gem(Rect2(board.position+Vector2(pos.x*cell,pos.y*cell_h),
    Vector2(cell,cell_h)),falling.kind+1)
 var next_rect:Rect2=layout["next"]
 var hold_rect:Rect2=layout["hold"]
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
 for ring in shockwaves:
  var progress:float = float(ring["age"])/float(ring["duration"])
  var radius:float = 7.0+float(ring["radius"])*pow(progress,.62)
  var col:Color=ring["color"]
  col.a = maxf(0.0,(1.0-progress)*.79)
  draw_arc(ring["pos"],radius,0,TAU,52,col,4.4*(1.0-progress)+.6,true)
  if progress<.62:
   col.a *= .35
   draw_arc(ring["pos"],radius*.67,0,TAU,45,col,2.2,true)
 for heading in headlines:
  var pct:float = float(heading["age"])/1.15
  var color:Color=heading["color"]
  color.a=clampf((1.0-pct)*1.4,0,1)
  var pos:Vector2=heading["pos"]
  var message:String=heading["text"]
  var label_at:=pos-Vector2(150.0,0.0)
  _label(message,label_at+Vector2(1.6,2.0),20,Color(.14,.08,.27,color.a*.66),HORIZONTAL_ALIGNMENT_CENTER,300.0)
  _label(message,label_at,20,color,HORIZONTAL_ALIGNMENT_CENTER,300.0)

func _draw_fragments() -> void:
 # 4 distinct candy particles: glossy bubble / sprinkle / prism / sparkle.
 # Motion is deterministic once spawned and fully inside Godot CanvasItem.
 for f in fragments:
  var life:float=clampf(float(f["life"])/float(f["original"]),0,1)
  var color:Color=f["color"]
  color.a=life
  var center:Vector2=f["pos"]
  var size:float=float(f["radius"])*life
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


func _draw_modal(layout:Dictionary) -> void:
 var viewport:Vector2 = layout["viewport"]
 var game_height:float=float(layout["height"])
 draw_rect(Rect2(Vector2.ZERO,Vector2(viewport.x,game_height)),Color(.01,.015,.08,.75),true)
 var modal := Rect2(Vector2(viewport.x*.09,game_height*.34),
  Vector2(viewport.x*.82,222))
 _glass_panel(modal,Color("#222c79"),Color("#90f6ff"))
 var title := "PAUSED" if paused else "GAME OVER"
 _label(title,Vector2(modal.position.x,modal.position.y+56),26,
  Color("#fff2ff"),HORIZONTAL_ALIGNMENT_CENTER,modal.size.x)
 var score:int = puzzle.score if mode==0 else falling.score
 _label("SCORE  %d" % score,Vector2(modal.position.x,modal.position.y+88),
  16,Color("#cbe9ff"),HORIZONTAL_ALIGNMENT_CENTER,modal.size.x)
 var action := "▶ RESUME" if paused else "↻ PLAY AGAIN"
 _button(Rect2(modal.position+Vector2(27,107),Vector2(modal.size.x-54,36)),action,true)
 if paused:
  _button(Rect2(modal.position+Vector2(27,148),Vector2(modal.size.x-54,27)),"↻ NEW RUN",false,true)
 _button(Rect2(modal.position+Vector2(27,184),Vector2(modal.size.x-54,28)),"⌂  GALAXY HOME",false,true)

func _origin_from_position(pos:Vector2,centered:bool,board:Rect2,shape:Array) -> Vector2i:
 var cell:float = board.size.x/9.0
 var local:Vector2 = (pos-board.position)/cell
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
  elif mode==1 and not paused:
   match event.keycode:
    KEY_LEFT: _fall_move(-1)
    KEY_RIGHT: _fall_move(1)
    KEY_UP: _fall_rotate()
    KEY_DOWN: _fall_soft_drop()
    KEY_SPACE: _fall_hard_drop()
  queue_redraw()

func _press(pos:Vector2) -> void:
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
    selected = i
    audio.effect("pick")
    return

func _move_pointer(pos:Vector2) -> void:
 if not touching:
  return
 touch_at=pos
 if pos.distance_to(pressed_at)>11.0:
  dragging=true
  touch_moved=true
 if mode==1 and falling_touch_valid and not paused and not falling.over:
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
  if primary.has_point(pos):
   if paused:
    paused=false
   else:
    _restart_mode()
   audio.effect("tap")
  elif paused and restart.has_point(pos):
   paused=false
   _restart_mode()
   audio.effect("tap")
  queue_redraw()
  return
 if layout["progress"].has_point(pos):
  if progress.unlocked_themes()>1:
   visuals.set_theme(progress.active_theme+1 if progress.active_theme+1<progress.unlocked_themes() else 0)
   var theme_name:String=progress.cycle_theme()
   _announce(theme_name+" GALAXY",Vector2(layout["viewport"].x*.5,layout["height"]*.5),Color("#c4f8ff"))
   audio.effect("fever")
   _save_game()
  else:
   _announce("NEXT GALAXY AT LEVEL 4",Vector2(layout["viewport"].x*.5,layout["height"]*.5),Color("#bdeaff"))
  return
 if mode==0 and layout["bomb"].has_point(pos):
  if puzzle.bombs>0:
   bomb_armed=not bomb_armed
   selected=-1
   audio.effect("tap")
  else:
   _announce("BOMB: 5000 SCORE + 18 LINES",layout["board"].get_center(),Color("#ffe0a7"))
  return
 if layout["pause"].has_point(pos):
  paused=true
  audio.effect("tap")
  return
 if layout["audio"].has_point(pos):
  audio.toggle_sound()
  return
 if layout["music"].has_point(pos):
  audio.toggle_music("puzzle" if mode==0 else "falling")
  return
 if native_ads!=null and layout["privacy"].has_point(pos):
  native_ads.call("show_privacy_options")
  return
 if layout["mode_switch"].has_point(pos):
  mode=1-mode
  bomb_armed=false
  selected=-1
  paused=false
  falling_touch_valid=false
  fall_accum=0.0
  fall_display=Vector2(falling.active)
  fall_drawn_drops=falling.drops
  audio.effect("tap")
  audio.select_music("puzzle" if mode==0 else "falling")
  _save_game()
  return
 if mode==1 and layout["hold"].has_point(pos):
  if falling.hold_piece():
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

func _restart_mode() -> void:
 # Interstitials only after completed rounds; never on Pause/New Run.
 var completed:bool=(puzzle.over if mode==0 else falling.over)
 if completed and native_ads!=null:
  native_ads.call("maybe_show_interstitial")
 if mode==0:
  puzzle.reset()
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
   var target:=Vector2i(clampi(int((pos.x-board.position.x)/cell),0,8),
    clampi(int((pos.y-board.position.y)/cell),0,8))
   var removed:int=puzzle.detonate_bomb(target)
   if removed>0:
    bomb_armed=false
    selected=-1
    var impact:Vector2=board.position+Vector2((target.x+.5)*cell,(target.y+.5)*cell)
    audio.effect_for("puzzle","big_shatter")
    _burst(impact,55+removed*5,Color("#ff62db"))
    _announce("CANDY BOMB!  %d SWEETS" % removed,impact-Vector2(0,45),Color("#ffe7ff"))
    flash=.78
    shake=.46
    _save_game()
   else:
    _announce("TAP CANDY TO EXPLODE",board.get_center(),Color("#ffb6d8"))
  return
 var drop:Vector2 = pos-Vector2(0,52) if dragging else pos
 if selected>=0 and selected<puzzle.tray.size() and board.has_point(drop):
  var shape:Array = puzzle.tray[selected]
  if not shape.is_empty():
   var origin:Vector2i = _origin_from_position(drop,dragging,board,shape)
   if puzzle.place(selected,origin):
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
     _burst(board.get_center(),18+count,Color("#7ceaff"))
     var combo_message:String="CANDY COMBO x%d  +%d" % [puzzle.last_groups,puzzle.last_gained] if puzzle.last_groups>1 else "SWEET CLEAR  +%d" % puzzle.last_gained
     _announce(combo_message,board.get_center()+Vector2(0,-12),Color("#91f7ff"))
    if puzzle.fever_moves==5:
     audio.effect("fever")
     _burst(board.get_center(),33,Color("#ff7aff"))
     _announce("NOVA FEVER!",board.get_center(),Color("#ff95e7"))
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
 if falling.over:
  return
 falling.hard_drop()
 _fall_locked()
 fall_accum=0.0

func _fall_locked() -> void:
 progress.locked_falling_piece()
 if falling.last_lines>0:
  progress.cleared_lines(falling.last_lines,falling.combo)
  flash=.54
  shake=.31
  _burst(_layout()["board"].get_center(),20+falling.last_lines*9,Color("#86e8ff"))
  var falling_message:String="BLOCKFALL COMBO x%d  +%d" % [falling.last_lines,falling.last_gained] if falling.last_lines>1 else "QUANTUM CLEAR  +%d" % falling.last_gained
  _announce(falling_message,_layout()["board"].get_center(),Color("#b2f9ff"))
  audio.effect_for("falling","big_shatter" if falling.last_lines>=3 else "shatter")
 else:
  audio.effect_for("falling","lock")
 _reward_feedback(_layout()["board"].get_center())
 if falling.over:
  audio.effect("lose")
 _save_game()

func _release_falling(pos:Vector2,layout:Dictionary) -> void:
 if not falling_touch_valid or falling.over:
  return
 var board:Rect2=layout["board"]
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
 headlines.append({"text":message,"pos":at,"age":0.0,"color":color})
 if headlines.size()>5:
  headlines.pop_front()

func _burst(center:Vector2,count:int,color:Color) -> void:
 shockwaves.append({"pos":center,"color":color,"age":0.0,"duration":.68,"radius":160.0})
 if shockwaves.size()>9:
  shockwaves.pop_front()
 var gen:=RandomNumberGenerator.new()
 gen.randomize()
 var candy_colors=[
  Color("#ff3d85"),Color("#ffce2c"),Color("#23eaf5"),
  Color("#a950ff"),Color("#75ff57"),Color("#ff9632"),
  Color("#ffffff")]
 for i in count:
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
 if not FileAccess.file_exists("user://novagrid-godot-save.json"):
  return
 var f := FileAccess.open("user://novagrid-godot-save.json",FileAccess.READ)
 if f==null:
  return
 var data:Variant = JSON.parse_string(f.get_as_text())
 if not data is Dictionary:
  return
 if data.has("puzzle"):
  puzzle.load_state(data["puzzle"])
 if data.has("falling"):
  falling.restore(data["falling"])
 if data.has("progression") and data["progression"] is Dictionary:
  progress.restore(data["progression"])

func _save_game() -> void:
 if puzzle==null or falling==null:
  return
 var f := FileAccess.open("user://novagrid-godot-save.json",FileAccess.WRITE)
 if f:
  f.store_string(JSON.stringify({"puzzle":puzzle.save_state(),"falling":falling.snapshot(),"progression":progress.snapshot()}))
