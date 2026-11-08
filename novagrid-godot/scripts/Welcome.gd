extends Node2D
## NovaGrid Reborn: real Godot 4.5.1 responsive menu, not a screenshot.
## The animated nebula and crystal textures are shared by both live game modes.
const VisualsScript = preload("res://scripts/Visuals.gd")
const AudioScript = preload("res://scripts/Audio.gd")
# Original AI-designed 941x1672 image is the EXACT full-screen source of truth.
# Shipped as res://assets/menu/novagrid_cosmic_candy_arcade.png inside the
# playable editor-ready ZIP. If absent, the previous Godot-rendered fallback
# remains operational rather than showing a broken texture.
const EXACT_MENU_ART = "res://assets/menu/novagrid_cosmic_candy_arcade.png"
const EXACT_MENU_CANVAS = Vector2(941.0,1672.0)
const EXACT_PUZZLE_HIT = Rect2(65.0,374.0,813.0,414.0)
const EXACT_FALL_HIT = Rect2(64.0,814.0,814.0,440.0)
const GEMS = [
 Color("#132255"),Color("#ff287f"),Color("#ffc323"),Color("#13e5ff"),
 Color("#a65cff"),Color("#17e888"),Color("#ff812b"),Color("#3688ff")]
var visuals
var audio
var exact_menu_texture:Texture2D = null
var font:Font
var clock:float=0.0
var touch_position:Vector2=Vector2(-1000,-1000)
var stars:Array=[]
var panel_cache:Dictionary={}
var chosen:int=-1
var transition_elapsed:float=0.0
# Exact Blockfall gameplay proportions. Unlike Block Puzzle, this preview
# has a vertical well, an ACTIVE falling T tetromino, landing ghost and NEXT.
const FALL_PREVIEW_COLS:int=10
const FALL_PREVIEW_ROWS:int=18
const FALL_PREVIEW_T = [
 Vector2i(3,3), Vector2i(4,3), Vector2i(5,3), Vector2i(4,4)
]
const FALL_PREVIEW_NEXT = [
 Vector2i(0,0),Vector2i(0,1),Vector2i(0,2),Vector2i(1,2)
]

func _ready() -> void:
 # Always render the ACTUAL reference artwork if its PNG is shipped with the
 # Godot project. Keep the procedural fallback for source-only installations.
 if ResourceLoader.exists(EXACT_MENU_ART):
  exact_menu_texture=load(EXACT_MENU_ART) as Texture2D
 font=ThemeDB.fallback_font
 visuals=VisualsScript.new()
 add_child(visuals)
 visuals.configure(GEMS)
 audio=AudioScript.new()
 add_child(audio)
 audio.select_music("puzzle")
 var random:=RandomNumberGenerator.new()
 random.seed=204812
 for i in 100:
  stars.append({"p":Vector2(random.randf(),random.randf()),
   "s":random.randf_range(.55,1.75),"phase":random.randf_range(0,TAU)})
 get_viewport().size_changed.connect(queue_redraw)
 queue_redraw()

func _process(delta:float) -> void:
 clock+=delta
 if chosen>=0:
  transition_elapsed+=delta
  if transition_elapsed>.22:
   var session:Node=get_node_or_null("/root/Session")
   if session!=null:
    session.set("start_mode",chosen)
   var err:int=get_tree().change_scene_to_file("res://scenes/Main.tscn")
   if err!=OK:
    printerr("Could not open NovaGrid gameplay: ",err)
   chosen=-1
 queue_redraw()

func _rectangles() -> Array[Rect2]:
 var size:Vector2=get_viewport_rect().size if is_inside_tree() else Vector2(432.0,960.0)
 # For the reference image, the WHOLE card is touchable despite being a
 # flattened, pixel-identical artwork. No transparent dead PLAY buttons.
 if exact_menu_texture != null:
  var ratio:=Vector2(size.x/EXACT_MENU_CANVAS.x,size.y/EXACT_MENU_CANVAS.y)
  return [
   Rect2(EXACT_PUZZLE_HIT.position*ratio,EXACT_PUZZLE_HIT.size*ratio),
   Rect2(EXACT_FALL_HIT.position*ratio,EXACT_FALL_HIT.size*ratio)
  ]
 var margin:float=clampf(size.x*.052,14.0,28.0)
 var card_height:float=clampf(size.y*.235,146.0,226.0)
 var gap:float=clampf(size.y*.018,11.0,19.0)
 var top:float=clampf(size.y*.267,158.0,273.0)
 # Keep two complete cards + progression footer on small Android screens.
 if top+2.0*card_height+gap>size.y-126.0:
  top=maxf(138.0,size.y-126.0-2.0*card_height-gap)
 return [
  Rect2(margin,top,size.x-2.0*margin,card_height),
  Rect2(margin,top+card_height+gap,size.x-2.0*margin,card_height)
 ]

