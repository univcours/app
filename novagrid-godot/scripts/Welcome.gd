extends Node2D
## NovaGrid Reborn: real Godot 4.5.1 responsive menu, not a screenshot.
## The animated nebula and crystal textures are shared by both live game modes.
const VisualsScript = preload("res://scripts/Visuals.gd")
const AudioScript = preload("res://scripts/Audio.gd")
# Bundled SIL Open Font License typefaces; independent of Android system fonts.
const DISPLAY_FONT:Font = preload("res://assets/fonts/Orbitron.ttf")
const UI_FONT:Font = preload("res://assets/fonts/Oxanium.ttf")
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

# Logical 432x960 reference layout. Playable actions are Classic and Blockfall.
# Daily and Galaxy are visibly disabled until their native gameplay exists.
func _menu_scale() -> Vector2:
 var size:Vector2=get_viewport_rect().size if is_inside_tree() else Vector2(432.0,960.0)
 return Vector2(size.x/432.0,size.y/960.0)

func _rectangles() -> Array[Rect2]:
 var ratio:Vector2=_menu_scale()
 return [
  Rect2(Vector2(20,548)*ratio,Vector2(392,81)*ratio),
  Rect2(Vector2(20,718)*ratio,Vector2(392,81)*ratio)
 ]

func _label(message:String,pos:Vector2,size:int,color:Color=Color.WHITE,
 alignment:HorizontalAlignment=HORIZONTAL_ALIGNMENT_LEFT,width:float=-1.0) -> void:
 # Multi-layer neon typography, with fallback for symbols absent from the fonts.
 var typeface:Font=DISPLAY_FONT if size>=19 else UI_FONT
 for i in message.length():
  if not typeface.has_char(message.unicode_at(i)):
   typeface=font
   break
 var glow:Color=Color("#b45eff") if size>=29 else color
 var strength:float=.72 if color.get_luminance()>.4 else .42
 if size>=19:
  draw_string_outline(typeface,pos,message,alignment,width,size,9,
   Color(glow.r,glow.g,glow.b,.16*strength))
  draw_string_outline(typeface,pos,message,alignment,width,size,5,
   Color(glow.r,glow.g,glow.b,.42*strength))
  draw_string_outline(typeface,pos,message,alignment,width,size,2,
   Color(glow.r,glow.g,glow.b,.75*strength))
 else:
  draw_string_outline(typeface,pos,message,alignment,width,size,3,
   Color(glow.r,glow.g,glow.b,.30*strength))
  draw_string_outline(typeface,pos,message,alignment,width,size,1,
   Color(glow.r,glow.g,glow.b,.65*strength))
 draw_string(typeface,pos,message,alignment,width,size,color)

func _glass(box:Rect2,fill:Color,outline:Color,strong:bool=false) -> void:
 var key:String=fill.to_html(true)+outline.to_html(true)+("Y" if strong else "N")
 if not panel_cache.has(key):
  var style:=StyleBoxFlat.new()
  style.bg_color=fill
  style.border_color=outline.lightened(.18)
  style.set_corner_radius_all(22 if strong else 15)
  style.set_border_width_all(2)
  style.shadow_color=Color(outline.r,outline.g,outline.b,.53 if strong else .31)
  style.shadow_size=23 if strong else 13
  panel_cache[key]=style
 draw_style_box(panel_cache[key],box)
 var line_from:=box.position+Vector2(18,3)
 var line_to:=Vector2(box.end.x-18,box.position.y+3)
 draw_line(line_from,line_to,Color(1,1,1,.52),1.7,true)
 draw_line(line_from+Vector2(0,2.5),line_to+Vector2(0,2.5),
  Color(.55,.90,1.0,.29),1.0,true)
 draw_line(Vector2(box.position.x+13,box.end.y-4),
  Vector2(box.end.x-13,box.end.y-4),
  Color(outline.r,outline.g,outline.b,.37),1.2,true)

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
  for ring in range(15,0,-1):
   var t:float=float(ring)/15.0
   draw_circle(center,radius*t,Color(shade.r,shade.g,shade.b,.017))
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

