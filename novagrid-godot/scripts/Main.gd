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
var saves_enabled:bool=true # QA scenes disable persistence to protect actual player saves.
var save_path:String="user://novagrid-godot-save.json"
var clock := 0.0
var banner_height := 0.0 # Reserved only after native ad renderer reports success.
var stars: Array = []
var fragments: Array = []
var shockwaves: Array = []
var headlines: Array = []
var flash := 0.0
var shake := 0.0

func _ready() -> void:
 puzzle = PuzzleScript.new()
 falling = FallingScript.new()
 var session:Node=get_node_or_null("/root/Session")
 audio=session.get("audio") if session!=null else null
 if audio==null:
  audio=AudioScript.new()
  add_child(audio)
 progress = ProgressionScript.new()
 font = ThemeDB.fallback_font
 visuals = VisualsScript.new()
 add_child(visuals)
 visuals.configure(GEM_COLORS)
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
 session=get_node_or_null("/root/Session")
 if session!=null:
  mode=clampi(int(session.get("start_mode")),0,1)
  audio.sounds_enabled=bool(session.get("sounds_enabled"))
  audio.music_enabled=bool(session.get("music_enabled"))
 audio.select_music("puzzle" if mode==0 else "falling")
 get_viewport().size_changed.connect(queue_redraw)
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
 var header_end:float=177.0
 var board:Rect2
 var tray:Array=[]
 var buttons:Array=[]
 var side_width:float=clampf(w*.194,65.0,85.0)
 if mode==0:
  # A real 9x9 glass grid and three unframed glowing crystal tray shapes.
  var tray_height:float=clampf(h*.082,60.0,81.0)
  var available:float=maxf(130.0,h-header_end-tray_height-126.0)
  var cell:float=maxf(2.0,minf((w-2.0*gutter-10.0)/9.0,available/9.0))
  var size:Vector2=Vector2(cell*9.0,cell*9.0)
  board=Rect2(Vector2((w-size.x)*.5,header_end+maxf(8.0,(available-size.y)*.34)),size)
  var tray_y:float=board.end.y+22.0
  var tray_w:float=(w-2.0*gutter-18.0)/3.0
  for i in 3:
   tray.append(Rect2(Vector2(gutter+i*(tray_w+9.0),tray_y),Vector2(tray_w,tray_height)))
 else:
  # Leave the real 10x18 board big, with playable NEXT and HOLD at right.
  var available:float=maxf(260.0,h-header_end-112.0)
  var cell:float=maxf(2.0,minf((w-3.0*gutter-side_width)/10.0,available/18.0))
  var size:Vector2=Vector2(cell*10.0,cell*18.0)
  board=Rect2(Vector2(gutter,header_end+maxf(4.0,(available-size.y)*.20)),size)
 var next_rect:=Rect2(Vector2(board.end.x+gutter,board.position.y+37.0),Vector2(side_width,96.0))
 var hold_rect:=Rect2(Vector2(board.end.x+gutter,board.position.y+187.0),Vector2(side_width,96.0))
 return {"viewport":viewport,"height":h,"gutter":gutter,
  "tabs":[],"board":board,"tray":tray,"buttons":buttons,
  "mode_switch":Rect2(gutter,12.0,43.0,43.0),
  "bomb":Rect2(w-gutter-61.0,146.0,61.0,30.0),
  "pause":Rect2(w-gutter-48.0,80.0,48.0,48.0),
  "audio":Rect2(gutter,round(h-101.0),36.0,34.0),
  "music":Rect2(gutter+42.0,round(h-101.0),36.0,34.0),
  "next":next_rect,"hold":hold_rect}

func _draw() -> void:
 var layout:Dictionary = _layout()
 _draw_sky(layout)
 _draw_header(layout)
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