func _label(message:String,pos:Vector2,size:int,color:Color=Color.WHITE,
 alignment:HorizontalAlignment=HORIZONTAL_ALIGNMENT_LEFT,width:float=-1.0) -> void:
 draw_string(font,pos,message,alignment,width,size,color)

func _glass(box:Rect2,fill:Color,outline:Color,strong:bool=false) -> void:
 var key:String=fill.to_html(true)+outline.to_html(true)+("Y" if strong else "N")
 if not panel_cache.has(key):
  var style:=StyleBoxFlat.new()
  style.bg_color=fill
  style.border_color=outline
  style.set_corner_radius_all(22 if strong else 15)
  style.set_border_width_all(2 if strong else 1)
  style.shadow_color=Color(outline.r,outline.g,outline.b,.22 if strong else .12)
  style.shadow_size=15 if strong else 8
  panel_cache[key]=style
 draw_style_box(panel_cache[key],box)
 var line_from:=box.position+Vector2(18,3)
 var line_to:=Vector2(box.end.x-18,box.position.y+3)
 draw_line(line_from,line_to,Color(1,1,1,.52),1.7,true)
 draw_line(line_from+Vector2(0,2.5),line_to+Vector2(0,2.5),
  Color(.55,.90,1.0,.19),1.0,true)

func _planet(center:Vector2,radius:float,main:Color,halo:Color) -> void:
 for step in range(5,0,-1):
  var extra:float=float(step)*radius*.17
  draw_circle(center,radius+extra,Color(halo.r,halo.g,halo.b,.020))
 draw_circle(center,radius,Color(main.r*.28,main.g*.35,main.b*.7,.76))
 for i in 26:
  var rr:float=radius*(1.0-float(i)/38.0)
  draw_arc(center-Vector2(radius*.21,radius*.14),rr,PI*1.15,TAU*.92,52,
   Color(halo.r,halo.g,halo.b,.022),1.2,true)
 draw_arc(center,radius*1.25,-.43,PI+.53,76,Color(halo.r,halo.g,halo.b,.37),1.7,true)
 draw_arc(center,radius*1.25,PI+.53,TAU-.45,76,Color(halo.r,halo.g,halo.b,.13),1.7,true)
 draw_circle(center-Vector2(radius*.31,radius*.36),radius*.13,Color(1,1,1,.34))

# Original lightweight cosmic atmosphere, drawn natively rather than using a
# static screenshot. Kept behind the playable hit targets.
func _cosmic_backdrop(size:Vector2) -> void:
 var bands:Array=[
  {"center":Vector2(.15,.12),"radius":.72,"color":Color("#6122bb")},
  {"center":Vector2(.90,.35),"radius":.68,"color":Color("#0542ab")},
  {"center":Vector2(.47,.78),"radius":.62,"color":Color("#ab145b")}
 ]
 for band in bands:
  var center:Vector2=Vector2(band["center"])*size
  var radius:float=size.x*float(band["radius"])
  var shade:Color=band["color"]
  for ring in range(9,0,-1):
   var t:float=float(ring)/9.0
   draw_circle(center,radius*t,Color(shade.r,shade.g,shade.b,.012))
 # Thin intertwined galaxy trails frame the two functional game choices.
 for arc_index in 3:
  var radius:float=size.x*(.60+float(arc_index)*.13)
  var hue:Color=Color("#42daff") if arc_index%2==0 else Color("#d857ff")
  draw_arc(Vector2(size.x*.58,size.y*.48),radius,-.61,1.61,96,
   Color(hue.r,hue.g,hue.b,.10),1.2,true)

