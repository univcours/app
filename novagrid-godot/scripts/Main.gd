extends Node2D
## NovaGrid native Godot 4.5 game UI.
## Gameplay, glass blocks, drag/drop, visual FX, saves and sounds run on Godot.
const PuzzleScript = preload("res://scripts/Puzzle.gd")
const FallingScript = preload("res://scripts/Falling.gd")
const AudioScript = preload("res://scripts/Audio.gd")

const GEM_COLORS = [
 Color("#192850"), Color("#ff46af"), Color("#ffcc3b"), Color("#31d9fa"),
 Color("#a866ff"), Color("#21eda3"), Color("#ff9147"), Color("#4fa5ff")
]
const SKY = Color("#070923")
var puzzle
var falling
var audio
var font: Font
var mode := 0
var paused := false
var selected := -1
var touching := false
var dragging := false
var pressed_at := Vector2.ZERO
var touch_at := Vector2.ZERO
var fall_accum := 0.0
var save_clock := 0.0
var clock := 0.0
var banner_height := 0.0 # Reserved only after native ad renderer reports success.
var stars: Array = []
var fragments: Array = []
var flash := 0.0
var shake := 0.0

func _ready() -> void:
 puzzle = PuzzleScript.new()
 falling = FallingScript.new()
 audio = AudioScript.new()
 add_child(audio)
 font = ThemeDB.fallback_font
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
 flash = maxf(0.0,flash-delta*2.1)
 shake = maxf(0.0,shake-delta*3.0)
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
  var controls_height:float = 36
  var playable_height:float = maxf(150,h-header_end-tray_height-controls_height-44)
  var cell:float = maxf(2.0,minf((w-2*gutter-9.0)/10.0,playable_height/12.0))
  var board_size := Vector2(cell*10.0,cell*12.0)
  var surplus:float = maxf(0.0,playable_height-board_size.y)
  board = Rect2(Vector2((w-board_size.x)/2.0,header_end+surplus*0.34),board_size)
  var tray_y:float = board.end.y+12.0
  var tray_w:float = (w-2*gutter-12)/3.0
  for i in 3:
   tray.append(Rect2(Vector2(gutter+i*(tray_w+6),tray_y),Vector2(tray_w,tray_height)))
  var actions_y:float = minf(h-42,tray_y+tray_height+8)
  buttons = [
   Rect2(gutter,actions_y,(w-3*gutter)/2.0,33),
   Rect2(2*gutter+(w-3*gutter)/2.0,actions_y,(w-3*gutter)/2.0,33)]
 else:
  var available:float = maxf(170,h-header_end-82)
  var cell:float = maxf(2.0,minf((w-2*gutter-10)/10.0,available/18.0))
  var board_size := Vector2(cell*10,cell*18)
  board = Rect2(Vector2((w-board_size.x)*0.5,header_end+maxf(0,available-board_size.y)*0.3),board_size)
  var control_y:float = minf(h-49,board.end.y+8.0)
  var control_width:float = (w-2*gutter-12.0)/4.0
  for i in 4:
   buttons.append(Rect2(gutter+i*(control_width+4),control_y,control_width,43))
 return {"viewport":viewport,"height":h,"gutter":gutter,
  "tabs":tabs,"board":board,"tray":tray,"buttons":buttons,
  "pause":Rect2(w-45,10,34,35),"audio":Rect2(10,10,34,35),
  "music":Rect2(49,10,34,35)}

func _draw() -> void:
 var layout:Dictionary = _layout()
 _draw_sky(layout)
 _draw_header(layout)
 _draw_tabs(layout)
 if mode==0:
  _draw_puzzle(layout)
 else:
  _draw_falling(layout)
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
 var bounds:Vector2 = layout["viewport"]
 draw_rect(Rect2(Vector2.ZERO,bounds),SKY,true)
 # Vivid but low-contrast nebula under the gameplay board.
 for i in 14:
  var radius:float = 220.0-float(i)*11.0
  var center := Vector2(bounds.x*0.1+sin(clock*0.06)*13,bounds.y*0.20)
  draw_circle(center,radius,Color(0.24,0.12,0.62,0.009))
  center = Vector2(bounds.x*0.9+cos(clock*0.07)*18,bounds.y*0.72)
  draw_circle(center,radius,Color(0.08,0.38,0.91,0.009))
  center = Vector2(bounds.x*.55,bounds.y*.93)
  draw_circle(center,radius,Color(.72,.14,.68,.006))
 for item in stars:
  var x:float = float(item["x"])*bounds.x
  var y:float = fposmod(float(item["y"])*bounds.y+clock*(4.0+float(item["radius"])*3.0),bounds.y)
  var brightness:float = .55+.32*sin(clock*1.3+float(item["phase"]))
  draw_circle(Vector2(x,y),float(item["radius"]),Color(.79,.89,1.0,brightness))
 # Moving stellar orbit.
 var center := Vector2(bounds.x*.49,bounds.y*.34)
 var previous := Vector2.ZERO
 for i in 81:
  var angle:float = float(i)/80.0*TAU
  var point := center+Vector2(cos(angle)*bounds.x*.77,sin(angle)*bounds.y*.15)
  if i>0:
   draw_line(previous,point,Color(.19,.66,.96,.085),1.2,true)
  previous=point