func _draw_sky(layout:Dictionary) -> void:
 var bounds:Vector2=layout["viewport"]
 # Large decorative luminous planets, orbit rings and drifting stardust:
 # the original reference's visual setting, never a screenshot backdrop.
 _draw_cosmic_planet(Vector2(bounds.x*.035,68.0+sin(clock*.10)*6.0),31.0,Color("#8746ff"),Color("#d84dff"))
 _draw_cosmic_planet(Vector2(bounds.x*1.055,bounds.y*.76+cos(clock*.085)*9.0),74.0,Color("#205cc8"),Color("#6d35ff"))
 _draw_cosmic_planet(Vector2(bounds.x*.89,bounds.y*.22),17.0,Color("#fa3be8"),Color("#ff92e4"))
 for item in stars:
  var x:float=float(item["x"])*bounds.x+sin(clock*.11+float(item["phase"]))*5.0
  var y:float=fposmod(float(item["y"])*bounds.y+clock*(3.0+float(item["radius"])*2.3),bounds.y)
  var radius:float=float(item["radius"])
  var brightness:float=.40+.42*sin(clock*.87+float(item["phase"]))
  var col:=Color(.83,.91,1.0,clampf(brightness,.08,.90))
  draw_circle(Vector2(x,y),radius,col)
  if radius>1.22:
   draw_line(Vector2(x-3.0,y),Vector2(x+3.0,y),Color(.57,.73,1.0,.28),.8,true)
   draw_line(Vector2(x,y-3.0),Vector2(x,y+3.0),Color(.74,.54,1.0,.28),.8,true)
 # Two translucent swirls that glide behind the actual game board.
 var previous:=Vector2.ZERO
 for i in 85:
  var ratio:float=float(i)/84.0
  var angle:float=ratio*TAU
  var point:Vector2=Vector2(bounds.x*.52+cos(angle)*bounds.x*.94,
   bounds.y*.48+sin(angle)*bounds.y*.19)
  if i>0:
   draw_line(previous,point,Color(.65,.36,1.0,.075),1.5,true)
  previous=point

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

func _glass_panel(rect:Rect2,fill:Color=Color("#17225b"),outline:Color=Color("#7deaff")) -> void:
 var key:String=fill.to_html(true)+":"+outline.to_html(true)
 if not panel_styles.has(key):
  var panel := StyleBoxFlat.new()
  panel.bg_color=fill
  panel.border_color=outline
  panel.set_corner_radius_all(10)
  panel.set_border_width_all(1)
  panel.shadow_color=Color(.04,.25,.88,.24)
  panel.shadow_size=3
  panel_styles[key]=panel
 draw_style_box(panel_styles[key],rect)
 draw_line(rect.position+Vector2(11,2),Vector2(rect.end.x-11,rect.position.y+2),Color(1,1,1,.63),1.2,true)
 draw_line(rect.position+Vector2(11,4),Vector2(rect.end.x-11,rect.position.y+4),Color(.70,.88,1.0,.21),1.0,true)
 draw_circle(rect.position+Vector2(9,9),2.1,Color(1,1,1,.34))

func _button(rect:Rect2,title:String,active:bool=false,small:bool=false) -> void:
 var fill := Color(.13,.43,.78,.80) if active else Color(.15,.18,.45,.83)
 _glass_panel(rect,fill,Color("#a3f7ff") if active else Color("#859de8"))
 var fontsize:int = 12 if small else 14
 _label(title,Vector2(rect.position.x,rect.position.y+rect.size.y*.64),fontsize,
  Color.WHITE,HORIZONTAL_ALIGNMENT_CENTER,rect.size.x)