func _starfield(size:Vector2) -> void:
 for star in stars:
  var point:Vector2=star["p"]
  var place:=Vector2(point.x*size.x, fposmod(point.y*size.y+clock*float(star["s"])*4.0,size.y))
  var brightness:float=.25+.52*absf(sin(clock*.73+float(star["phase"])))
  draw_circle(place,float(star["s"]),Color(.88,.93,1.0,brightness))
 # Original, low-cost orbital lines add depth without obscuring the actual UI.
 var middle:=Vector2(size.x*.53,size.y*.19)
 for n in 4:
  var radius:float=size.x*(.30+float(n)*.11)
  draw_arc(middle,radius,-.85,PI+.56,96,Color(.38,.52,1.0,.045),1.0,true)

func _crystal(rect:Rect2,kind:int,alpha:float=1.0) -> void:
 var tex:Texture2D=visuals.get_gem_texture(kind)
 if tex!=null:
  draw_texture_rect(tex,rect,false,Color(1,1,1,alpha))
 else:
  var color:Color=GEMS[clampi(kind,1,GEMS.size()-1)]
  draw_rect(rect,color,true)
 # The sweet is a true StandardMaterial3D mesh with clearcoat, rendered
 # by the same SubViewport candy atlas as the two live play modes.

func _mini_board(rect:Rect2,falling:bool) -> void:
 if falling:
  _falling_preview(rect)
  return
 # Block Puzzle preview is deliberately broad and SQUARE (9x9 gameplay);
 # Blockfall uses its own separate tall-well rendering below.
 var cols:int=7
 var rows:int=7
 var side:float=minf(rect.size.x/float(cols),rect.size.y/float(rows))
 var board:=Rect2(rect.position+Vector2((rect.size.x-cols*side)*.5,
  (rect.size.y-rows*side)*.5),Vector2(cols*side,rows*side))
 _glass(board.grow(6.0),Color("#080f30"),Color("#61baff"))
 for y in rows:
  for x in cols:
   var cell:=Rect2(board.position+Vector2(x*side,y*side),Vector2(side,side))
   var background:=Color(.07,.15,.34,.94) if (x+y)%2==0 else Color(.055,.12,.29,.94)
   draw_rect(cell.grow(-.80),background,true)
   var gem:int=0
   if y==5 and x!=3:
    gem=1+(x*2)%7
   elif y==6 and x<4:
    gem=1+(x+3)%7
   elif x==5 and y>=2 and y<=4:
    gem=3
   elif y==1 and x>=1 and x<=3:
    gem=4
   elif y==2 and x==2:
    gem=4
   if gem>0:
    _crystal(cell.grow(-1.0),gem)
 draw_line(board.position+Vector2(3,board.size.y+5),
  board.end+Vector2(-3,5),Color("#42f3ff"),2.0,true)