func _label(text:String,pos:Vector2,size:int=16,color:Color=Color.WHITE,
 alignment:HorizontalAlignment=HORIZONTAL_ALIGNMENT_LEFT,width:float=-1.0) -> void:
 draw_string(font,pos,text,alignment,width,size,color)

func _glass_panel(rect:Rect2,fill:Color=Color("#17225b"),outline:Color=Color("#7deaff")) -> void:
 draw_rect(rect,Color("#050923"),true)
 draw_rect(Rect2(rect.position+Vector2(1,1),rect.size-Vector2(2,2)),fill,true)
 draw_rect(rect,outline,false,1.5)
 draw_line(rect.position+Vector2(3,2),Vector2(rect.end.x-3,rect.position.y+2),Color(1,1,1,.45),1.1,true)

func _button(rect:Rect2,title:String,active:bool=false,small:bool=false) -> void:
 var fill := Color(.16,.37,.74,.87) if active else Color(.13,.17,.43,.9)
 _glass_panel(rect,fill,Color("#a3ecff") if active else Color("#658bcf"))
 var fontsize:int = 12 if small else 14
 _label(title,Vector2(rect.position.x,rect.position.y+rect.size.y*.64),fontsize,
  Color.WHITE,HORIZONTAL_ALIGNMENT_CENTER,rect.size.x)

func _draw_header(layout:Dictionary) -> void:
 var w:float = layout["viewport"].x
 _label("N O V A G R I D",Vector2(0,38),25,Color("#ecf7ff"),HORIZONTAL_ALIGNMENT_CENTER,w)
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

func _draw_tabs(layout:Dictionary) -> void:
 var titles := ["✦  BLOCK PUZZLE","▦  BLOCKFALL"]
 for i in 2:
  _button(layout["tabs"][i],titles[i],i==mode,true)

func _gem(rect:Rect2,color_id:int,ghost:bool=false) -> void:
 if color_id<=0:
  return
 var base:Color = GEM_COLORS[clampi(color_id,1,GEM_COLORS.size()-1)]
 if ghost:
  draw_rect(rect,Color(base.r,base.g,base.b,.16),true)
  draw_rect(rect,Color(base.r,base.g,base.b,.7),false,1.0)
  return
 var inset := Rect2(rect.position+Vector2(1,1),rect.size-Vector2(2,2))
 draw_rect(Rect2(inset.position+Vector2(0.8,1.5),inset.size),Color(base.r,base.g,base.b,.32),true)
 draw_rect(inset,base.darkened(.2),true)
 draw_rect(Rect2(inset.position+Vector2(2,2),inset.size-Vector2(4,4)),base.lightened(.17),true)
 var upper := Rect2(inset.position+Vector2(3,2),Vector2(maxf(1,inset.size.x-6),maxf(2,inset.size.y*.23)))
 draw_rect(upper,Color(1,1,1,.31),true)
 draw_line(inset.position+Vector2(2,2),Vector2(inset.end.x-2,inset.position.y+2),Color(1,1,1,.82),1.3,true)
 draw_line(inset.position+Vector2(2,2),Vector2(inset.position.x+2,inset.end.y-2),Color(1,1,1,.4),1.1,true)
 draw_line(Vector2(inset.position.x+2,inset.end.y-2),inset.end-Vector2(2,2),base.darkened(.48),2.0)
 draw_line(inset.end-Vector2(2,2),Vector2(inset.end.x-2,inset.position.y+2),base.darkened(.43),1.8)
 draw_rect(inset,Color(1,1,1,.38),false,.75)

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
 _button(layout["buttons"][0],"↶ UNDO",false,true)
 _button(layout["buttons"][1],"↻ RESTART",false,true)
 if dragging and selected>=0 and not puzzle.tray[selected].is_empty():
  var s:Array = puzzle.tray[selected]
  var shape_size:Vector2i = puzzle.shape_size(s)
  var left:Vector2 = touch_at-Vector2(shape_size.x*cell*.5,shape_size.y*cell*.5+54)
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
 var labels := ["◀","⟳","▶","▼ DROP"]
 for i in 4:
  _button(layout["buttons"][i],labels[i],i==3,true)

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
 _button(Rect2(modal.position+Vector2(27,110),Vector2(modal.size.x-54,48)),action,true)

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
    KEY_LEFT: falling.move(-1)
    KEY_RIGHT: falling.move(1)
    KEY_UP:
     if falling.rotate(): audio.effect("rotate")
    KEY_DOWN: _fall_soft_drop()
    KEY_SPACE: _fall_hard_drop()
  queue_redraw()