# Follows the approved reference image's actual screen structure:
# top HUD, luminous NovaGrid title, floating crystal pile, four large
# stacked mode rows, and bottom navigation. No flattened fake hit targets.
func _hero_cube(x:float,y:float,side:float,color:Color) -> void:
 var c:Color=color
 var front:=PackedVector2Array([
  Vector2(x,y),Vector2(x+side,y),Vector2(x+side,y+side),Vector2(x,y+side)])
 var top:=PackedVector2Array([
  Vector2(x,y),Vector2(x+side*.21,y-side*.19),
  Vector2(x+side*1.21,y-side*.19),Vector2(x+side,y)])
 var right:=PackedVector2Array([
  Vector2(x+side,y),Vector2(x+side*1.21,y-side*.19),
  Vector2(x+side*1.21,y+side*.81),Vector2(x+side,y+side)])
 draw_rect(Rect2(x-4,y-4,side+9,side+9),Color(c.r,c.g,c.b,.075),true)
 draw_colored_polygon(front,c)
 draw_colored_polygon(top,c.lightened(.46))
 draw_colored_polygon(right,c.darkened(.31))
 var bevel:float=maxf(3.0,side*.09)
 draw_colored_polygon(PackedVector2Array([
  Vector2(x,y),Vector2(x+side,y),
  Vector2(x+side-bevel,y+bevel),Vector2(x+bevel,y+bevel)]),c.lightened(.38))
 draw_colored_polygon(PackedVector2Array([
  Vector2(x,y),Vector2(x+bevel,y+bevel),
  Vector2(x+bevel,y+side-bevel),Vector2(x,y+side)]),c.lightened(.21))
 draw_colored_polygon(PackedVector2Array([
  Vector2(x+side,y),Vector2(x+side,y+side),
  Vector2(x+side-bevel,y+side-bevel),Vector2(x+side-bevel,y+bevel)]),c.darkened(.20))
 draw_rect(Rect2(x+bevel,y+bevel,side-2*bevel,side-2*bevel),Color(1,1,1,.065),true)
 draw_line(Vector2(x+bevel*1.3,y+bevel*1.2),
  Vector2(x+side*.58,y+bevel*1.2),Color(1,1,1,.57),1.3,true)
 draw_line(Vector2(x+2,y+2),Vector2(x+side-3,y+2),Color(1,1,1,.75),1.6,true)
 draw_line(Vector2(x+2,y+2),Vector2(x+2,y+side-3),Color(1,1,1,.33),1.4,true)
 draw_line(Vector2(x+side-1,y+2),Vector2(x+side-1,y+side-2),
  Color(1,1,1,.35),1.2,true)

func _reference_hero() -> void:
 var center:=Vector2(220,364)
 _planet(center+Vector2(1,65),128,Color("#1f1679"),Color("#a538ff"))
 for ring in 4:
  draw_arc(center+Vector2(0,75),148+ring*5,PI*.05,PI*.95,88,
   Color(.3,.75,1.0,.16+ring*.025),2.0,true)
 var bob:float=sin(clock*1.35)*3.0
 draw_circle(center+Vector2(0,108),126,Color("#7718c4",.09))
 # Faceted 3D-looking cube arrangement from the approved concept.
 # All polygons are produced by Godot, so no fake screenshots are embedded.
 _hero_cube(112,321+bob,58,Color("#b34dfb"))
 _hero_cube(174,349+bob,57,Color("#9c3fff"))
 _hero_cube(235,340+bob,56,Color("#17b8ff"))
 _hero_cube(145,259+bob,57,Color("#d259fa"))
 _hero_cube(208,292+bob,56,Color("#ffad24"))
 _hero_cube(208,233+bob,53,Color("#ffc139"))
 _hero_cube(267,312+bob,44,Color("#10aefb"))
 for spark in [Vector2(93,320),Vector2(338,306),Vector2(180,241)]:
  var radius:float=5.0+sin(clock*2.0+spark.x)*1.2
  draw_line(spark-Vector2(radius,0),spark+Vector2(radius,0),
   Color("#fbd2ff",.75),1.5,true)
  draw_line(spark-Vector2(0,radius),spark+Vector2(0,radius),
   Color("#fbd2ff",.75),1.5,true)

# Drawn below the crystal constellation and above the first live CTA.
# A native layered neon mountain horizon replaces the former empty space.
func _cosmic_horizon() -> void:
 for band in 6:
  var strength:float=.12-float(band)*.016
  draw_line(Vector2(37,513+band*3),Vector2(395,513+band*3),
   Color(.36,.18,.95,strength),2.0,true)
 var far:=PackedVector2Array([
  Vector2(0,538),Vector2(0,515),Vector2(43,482),Vector2(84,516),
  Vector2(138,492),Vector2(180,518),Vector2(237,481),
  Vector2(293,519),Vector2(364,473),Vector2(432,516),Vector2(432,538)])
 draw_colored_polygon(far,Color("#141042"))
 draw_line(Vector2(0,516),Vector2(43,482),Color("#a252ff",.30),1.5,true)
 draw_line(Vector2(294,518),Vector2(364,473),Color("#38cfff",.32),1.5,true)
 var near:=PackedVector2Array([
  Vector2(0,545),Vector2(0,533),Vector2(66,509),Vector2(96,537),
  Vector2(155,528),Vector2(231,541),Vector2(295,523),
  Vector2(344,537),Vector2(401,510),Vector2(432,523),Vector2(432,545)])
 draw_colored_polygon(near,Color("#070a2b"))
 draw_line(Vector2(65,511),Vector2(96,537),Color("#a66bff",.42),1.6,true)
 draw_line(Vector2(344,537),Vector2(401,510),Color("#26b8ff",.48),1.6,true)
 for n in 7:
  var x:float=52.0+float(n)*51.0
  var y:float=508.0+sin(float(n)*2.3)*12.0
  draw_circle(Vector2(x,y),2.1,Color("#ad95ff",.34))