func _falling_preview(rect:Rect2) -> void:
 # Real proportions: 10 columns x 18 rows, like the live Blockfall engine.
 # The remaining horizontal space is a dedicated NEXT-piece sidebar.
 # Keep ~8 px inner padding: nothing may escape the clickable game card.
 _glass(rect,Color("#080b2b"),Color("#ed8fff"))
 var padding:float=7.0
 var cell:float=minf((rect.size.y-2.0*padding)/float(FALL_PREVIEW_ROWS),
  (rect.size.x-55.0)/float(FALL_PREVIEW_COLS))
 var width:float=cell*float(FALL_PREVIEW_COLS)
 var height:float=cell*float(FALL_PREVIEW_ROWS)
 var well:=Rect2(rect.position+Vector2(padding, (rect.size.y-height)*.5),
  Vector2(width,height))
 # Distinct Tetris-like well with strong vertical edges and visible bottom.
 draw_rect(well.grow(1.8),Color("#020a25"),true)
 draw_line(well.position-Vector2(2,0),
  well.position+Vector2(-2,height),Color("#c268ff"),2.5,true)
 draw_line(well.position+Vector2(width+2,0),
  well.end+Vector2(2,0),Color("#64ddff"),2.5,true)
 for y in FALL_PREVIEW_ROWS:
  for x in FALL_PREVIEW_COLS:
   var tile:=Rect2(well.position+Vector2(x*cell,y*cell),
    Vector2(cell,cell))
   var checker:Color=Color("#11234f") if (x+y)%2==0 else Color("#0b1a3e")
   draw_rect(tile.grow(-.45),checker,true)
 # Four coherent LOCKED tetrominoes, not randomized pile like Block Puzzle.
 # J piece along the left, orange L on the right, yellow O and green S.
 var locked:Array=[
  {"color":7,"cells":[Vector2i(0,15),Vector2i(0,16),
   Vector2i(0,17),Vector2i(1,17)]},
  {"color":6,"cells":[Vector2i(8,15),Vector2i(8,16),
   Vector2i(8,17),Vector2i(7,17)]},
  {"color":2,"cells":[Vector2i(5,16),Vector2i(6,16),
   Vector2i(5,17),Vector2i(6,17)]},
  {"color":5,"cells":[Vector2i(3,14),Vector2i(4,14),
   Vector2i(2,15),Vector2i(3,15)]}
 ]
 for piece in locked:
  for spot in piece["cells"]:
   var p:Vector2i=spot
   _crystal(Rect2(well.position+Vector2(p.x*cell,p.y*cell),
    Vector2(cell,cell)).grow(-.45),int(piece["color"]))
 # GHOST shows where the moving T will land. The ghost is NOT filled.
 # Four visible translucent outlines emphasize real falling mechanics.
 for spot in FALL_PREVIEW_T:
  var shadow:Vector2i=spot+Vector2i(0,9)
  var ghost:=Rect2(well.position+Vector2(shadow.x*cell,shadow.y*cell),
   Vector2(cell,cell)).grow(-1.0)
  draw_rect(ghost,Color("#dca2ff",.10),true)
  draw_rect(ghost,Color("#f2adff",.55),false,1.2)
 # Active pink T is mid-air, moving down gently; all FOUR cells remain aligned.
 var fall_offset:float=fposmod(clock*.75,1.0)*cell*.70
 for spot in FALL_PREVIEW_T:
  var target:Vector2i=spot
  var at:=Rect2(well.position+Vector2(target.x*cell,
   target.y*cell+fall_offset),Vector2(cell,cell))
  _crystal(at.grow(-.35),4)
 # Vertical movement tracer and arrow make it clear this is a FALLING piece.
 var track_x:float=well.position.x+4.5*cell
 draw_line(Vector2(track_x,well.position.y+5.4*cell),
  Vector2(track_x,well.position.y+9.3*cell),
  Color("#dba9ff",.30),1.0,true)
 var arrow_y:float=well.position.y+9.8*cell
 draw_line(Vector2(track_x-3,arrow_y-4),Vector2(track_x,arrow_y),
  Color("#e2b4ff",.6),1.5,true)
 draw_line(Vector2(track_x+3,arrow_y-4),Vector2(track_x,arrow_y),
  Color("#e2b4ff",.6),1.5,true)
 # Dedicated next preview removes ambiguity: real Blockfall queues shapes.
 var side_x:float=well.end.x+6.0
 var side_width:float=maxf(27.0,rect.end.x-side_x-5.0)
 _label("NEXT",Vector2(side_x,rect.position.y+20),10,
  Color("#f5cdff"))
 var next_cell:float=minf(12.0,(side_width-4.0)*.5)
 for spot in FALL_PREVIEW_NEXT:
  var p:Vector2i=spot
  _crystal(Rect2(Vector2(side_x+4.0+p.x*next_cell,
   rect.position.y+31.0+p.y*next_cell),
   Vector2(next_cell,next_cell)).grow(-.35),6)
 _label("↓ DROP",Vector2(side_x,rect.position.y+105),9,
  Color("#8df5ff"))
 _label("LINES",Vector2(side_x,rect.position.y+143),9,
  Color("#acbbf6"))
 _label("04",Vector2(side_x,rect.position.y+161),16,
  Color("#f9e0ff"))
 # Last line of the well is always visible, preventing floating-board illusion.
 draw_line(well.position+Vector2(0,height+2),
  well.end+Vector2(0,2),Color("#ef78ff"),2.2,true)

