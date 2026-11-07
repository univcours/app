extends Node2D
## NovaGrid native Godot 4.5 game UI.
## Gameplay, glass blocks, drag/drop, visual FX, saves and sounds run on Godot.
const PuzzleScript = preload("res://scripts/Puzzle.gd")
const FallingScript = preload("res://scripts/Falling.gd")
const AudioScript = preload("res://scripts/Audio.gd")
const VisualsScript = preload("res://scripts/Visuals.gd")
const ProgressionScript = preload("res://scripts/Progression.gd")

const GEM_COLORS = [
 Color("#192850"), Color("#ff46af"), Color("#ffcc3b"), Color("#31d9fa"),
 Color("#a866ff"), Color("#21eda3"), Color("#ff9147"), Color("#4fa5ff")
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
var fall_accum := 0.0
var save_clock := 0.0
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
 audio = AudioScript.new()
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
 var gen := RandomNumberGenerator.new()
 gen.seed = 20261106
 for i in 110:
  stars.append({"x": gen.randf(), "y": gen.randf(),
   "radius": gen.randf_range(0.4,1.7), "phase": gen.randf_range(0,TAU)})
 audio.select_music("puzzle")
 get_viewport().size_changed.connect(queue_redraw)
 set_process(true)
 queue_redraw()

func _process(delta:float) -> void:
 clock += delta
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
  f["speed"] = Vector2(f["speed"])*(1.0-delta*1.1)
  if float(f["life"])<=0.0:
   fragments.remove_at(idx)
  else:
   fragments[idx] = f
 if mode==1 and not paused and not falling.over:
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
 var viewport:Vector2 = get_viewport_rect().size
 var w:float = viewport.x
 var h:float = viewport.y-banner_height
 var gutter:float = clampf(w*0.027,7.0,16.0)
 var half:float = (w-3.0*gutter)/2.0
 var tabs := [Rect2(gutter,61,half,39),Rect2(gutter*2.0+half,61,half,39)]
 var header_end:float = 151.0
 var board:Rect2
 var tray:Array = []
 var buttons:Array = []
 if mode==0:
  var tray_height:float = clampf(h*0.083,58,76)
  var playable_height:float = maxf(150,h-header_end-tray_height-84)
  var cell:float = maxf(2.0,minf((w-2*gutter-9.0)/10.0,playable_height/12.0))
  var board_size := Vector2(cell*10.0,cell*12.0)
  var surplus:float = maxf(0.0,playable_height-board_size.y)
  board = Rect2(Vector2((w-board_size.x)/2.0,header_end+surplus*0.34),board_size)
  var tray_y:float = board.end.y+12.0
  var tray_w:float = (w-2*gutter-12)/3.0
  for i in 3:
   tray.append(Rect2(Vector2(gutter+i*(tray_w+6),tray_y),Vector2(tray_w,tray_height)))
 else:
  # Falling-block play uses direct gestures only; no directional controls.
  var available:float = maxf(170,h-header_end-73)
  var cell:float = maxf(2.0,minf((w-2*gutter-10)/10.0,available/18.0))
  var board_size := Vector2(cell*10,cell*18)
  board = Rect2(Vector2((w-board_size.x)*.5,header_end+maxf(0,available-board_size.y)*.28),board_size)

 return {"viewport":viewport,"height":h,"gutter":gutter,
  "tabs":tabs,"board":board,"tray":tray,"buttons":buttons,
  "pause":Rect2(w-45,10,34,35),"audio":Rect2(10,10,34,35),
  "music":Rect2(49,10,34,35)}

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
 # The real galaxy/nebula is rendered by GPU shader behind this CanvasItem.
 # These deterministic orbiting stars add crisp foreground parallax.
 var bounds:Vector2 = layout["viewport"]
 for item in stars:
  var x:float = float(item["x"])*bounds.x+sin(clock*.11+float(item["phase"]))*4.0
  var y:float = fposmod(float(item["y"])*bounds.y+clock*(3.0+float(item["radius"])*2.3),bounds.y)
  var brightness:float = .33+.47*sin(clock*.87+float(item["phase"]))
  draw_circle(Vector2(x,y),float(item["radius"]),Color(.74,.91,1.0,maxf(.11,brightness)))
 var center := Vector2(bounds.x*.49,bounds.y*.37)
 var previous := Vector2.ZERO
 for i in 81:
  var angle:float = float(i)/80.0*TAU
  var point := center+Vector2(cos(angle)*bounds.x*.81,sin(angle)*bounds.y*.15)
  if i>0:
   draw_line(previous,point,Color(.31,.66,1.0,.065),1.2,true)
  previous=point

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
 var w:float = layout["viewport"].x
 _label("N O V A G R I D",Vector2(0,39),25,Color(.12,.72,1.0,.52),HORIZONTAL_ALIGNMENT_CENTER,w)
 _label("N O V A G R I D",Vector2(0,37),25,Color("#f1f6ff"),HORIZONTAL_ALIGNMENT_CENTER,w)
 _button(layout["pause"],"▶" if paused else "Ⅱ",false,true)
 _button(layout["audio"],"♪" if audio.sounds_enabled else "×",false,true)
 _button(layout["music"],"♫" if audio.music_enabled else "○",false,true)
 _label("COSMIC GLASS ARCADE",Vector2(0,55),9,Color("#9eaeeb"),HORIZONTAL_ALIGNMENT_CENTER,w)
 var label:String = "SCORE"
 var value:int = puzzle.score if mode==0 else falling.score
 var combo:int = puzzle.combo if mode==0 else falling.combo
 var best:int = puzzle.best if mode==0 else falling.best
 _label("%s  %d" % [label,value],Vector2(15,122),17,Color("#ecfbff"))
 _label("BEST %d" % best,Vector2(w*.48,122),11,Color("#b5cdfd"))
 _label("COMBO x%d" % combo,Vector2(w-111,140),11,Color("#ffe3ff"))
 if mode==0:
  var progress:float = float(puzzle.fever)/100.0
  draw_rect(Rect2(Vector2(13,132),Vector2(w*.37,4)),Color("#192654"),true)
  draw_rect(Rect2(Vector2(13,132),Vector2(w*.37*progress,4)),Color("#fc78dc"),true)
  _label("FEVER",Vector2(13,146),8,Color("#eed6ff"))
 else:
  _label("LINES %d   LV %d" % [falling.lines,falling.level],Vector2(13,143),11,Color("#b7d8fb"))

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
 _label("%s   %d/%d" % [mission["label"],mission["progress"],mission["target"]],Vector2(rect.position.x+12,y+41),9,Color("#b7daff"))

func _draw_tabs(layout:Dictionary) -> void:
 var titles := ["✦  BLOCK PUZZLE","▦  BLOCKFALL"]
 for i in 2:
  _button(layout["tabs"][i],titles[i],i==mode,true)

func _gem(rect:Rect2,color_id:int,ghost:bool=false) -> void:
 if color_id<=0:
  return
 var base:Color=GEM_COLORS[clampi(color_id,1,GEM_COLORS.size()-1)]
 if ghost:
  var faded:Color=Color(base.r,base.g,base.b,.13)
  draw_rect(rect.grow(-2.0),faded,true)
  draw_rect(rect.grow(-1.0),Color(base.r,base.g,base.b,.74),false,1.6)
  return
 var inset := rect.grow(-.65)
 var texture:Texture2D=visuals.get_gem_texture(color_id) if visuals else null
 # GPU shader gives each crystal its curved transparent-looking shell,
 # volumetric light, animated internal caustics and rounded reflections.
 if texture!=null:
  draw_texture_rect(texture,inset,false,Color.WHITE)
 else:
  draw_style_box(gem_styles[clampi(color_id,1,gem_styles.size()-1)],inset)
 # Custom bright glints in the UI layer keep small gems sharp.
 if rect.size.x>16.0:
  var star:=rect.position+Vector2(rect.size.x*.28,rect.size.y*.22)
  draw_line(star-Vector2(2.6,0),star+Vector2(2.6,0),Color(1,1,1,.45),.72,true)
  draw_line(star-Vector2(0,2.6),star+Vector2(0,2.6),Color(1,1,1,.36),.72,true)

func _board_back(board_rect:Rect2,cols:int,rows:int) -> float:
 _glass_panel(Rect2(board_rect.position-Vector2(4,4),board_rect.size+Vector2(8,8)),
  Color(.055,.078,.19,.96),Color("#74ddff"))
 var cell:float = board_rect.size.x/float(cols)
 for y in rows:
  for x in cols:
   var rect := Rect2(board_rect.position+Vector2(x*cell,y*cell),Vector2(cell,cell))
   draw_rect(Rect2(rect.position+Vector2(.9,.9),rect.size-Vector2(1.8,1.8)),Color(.14,.19,.39,.76),true)
   draw_rect(rect,Color(.33,.36,.62,.22),false,.6)
 return cell

func _draw_puzzle(layout:Dictionary) -> void:
 var board:Rect2 = layout["board"]
 var cell:float = _board_back(board,10,12)
 for y in 12:
  for x in 10:
   var id:int = int(puzzle.cells[y][x])
   if id>0:
    _gem(Rect2(board.position+Vector2(x*cell,y*cell),Vector2(cell,cell)),id)
 if selected>=0 and selected<puzzle.tray.size() and not puzzle.tray[selected].is_empty():
  var near:Vector2 = touch_at-Vector2(0,52) if dragging else touch_at
  if board.has_point(near):
   var origin:Vector2i = _origin_from_position(near,dragging,board,puzzle.tray[selected])
   if puzzle.fits(puzzle.tray[selected],origin):
    var marker:int = 1+(puzzle.moves+selected*2)%6
    for p in puzzle.tray[selected]:
     var q:Vector2i = origin+p
     _gem(Rect2(board.position+Vector2(q.x*cell,q.y*cell),Vector2(cell,cell)),marker,true)
 for i in 3:
  var tray_rect:Rect2 = layout["tray"][i]
  _glass_panel(tray_rect,Color(.12,.14,.38,.85),
   Color("#f9c4ff") if i==selected else Color("#5e86d1"))
  var shape:Array = puzzle.tray[i]
  if shape.is_empty():
   continue
  var bounds:Vector2i = puzzle.shape_size(shape)
  var micro:float = minf((tray_rect.size.x-8)/float(bounds.x),(tray_rect.size.y-9)/float(bounds.y))
  micro = minf(micro,20)
  var offset := tray_rect.position+(tray_rect.size-Vector2(micro*bounds.x,micro*bounds.y))*.5
  var gem_color:int = 1+(puzzle.moves+i*2)%6
  for p in shape:
   _gem(Rect2(offset+Vector2(p.x*micro,p.y*micro),Vector2(micro,micro)),gem_color)
 _label("DRAG OR TAP A CRYSTAL INTO THE GRID",Vector2(0,layout["height"]-67.0),10,Color("#c6dbfa"),HORIZONTAL_ALIGNMENT_CENTER,layout["viewport"].x)
 if dragging and selected>=0 and not puzzle.tray[selected].is_empty():
  var s:Array = puzzle.tray[selected]
  var shape_size:Vector2i = puzzle.shape_size(s)
  var left:Vector2 = visual_pointer-Vector2(shape_size.x*cell*.5,shape_size.y*cell*.5+54)
  for p in s:
   _gem(Rect2(left+Vector2(p.x*cell,p.y*cell),Vector2(cell,cell)),1+(puzzle.moves+selected*2)%6,true)

func _draw_falling(layout:Dictionary) -> void:
 var board:Rect2 = layout["board"]
 var cell:float = _board_back(board,10,18)
 var ghost:Vector2i = Vector2i(falling.active.x,falling.ghost_row())
 for y in 18:
  for x in 10:
   var id:int = falling.cell_at(x,y)
   if id>0:
    _gem(Rect2(board.position+Vector2(x*cell,y*cell),Vector2(cell,cell)),id)
 for p in falling.piece:
  var pos:Vector2i = ghost+p
  if pos.y>=0 and pos.y<18 and falling.board[pos.y][pos.x]==0:
   _gem(Rect2(board.position+Vector2(pos.x*cell,pos.y*cell),Vector2(cell,cell)),falling.kind+1,true)
 for p in falling.piece:
  var pos:Vector2i = falling.active+p
  if pos.y>=0 and pos.y<18:
   _gem(Rect2(board.position+Vector2(pos.x*cell,pos.y*cell),Vector2(cell,cell)),falling.kind+1)
 # Compact next-piece preview sits BESIDE the small HUD, outside the board.
 _label("NEXT",Vector2(board.end.x-31,143),9,Color("#bcefff"))
 var preview: Array = falling.FORMS[falling.next_kind]
 for raw in preview:
  var q := Vector2(int(raw[0]),int(raw[1]))
  _gem(Rect2(Vector2(board.end.x-76,149)+q*12,Vector2(12,12)),falling.next_kind+1)
 _label("TAP  ROTATE    SWIPE  MOVE / DROP    HOLD  SOFT DROP",Vector2(0,layout["height"]-68.0),9,Color("#c6dbfa"),HORIZONTAL_ALIGNMENT_CENTER,layout["viewport"].x)

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
 for f in fragments:
  var life:float = clampf(float(f["life"])/float(f["original"]),0,1)
  var color:Color = f["color"]
  color.a = life
  var loc:Vector2 = f["pos"]
  var size:float = float(f["radius"])*life
  draw_rect(Rect2(loc-Vector2.ONE*size,Vector2.ONE*size*2),color,true)

func _draw_modal(layout:Dictionary) -> void:
 var viewport:Vector2 = layout["viewport"]
 draw_rect(Rect2(Vector2.ZERO,viewport),Color(.01,.015,.08,.75),true)
 var modal := Rect2(Vector2(viewport.x*.09,viewport.y*.34),
  Vector2(viewport.x*.82,180))
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

func _origin_from_position(pos:Vector2,centered:bool,board:Rect2,shape:Array) -> Vector2i:
 var cell:float = board.size.x/10.0
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
  var modal:=Rect2(Vector2(viewport.x*.09,viewport.y*.34),Vector2(viewport.x*.82,180.0))
  var primary:=Rect2(modal.position+Vector2(27,107),Vector2(modal.size.x-54,36))
  var restart:=Rect2(modal.position+Vector2(27,148),Vector2(modal.size.x-54,27))
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
 for i in 2:
  if layout["tabs"][i].has_point(pos):
   if mode!=i:
    mode=i
    selected=-1
    paused=false
    fall_accum=0
    audio.effect("tap")
    audio.select_music("puzzle" if mode==0 else "falling")
    _save_game()
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
 else:
  falling.reset()
  fall_accum=0
 _save_game()

func _release_puzzle(pos:Vector2,layout:Dictionary) -> void:
 var board:Rect2 = layout["board"]
 var drop:Vector2 = pos-Vector2(0,52) if dragging else pos
 if selected>=0 and selected<puzzle.tray.size() and board.has_point(drop):
  var shape:Array = puzzle.tray[selected]
  if not shape.is_empty():
   var origin:Vector2i = _origin_from_position(drop,dragging,board,shape)
   if puzzle.place(selected,origin):
    var count:int = puzzle.last_cleared
    audio.effect_for("puzzle","big_shatter" if count>10 else "shatter" if count>0 else "place")
    progress.placed_piece()
    if count>0:
     var cleared_groups:int=maxi(1,int(count/10))
     progress.cleared_lines(cleared_groups,puzzle.combo)
    _reward_feedback(board.get_center())
    if count>0:
     flash=.28 if count<20 else .7
     shake=.25
     _burst(board.get_center(),18+count,Color("#7ceaff"))
     _announce("CRYSTAL COMBO x%d" % puzzle.combo,board.get_center()+Vector2(0,-12),Color("#91f7ff"))
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
  _announce("QUANTUM CLEAR!",_layout()["board"].get_center(),Color("#b2f9ff"))
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
 shockwaves.append({"pos":center,"color":color,"age":0.0,"duration":.6,"radius":125.0})
 if shockwaves.size()>9:
  shockwaves.pop_front()
 var gen := RandomNumberGenerator.new()
 gen.randomize()
 for i in count:
  var angle:float = gen.randf_range(0,TAU)
  var velocity:Vector2 = Vector2(cos(angle),sin(angle))*gen.randf_range(55,200)
  fragments.append({"pos":center,"speed":velocity,
   "life":gen.randf_range(.25,.65),"original":.65,
   "radius":gen.randf_range(2.2,5.1),"color":color})

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