func _draw_header(layout:Dictionary) -> void:
 var w:float=layout["viewport"].x
 var g:float=layout["gutter"]
 var mode_name:String="Classic Puzzle" if mode==0 else "Blockfall"
 # Match the reference hierarchy: enormous luminous mode title, two score
 # capsules and a single sapphire glass pause button at the right.
 _label(mode_name,Vector2(1.2,42.0),29,Color(.12,.46,1.0,.56),HORIZONTAL_ALIGNMENT_CENTER,w)
 _label(mode_name,Vector2(0.0,40.0),29,Color("#f5fbff"),HORIZONTAL_ALIGNMENT_CENTER,w)
 _label("✦ 3D CANDY GALAXY ✦",Vector2(0,59),10,Color("#ffd3f1"),HORIZONTAL_ALIGNMENT_CENTER,w)
 var score:int=puzzle.score if mode==0 else falling.score
 var best:int=puzzle.best if mode==0 else falling.best
 var other:String="BEST" if mode==0 else "LEVEL"
 var other_value:String=str(best) if mode==0 else str(falling.level)
 var left_card:=Rect2(Vector2(g,77),Vector2((w-3.0*g-55.0)*.51,57))
 var right_card:=Rect2(Vector2(left_card.end.x+g,77),Vector2((w-3.0*g-55.0)*.49,57))
 _glass_panel(left_card,Color(.14,.075,.29,.94),Color(.84,.48,.92,.82))
 _glass_panel(right_card,Color(.075,.15,.34,.92),Color(.39,.81,1.0,.88))
 _label("SCORE",Vector2(left_card.position.x,left_card.position.y+17),11,Color("#f1e9ff"),HORIZONTAL_ALIGNMENT_CENTER,left_card.size.x)
 _label("%s" % score,Vector2(left_card.position.x,left_card.position.y+44),24,Color("#ffe7a4"),HORIZONTAL_ALIGNMENT_CENTER,left_card.size.x)
 _label(other,Vector2(right_card.position.x,right_card.position.y+17),11,Color("#ffe0a9"),HORIZONTAL_ALIGNMENT_CENTER,right_card.size.x)
 _label(other_value,Vector2(right_card.position.x,right_card.position.y+44),24,Color("#fff1c2"),HORIZONTAL_ALIGNMENT_CENTER,right_card.size.x)
 _button(layout["pause"],"▶" if paused else "Ⅱ",true,false)
 if mode==0:
  var progress_bar:=Rect2(Vector2(g,147),Vector2(w-2.0*g-73.0,9))
  draw_rect(progress_bar,Color("#24113d"),true)
  draw_rect(Rect2(progress_bar.position,Vector2(progress_bar.size.x*float(puzzle.fever)/100.0,progress_bar.size.y)),Color("#e953ff"),true)
  _label("FEVER  %d%%" % puzzle.fever,Vector2(g,171),9,Color("#f1b3ff"))
  var bomb:Rect2=layout["bomb"]
  _glass_panel(bomb,Color(.33,.07,.33,.85) if bomb_armed else Color(.15,.09,.40,.85),Color("#ff84de") if bomb_armed else Color("#b466ed"))
  _label("●  %s" % (str(puzzle.bombs) if puzzle.bombs>0 else "%d%%" % puzzle.bomb_charge()),
   Vector2(bomb.position.x,bomb.position.y+21),14,Color("#ffe6ad"),HORIZONTAL_ALIGNMENT_CENTER,bomb.size.x)
  _label("COMBO x%d  •  LINES %d" % [puzzle.combo,puzzle.total_lines],Vector2(g+75,171),10,Color("#fff1a2"))
 else:
  _label("COMBO x%d  •  LINES %d" % [falling.combo,falling.lines],Vector2(g,170),12,Color("#ff9dff"))

func _draw_progress_hud(layout:Dictionary) -> void:
 var w:float=layout["viewport"].x
 var g:float=layout["gutter"]
 var y:float=layout["height"]-54.0
 var rect:=Rect2(g,y,w-2.0*g,46.0)
 _glass_panel(rect,Color(.08,.14,.34,.81),Color("#70cfff"))
 var rank:String=progress.rank_name()
 _label("LV %d • %s" % [progress.level,rank],Vector2(rect.position.x+12,y+17),12,Color("#dcfaff"))
 _label("★ %d  |  STREAK %d" % [progress.stars,progress.streak],Vector2(rect.position.x, y+17),10,Color("#ffdc87"),HORIZONTAL_ALIGNMENT_RIGHT,rect.size.x-12)
 var track:=Rect2(rect.position+Vector2(12,23),Vector2(rect.size.x-24,5))
 draw_rect(track,Color("#273366"),true)
 draw_rect(Rect2(track.position,Vector2(track.size.x*progress.level_progress(),track.size.y)),Color("#64f1ff"),true)
 var mission:Dictionary=progress.next_mission()
 _label("%s  %d/%d   ·   %s GALAXY (TAP)" % [mission["label"],mission["progress"],mission["target"],progress.theme_name()],Vector2(rect.position.x+12,y+41),9,Color("#b7daff"))