func _card(rect:Rect2,index:int) -> void:
 var is_puzzle:bool=index==0
 var active:bool=rect.grow(4).has_point(touch_position)
 var cyan:=Color("#35eaff")
 var pink:=Color("#ff8ef6")
 var accent:Color=cyan if is_puzzle else pink
 var background:Color=Color("#0c254d") if is_puzzle else Color("#241348")
 var bob:float=sin(clock*1.6+float(index)*2.0)*1.2
 var panel:=Rect2(rect.position+Vector2(0,bob),rect.size)
 _glass(panel,background,accent,true)
 # Side-tone and neon rail give real hierarchy, not a flat text rectangle.
 draw_rect(Rect2(panel.position+Vector2(2,17),Vector2(3,panel.size.y-34)),accent,true)
 draw_line(panel.position+Vector2(14,panel.size.y-3),
  panel.position+Vector2(panel.size.x*.48,panel.size.y-3),
  Color(accent.r,accent.g,accent.b,.8),2.0,true)
 # Scale inner content proportionally for 360x640 through 432x960.
 # Canonical coordinates: 390 x 226, normalized to a single interactive card.
 draw_set_transform(panel.position,0.0,Vector2(panel.size.x/390.0,panel.size.y/226.0))
 var label_color:Color=Color("#8ff5ff") if is_puzzle else Color("#ffc5fb")
 _label("01  /  9 x 9" if is_puzzle else "02  /  FALLING BLOCKS",
  Vector2(21,31),12,label_color)
 _label("CLASSIC" if is_puzzle else "BLOCKFALL",Vector2(20,76),29,Color.WHITE)
 _label("PUZZLE" if is_puzzle else "ARCADE",
  Vector2(20,112),36,accent)
 _label("PLACE  ·  MATCH  ·  BLAST" if is_puzzle else "DROP  ·  ROTATE  ·  SURVIVE",
  Vector2(21,136),10,Color("#c8ddf7"))
 for j in 3:
  var kind:int=(j+3) if is_puzzle else (j+1)
  _crystal(Rect2(Vector2(20+24*j,146),Vector2(23,23)),kind)
 # Large CTA is the brightest element on the left, away from game thumbnail.
 var button:=Rect2(Vector2(20,180),Vector2(164,34))
 _glass(button,Color("#006f97") if is_puzzle else Color("#8a2a9a"),accent)
 _label("PLAY NOW  ▶",Vector2(button.position.x,button.position.y+23),16,
  Color.WHITE,HORIZONTAL_ALIGNMENT_CENTER,button.size.x)
 var inset:=Rect2(Vector2(204,21),Vector2(168,186))
 _mini_board(inset,not is_puzzle)
 # Animated, original glow guides the eye to the preview's playfield.
 draw_arc(Vector2(290,114),101.0,PI*.55,PI*1.22,32,
  Color(accent.r,accent.g,accent.b,.22),2.1,true)
 if active:
  draw_arc(Vector2(294,116),106.0,-.65,.75,26,
   Color(accent.r,accent.g,accent.b,.60),3.0,true)
 draw_set_transform(Vector2.ZERO,0.0,Vector2.ONE)