func _press(pos:Vector2) -> void:
 touching = true
 pressed_at = pos
 touch_at = pos
 dragging = false
 var layout:Dictionary = _layout()
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
 touch_at = pos
 if pos.distance_to(pressed_at)>9.0:
  dragging = true
 if mode==1 and not paused and not falling.over:
  var cell:float = _layout()["board"].size.x/10.0
  while touch_at.x-pressed_at.x>cell*.6:
   falling.move(1)
   pressed_at.x += cell*.6
  while pressed_at.x-touch_at.x>cell*.6:
   falling.move(-1)
   pressed_at.x -= cell*.6
 queue_redraw()

func _release(pos:Vector2) -> void:
 if not touching:
  return
 touching = false
 touch_at = pos
 var layout:Dictionary = _layout()
 if paused or (mode==0 and puzzle.over) or (mode==1 and falling.over):
  var viewport:Vector2 = layout["viewport"]
  var play := Rect2(Vector2(viewport.x*.09+27,viewport.y*.34+110),
   Vector2(viewport.x*.82-54,48))
  if play.has_point(pos):
   if paused:
    paused=false
   elif mode==0:
    puzzle.reset()
    selected=-1
   else:
    falling.reset()
    fall_accum=0
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

func _release_puzzle(pos:Vector2,layout:Dictionary) -> void:
 var board:Rect2 = layout["board"]
 var drop:Vector2 = pos-Vector2(0,52) if dragging else pos
 if selected>=0 and selected<puzzle.tray.size() and board.has_point(drop):
  var shape:Array = puzzle.tray[selected]
  if not shape.is_empty():
   var origin:Vector2i = _origin_from_position(drop,dragging,board,shape)
   if puzzle.place(selected,origin):
    var count:int = puzzle.last_cleared
    audio.effect("combo" if count>10 else "clear" if count>0 else "place")
    if count>0:
     flash=.28 if count<20 else .7
     shake=.25
     _burst(board.get_center(),18+count,Color("#7ceaff"))
    if puzzle.fever_moves==5:
     audio.effect("fever")
     _burst(board.get_center(),33,Color("#ff7aff"))
    if puzzle.over:
     audio.effect("lose")
    selected=-1
    _save_game()
   else:
    audio.effect("invalid")
  return
 for i in layout["buttons"].size():
  if layout["buttons"][i].has_point(pos):
   if i==0:
    if puzzle.undo():
     audio.effect("tap")
   else:
    puzzle.reset()
    audio.effect("tap")
   selected=-1
   _save_game()
   return

func _fall_soft_drop() -> void:
 var locked:bool = falling.soft_drop()
 if locked:
  _fall_locked()
 else:
  audio.effect("pick")

func _fall_hard_drop() -> void:
 falling.hard_drop()
 _fall_locked()
 fall_accum=0

func _fall_locked() -> void:
 if falling.last_lines>0:
  flash=.54
  shake=.31
  _burst(_layout()["board"].get_center(),20+falling.last_lines*9,Color("#86e8ff"))
  audio.effect("combo" if falling.last_lines>=3 else "clear")
 else:
  audio.effect("place")
 if falling.over:
  audio.effect("lose")
 _save_game()

func _release_falling(pos:Vector2,layout:Dictionary) -> void:
 var labels: Array = layout["buttons"]
 for i in labels.size():
  if labels[i].has_point(pos):
   match i:
    0: falling.move(-1)
    1:
     if falling.rotate(): audio.effect("rotate")
    2: falling.move(1)
    3: _fall_hard_drop()
   return
 var field:Rect2 = layout["board"]
 if not field.has_point(pressed_at):
  return
 var movement:Vector2 = pos-pressed_at
 if movement.y>field.size.y/13.0:
  _fall_hard_drop()
 elif movement.length()<25:
  if falling.rotate():
   audio.effect("rotate")

func _burst(center:Vector2,count:int,color:Color) -> void:
 var gen := RandomNumberGenerator.new()
 gen.randomize()
 for i in count:
  var angle:float = gen.randf_range(0,TAU)
  var velocity:Vector2 = Vector2(cos(angle),sin(angle))*gen.randf_range(55,200)
  fragments.append({"pos":center,"speed":velocity,
   "life":gen.randf_range(.25,.65),"original":.65,
   "radius":gen.randf_range(1.7,4.0),"color":color})

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

func _save_game() -> void:
 if puzzle==null or falling==null:
  return
 var f := FileAccess.open("user://novagrid-godot-save.json",FileAccess.WRITE)
 if f:
  f.store_string(JSON.stringify({"puzzle":puzzle.save_state(),"falling":falling.snapshot()}))