func _draw_tabs(layout:Dictionary) -> void:
 # A single compact mode switch avoids breaking the hero-screen composition.
 # No directional or on-board movement arrows.
 _button(layout["mode_switch"],"▦" if mode==0 else "✦",false,true)
 _button(layout["audio"],"♪" if audio.sounds_enabled else "×",false,true)
 _button(layout["music"],"♫" if audio.music_enabled else "○",false,true)


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
 var outer:=Rect2(board_rect.position-Vector2(4,4),board_rect.size+Vector2(8,8))
 # Multi-layer neon glass frame with blue-white corner lighting.
 draw_rect(outer.grow(5.0),Color(.08,.46,1.0,.12),false,5.0)
 draw_rect(outer.grow(2.5),Color(.12,.58,1.0,.21),false,3.0)
 _glass_panel(outer,Color(.056,.031,.14,.85),Color("#ba93ff"))
 draw_rect(board_rect,Color(.014,.017,.070,.48),true)
 var cell:float=board_rect.size.x/float(cols)
 for y in rows:
  for x in cols:
   var rect:=Rect2(board_rect.position+Vector2(x*cell,y*cell),Vector2(cell,cell))
   draw_rect(rect.grow(-.5),Color(.13,.16,.32,.63),true)
   draw_rect(rect.grow(-.75),Color(.43,.39,.70,.36),false,.85)
 draw_line(outer.position,Vector2(outer.end.x,outer.position.y),Color("#78f1ff"),2.0,true)
 draw_line(Vector2(outer.position.x,outer.end.y),outer.end,Color("#77dbff"),1.8,true)
 for corner in [outer.position,Vector2(outer.end.x,outer.position.y),outer.end,Vector2(outer.position.x,outer.end.y)]:
  draw_circle(corner,2.7,Color("#d3faff"))
  draw_circle(corner,6.2,Color(.19,.75,1.0,.10))
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
    var tile:=Rect2(board.position+Vector2(xx*cell,yy*cell),Vector2(cell,cell))
    draw_rect(tile.grow(-1),Color(.99,.26,.79,.40 if puzzle.cells[yy][xx]>0 else .16),true)
    draw_rect(tile.grow(-1),Color("#ff9eec"),false,1.4)
 if selected>=0 and selected<puzzle.tray.size() and not puzzle.tray[selected].is_empty():
  var near:Vector2=touch_at-Vector2(0,52) if dragging else touch_at
  if board.has_point(near):
   var origin:Vector2i=_origin_from_position(near,dragging,board,puzzle.tray[selected])
   if puzzle.fits(puzzle.tray[selected],origin):
    var preview_color:int=int(puzzle.tray_colors[selected])
    for p in puzzle.tray[selected]:
     var q:Vector2i=origin+p
     _gem(Rect2(board.position+Vector2(q.x*cell,q.y*cell),Vector2(cell,cell)),preview_color,true)
 # Three freestanding, very glossy and vividly colored crystals as the collage.
 var colors:Array=puzzle.tray_colors
 for i in 3:
  var tray_rect:Rect2=layout["tray"][i]
  var highlight:Color=GEM_COLORS[colors[i]]
  if i==selected:
   draw_rect(tray_rect.grow(1.0),Color(highlight.r,highlight.g,highlight.b,.17),true)
   draw_rect(tray_rect,Color(highlight.r,highlight.g,highlight.b,.85),false,1.7)
  var shape:Array=puzzle.tray[i]
  if shape.is_empty():
   continue
  var bounds:Vector2i=puzzle.shape_size(shape)
  var micro:float=minf((tray_rect.size.x-8.0)/float(bounds.x),(tray_rect.size.y-4.0)/float(bounds.y))
  micro=minf(micro,30.0)
  var offset:Vector2=tray_rect.position+(tray_rect.size-Vector2(micro*bounds.x,micro*bounds.y))*.5
  for p in shape:
   _gem(Rect2(offset+Vector2(p.x*micro,p.y*micro),Vector2(micro,micro)),colors[i])
 _label("CLEAR ROWS • COLUMNS • 3×3 SECTORS",Vector2(0,layout["height"]-117.0),11,Color("#e4d4ff"),HORIZONTAL_ALIGNMENT_CENTER,layout["viewport"].x)
 if dragging and selected>=0 and not puzzle.tray[selected].is_empty():
  var s:Array=puzzle.tray[selected]
  var shape_size:Vector2i=puzzle.shape_size(s)
  var left:Vector2=visual_pointer-Vector2(shape_size.x*cell*.5,shape_size.y*cell*.5+54)
  for p in s:
   _gem(Rect2(left+Vector2(p.x*cell,p.y*cell),Vector2(cell,cell)),colors[selected],true)