func _draw() -> void:
 var view:Vector2=get_viewport_rect().size
 if exact_menu_texture != null:
  # Render the supplied image itself, no approximation via procedural panels.
  # Stretch to the viewport so all CTA/buttons remain present on narrow phones.
  draw_texture_rect(exact_menu_texture,Rect2(Vector2.ZERO,view),false)
  if chosen>=0:
   draw_rect(Rect2(Vector2.ZERO,view),
    Color(.01,.02,.08,clampf(transition_elapsed/.28,0.0,1.0)),true)
  return
 var cards:Array[Rect2]=_rectangles()
 var compact:bool=view.y<730.0
 # Dark atmospheric veil behind the brand prevents the nebula from
 # reducing readability; no fake imagery and no expensive blur shaders.
 draw_rect(Rect2(Vector2.ZERO,view),Color("#060b27",.48),true)
 _cosmic_backdrop(view)
 _starfield(view)
 var header_height:float=cards[0].position.y
 var title_y:float=header_height*.36
 var small:float=.83 if compact else 1.0
 _planet(Vector2(view.x*.84,header_height*.42),view.x*.115,
  Color("#101a58"),Color("#6678ff"))
 _planet(Vector2(view.x*.13,header_height*.59),view.x*.067,
  Color("#07375c"),Color("#4ee9f6"))
 # A restrained candy constellation frames the genuine brand and makes
 # the game visually identifiable from the first screen.
 var hero_gems:=[{"kind":1,"x":.045,"y":.29,"size":45.0},
  {"kind":2,"x":.86,"y":.70,"size":48.0},
  {"kind":5,"x":.055,"y":.72,"size":35.0}]
 for item in hero_gems:
  var tex:Texture2D=visuals.get_gem_texture(int(item["kind"]))
  if tex==null:
   continue
  var diameter:float=float(item["size"])*small
  var offset:float=sin(clock*1.25+float(item["kind"]))*4.0
  var p:=Vector2(view.x*float(item["x"]),header_height*float(item["y"])+offset)
  var halo:Color=GEMS[int(item["kind"])]
  draw_circle(p+Vector2(diameter*.5,diameter*.5),diameter*.62,
   Color(halo.r,halo.g,halo.b,.10))
  draw_texture_rect(tex,Rect2(p,Vector2(diameter,diameter)),false,Color.WHITE)
 # One coherent name instead of old NOVA / G.RID fragmentation.
 var brand_size:int=clampi(int(view.x*.112*small),33,50)
 _label("NovaGrid",Vector2(0,title_y+3),brand_size,Color("#148bff"),
  HORIZONTAL_ALIGNMENT_CENTER,view.x)
 _label("NovaGrid",Vector2(0,title_y),brand_size,Color("#f8fdff"),
  HORIZONTAL_ALIGNMENT_CENTER,view.x)
 var sub_y:float=title_y+27.0*small
 _label("C O S M I C   B L O C K   P U Z Z L E",Vector2(0,sub_y),
  11 if not compact else 9,Color("#96f4ff"),HORIZONTAL_ALIGNMENT_CENTER,view.x)
 var trail_y:float=sub_y+15.0*small
 draw_line(Vector2(view.x*.33,trail_y),Vector2(view.x*.67,trail_y),
  Color("#ab7fff",.82),2.0,true)
 _label("CRYSTAL BLOCKS  ·  COSMIC COMBOS",Vector2(0,trail_y+22.0*small),
  11 if not compact else 9,Color("#e2d9ff"),HORIZONTAL_ALIGNMENT_CENTER,view.x)
 _label("CHOOSE YOUR ADVENTURE",Vector2(0,cards[0].position.y-13.0),
  11,Color("#b4cbff"),HORIZONTAL_ALIGNMENT_CENTER,view.x)
 for i in 2:
  _card(cards[i],i)
 var footer_top:float=cards[1].end.y+clampf(view.y*.020,11.0,20.0)
 var room:float=view.y-footer_top-57.0
 if room>42.0:
  var footer_height:float=minf(room,87.0)
  var footer:=Rect2(Vector2(cards[0].position.x,footer_top),
   Vector2(cards[0].size.x,footer_height))
  _glass(footer,Color("#10224a"),Color("#587bff"))
  _label("★  YOUR COSMIC JOURNEY",footer.position+Vector2(18,25),
   16 if not compact else 13,Color("#ffe49a"))
  _label("LEVEL UP  ·  UNLOCK THEMES  ·  EARN STARS",
   footer.position+Vector2(18,44),10 if not compact else 9,Color("#bde2ff"))
  if footer_height>65.0:
   var kinds:=[2,3,4,5,1]
   for i in kinds.size():
    _crystal(Rect2(footer.position+Vector2(19+i*28,49),
     Vector2(25,25)),kinds[i])
   _label("YOUR NEXT HIGH SCORE STARTS HERE",
    footer.position+Vector2(155,66),9,Color("#d5cdff"))
 _label("ORIGINAL PUZZLE ARCADE   •   PLAY YOUR WAY",
  Vector2(0,view.y-18.0),10 if not compact else 8,
  Color(.76,.88,1.0,.8),HORIZONTAL_ALIGNMENT_CENTER,view.x)
 if chosen>=0:
  draw_rect(Rect2(Vector2.ZERO,view),
   Color(.01,.02,.09,clampf(transition_elapsed/.28,0.0,1.0)),true)

func _launch(index:int) -> void:
 if chosen>=0:
  return
 chosen=index
 transition_elapsed=0.0
 audio.effect("tap")

func _input(event:InputEvent) -> void:
 if event is InputEventScreenTouch and event.index==0:
  if event.pressed:
   touch_position=event.position
  else:
   for i in 2:
    if _rectangles()[i].grow(4).has_point(event.position):
     _launch(i)
     break
   touch_position=Vector2(-1000,-1000)
  queue_redraw()
 elif not OS.has_feature("mobile") and event is InputEventMouseMotion:
  touch_position=event.position
 elif not OS.has_feature("mobile") and event is InputEventMouseButton and event.button_index==MOUSE_BUTTON_LEFT and event.pressed:
  for i in 2:
   if _rectangles()[i].grow(4).has_point(event.position):
    _launch(i)
    break
 elif event is InputEventKey and event.pressed and not event.echo:
  if event.keycode==KEY_1 or event.keycode==KEY_ENTER:
   _launch(0)
  elif event.keycode==KEY_2:
   _launch(1)