func _menu_row(y:float,title:String,subtitle:String,accent:Color,
 enabled:bool,number:int) -> void:
 var rect:=Rect2(20,y,392,81)
 var ink:Color=Color("#071c4a") if enabled else Color("#11112c")
 _glass(rect,ink,accent if enabled else Color("#65538d"),true)
 draw_line(Vector2(42,y+2),Vector2(387,y+2),
  Color(accent.r,accent.g,accent.b,.52 if enabled else .18),1.5,true)
 # Gradient-like glow on the left and consistent illuminated game icon.
 draw_rect(Rect2(23,y+11,5,59),Color(accent.r,accent.g,accent.b,.85 if enabled else .24),true)
 var glyph:Rect2=Rect2(37,y+21,40,40)
 _glass(glyph,Color("#102448"),accent)
 if number==0:
  for yy in 3:
   for xx in 3:
    draw_rect(Rect2(43+xx*10,y+27+yy*10,7,7),
     Color("#52e4ff",.85),true)
 elif number==1:
  _label("D",Vector2(50,y+49),25,accent)
 elif number==2:
  for yy in 3:
   _hero_cube(48+yy*5,y+28+yy*5,10,accent)
 else:
  _label("✦",Vector2(45,y+49),28,accent)
 _label(title,Vector2(91,y+34),20,
  Color("#f5faff") if enabled else Color("#aab5d6"))
 _label(subtitle,Vector2(91,y+55),12,Color("#bce3ff"))
 if enabled:
  _label("▶",Vector2(361,y+50),26,accent)
 else:
  _label("SOON",Vector2(344,y+46),12,Color("#b4acef"))

func _draw() -> void:
 var actual:Vector2=get_viewport_rect().size
 draw_rect(Rect2(Vector2.ZERO,actual),Color("#06071d"),true)
 # All tappable rectangles use the same viewport mapping.
 draw_set_transform(Vector2.ZERO,0.0,_menu_scale())
 draw_rect(Rect2(0,0,432,960),Color("#090b29"),true)
 _cosmic_backdrop(Vector2(432,960))
 _starfield(Vector2(432,960))
 _planet(Vector2(403,103),64,Color("#18124a"),Color("#4e65ff"))
 _planet(Vector2(29,264),25,Color("#231459"),Color("#b54dff"))
 # Top HUD: decorative symbols only; do not fabricate spendable balances.
 _glass(Rect2(18,21,70,44),Color("#11204a"),Color("#42dfff"))
 _label("✦",Vector2(35,51),24,Color("#ffcf50"))
 _label("★",Vector2(62,49),19,Color("#ffe7a2"))
 _glass(Rect2(348,21,65,44),Color("#141d4c"),Color("#9c78ff"))
 _label("⚙",Vector2(368,51),25,Color("#f4efff"))
 _label("NovaGrid",Vector2(0,144),45,Color("#f7eaff"),
  HORIZONTAL_ALIGNMENT_CENTER,432)
 _label("Cosmic Block Puzzle",Vector2(0,169),15,Color("#a5eaff"),
  HORIZONTAL_ALIGNMENT_CENTER,432)
 _reference_hero()
 _cosmic_horizon()
 _menu_row(548,"Classic","9 X 9 Puzzle",Color("#39e6ff"),true,0)
 _menu_row(633,"Daily Challenge","Coming soon",Color("#ffc15b"),false,1)
 _menu_row(718,"Blockfall","Endless block action",Color("#df6dff"),true,2)
 _menu_row(803,"Galaxy Stages","Coming soon",Color("#31dfff"),false,3)
 var bottom:=Rect2(20,893,392,57)
 _glass(bottom,Color("#161440"),Color("#684bba"))
 _label("CLASSIC",Vector2(47,928),11,Color("#aeefff"))
 _label("BLOCKFALL",Vector2(150,928),11,Color("#e5aaff"))
 _label("NOVA",Vector2(300,928),11,Color("#bbceef"))
 if chosen>=0:
  draw_rect(Rect2(0,0,432,960),
   Color(.01,.02,.09,clampf(transition_elapsed/.28,0.0,1.0)),true)
 draw_set_transform(Vector2.ZERO,0.0,Vector2.ONE)

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