func _draw_falling(layout:Dictionary) -> void:
 var board:Rect2=layout["board"]
 var cell:float=_board_back(board,10,18)
 var ghost:Vector2i=Vector2i(falling.active.x,falling.ghost_row())
 for y in 18:
  for x in 10:
   var id:int=falling.cell_at(x,y)
   if id>0:
    _gem(Rect2(board.position+Vector2(x*cell,y*cell),Vector2(cell,cell)),id)
 for p in falling.piece:
  var pos:Vector2i=ghost+p
  if pos.y>=0 and pos.y<18 and falling.board[pos.y][pos.x]==0:
   _gem(Rect2(board.position+Vector2(pos.x*cell,pos.y*cell),Vector2(cell,cell)),falling.kind+1,true)
 for p in falling.piece:
  var pos:Vector2=fall_display+Vector2(p)
  if pos.y>=0 and pos.y<18:
   _gem(Rect2(board.position+Vector2(pos.x*cell,pos.y*cell),Vector2(cell,cell)),falling.kind+1)
 # Real reference-style NEXT and HOLD panels at the right, not a fake preview.
 var next_rect:Rect2=layout["next"]
 var hold_rect:Rect2=layout["hold"]
 _label("NEXT",Vector2(next_rect.position.x,next_rect.position.y-10),15,Color("#f2f5ff"),HORIZONTAL_ALIGNMENT_CENTER,next_rect.size.x)
 _glass_panel(next_rect,Color(.03,.04,.15,.93),Color("#ffb348"))
 _draw_side_piece(next_rect,falling.next_kind)
 _label("HOLD",Vector2(hold_rect.position.x,hold_rect.position.y-10),15,Color("#f2f5ff"),HORIZONTAL_ALIGNMENT_CENTER,hold_rect.size.x)
 _glass_panel(hold_rect,Color(.03,.04,.15,.93),Color("#4adaff"))
 if falling.hold_kind>=0:
  _draw_side_piece(hold_rect,falling.hold_kind)
 if falling.hold_used:
  draw_rect(hold_rect.grow(-2),Color(.06,.09,.20,.47),true)
 var combo_rect:=Rect2(Vector2(next_rect.position.x,hold_rect.end.y+39.0),Vector2(next_rect.size.x,85.0))
 _glass_panel(combo_rect,Color(.27,.04,.32,.74),Color("#f34ce1"))
 _label("COMBO",Vector2(combo_rect.position.x,combo_rect.position.y+28),14,Color("#ffbbfb"),HORIZONTAL_ALIGNMENT_CENTER,combo_rect.size.x)
 _label("x%d" % falling.combo,Vector2(combo_rect.position.x,combo_rect.position.y+68),30,Color("#fff4ba"),HORIZONTAL_ALIGNMENT_CENTER,combo_rect.size.x)
 _label("SWIPE ↔  MOVE    TAP  ROTATE    SWIPE ↓  DROP",Vector2(0,layout["height"]-117.0),9,Color("#dccfff"),HORIZONTAL_ALIGNMENT_CENTER,layout["viewport"].x)

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
 draw_rect(Rect2(Vector2.ZERO,viewport),Color(.01,.015,.08,.75),true)
 var modal := Rect2(Vector2(viewport.x*.09,viewport.y*.34),
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
   if not (mode==0 and puzzle.over) and not (mode==1 and falling.over):
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
  var modal:=Rect2(Vector2(viewport.x*.09,viewport.y*.34),Vector2(viewport.x*.82,222.0))
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
 if Rect2(Vector2(layout["gutter"],layout["height"]-54.0),Vector2(layout["viewport"].x-2.0*layout["gutter"],46.0)).has_point(pos):
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
  _save_audio_settings()
  return
 if layout["music"].has_point(pos):
  audio.toggle_music("puzzle" if mode==0 else "falling")
  _save_audio_settings()
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

func _read_snapshot(path:String) -> Dictionary:
 if not FileAccess.file_exists(path):
  return {}
 # JSON.parse_string prints an engine ERROR on truncated files; use the
 # result-code parser so a recoverable save never produces a fatal-looking log.
 var decoder:=JSON.new()
 if decoder.parse(FileAccess.get_file_as_string(path))!=OK:
  return {}
 var data:Variant=decoder.data
 if data is Dictionary and data.has("puzzle") and data.has("falling"):
  return data
 return {}

func _load_game() -> void:
 if not saves_enabled:
  return
 var data:Dictionary=_read_snapshot(save_path)
 if data.is_empty():
  # A truncated last write must not destroy the previous good snapshot.
  data=_read_snapshot(save_path+".bak")
 if data.is_empty():
  return
 if data.has("puzzle") and data["puzzle"] is Dictionary:
  puzzle.load_state(data["puzzle"])
 if data.has("falling") and data["falling"] is Dictionary:
  falling.restore(data["falling"])
 if data.has("progression") and data["progression"] is Dictionary:
  progress.restore(data["progression"])

func _save_audio_settings() -> void:
 var session:Node=get_node_or_null("/root/Session")
 if session!=null:
  session.call("update_audio_settings",audio.sounds_enabled,audio.music_enabled)

func _save_game() -> void:
 if not saves_enabled or puzzle==null or falling==null or progress==null:
  return
 var payload:String=JSON.stringify({
  "puzzle":puzzle.save_state(),
  "falling":falling.snapshot(),
  "progression":progress.snapshot()
 })
 var temporary_path:String=save_path+".tmp"
 var tmp:FileAccess=FileAccess.open(temporary_path,FileAccess.WRITE)
 if tmp==null:
  push_warning("NovaGrid could not open temporary save file.")
  return
 tmp.store_string(payload)
 tmp.flush()
 tmp=null # Close before moving the file, including on Windows.
 var primary_absolute:String=ProjectSettings.globalize_path(save_path)
 var temporary_absolute:String=ProjectSettings.globalize_path(temporary_path)
 if not _read_snapshot(save_path).is_empty():
  var backup_error:int=DirAccess.copy_absolute(
   primary_absolute,ProjectSettings.globalize_path(save_path+".bak"))
  if backup_error!=OK:
   push_warning("NovaGrid could not refresh backup: %d" % backup_error)
 var move_error:int=DirAccess.rename_absolute(temporary_absolute,primary_absolute)
 if move_error!=OK:
  # Never delete the previous save to force an overwrite. The existing
  # primary/backup remains usable and the .tmp is available for recovery.
  push_warning("NovaGrid could not finalize save: %d" % move_error)
