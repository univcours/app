extends Node2D
## NovaGrid Reborn: real Godot 4.5.1 responsive menu, not a screenshot.
## The animated nebula and crystal textures are shared by both live game modes.
const VisualsScript = preload("res://scripts/Visuals.gd")
const AudioScript = preload("res://scripts/Audio.gd")
const GEMS = [
 Color("#132255"),Color("#ff287f"),Color("#ffc323"),Color("#13e5ff"),
 Color("#a65cff"),Color("#17e888"),Color("#ff812b"),Color("#3688ff")]
var visuals
var audio
var font:Font
var clock:float=0.0
var touch_position:Vector2=Vector2(-1000,-1000)
var stars:Array=[]
var panel_cache:Dictionary={}
var chosen:int=-1
var transition_elapsed:float=0.0

func _ready() -> void:
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
 var margin:float=clampf(size.x*.046,12,28)
 var h:float=clampf(size.y*.205,146.0,196.0)
 var gap:float=clampf(size.y*.025,12,24)
 var y:float=maxf(216.0,size.y*.295)
 if y+2.0*h+gap>size.y-138.0:
  y=maxf(174.0,size.y-138.0-2.0*h-gap)
 return [Rect2(margin,y,size.x-2*margin,h),
  Rect2(margin,y+h+gap,size.x-2*margin,h)]

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
 var cols:int=10 if falling else 9
 var rows:int=12 if falling else 9
 var cell_size:float=minf(rect.size.x/float(cols),rect.size.y/float(rows))
 var real:=Rect2(rect.position+Vector2((rect.size.x-cols*cell_size)*.5,
  (rect.size.y-rows*cell_size)*.5),Vector2(cols*cell_size,rows*cell_size))
 _glass(real.grow(5),Color(.04,.08,.22,.75),Color(.25,.78,1.0,.50))
 for y in rows:
  for x in cols:
   var square:=Rect2(real.position+Vector2(x*cell_size,y*cell_size),Vector2(cell_size,cell_size))
   draw_rect(square.grow(-.65),Color(.08,.15,.31,.62),true)
   var tile:int=0
   if falling:
    if y>5 and (((x*3+y*5)%9<4 and y>7) or (y>9 and ((x+y*3)%6!=0))):
     tile=1+(x*7+y*3)%7
    if y==3 and x>=3 and x<=6:
     tile=3
   else:
    if ((y==6 or y==7) and x<8) or (x==6 and y>1 and y<8):
     tile=1+(x*2+y*3)%7
    if y==3 and x>=3 and x<=5:
     tile=4
   if tile>0:
    _crystal(square.grow(-.45),tile)

func _card(rect:Rect2,index:int) -> void:
 var active:bool=rect.has_point(touch_position)
 var main_color:Color=Color("#11e3ff") if index==0 else Color("#eb68ff")
 var glow_color:Color=Color("#1c93f6") if index==0 else Color("#a44dfb")
 var offset:float=sin(clock*(1.3 if index==0 else 1.45)+float(index)*1.9)*1.9
 var card:=Rect2(rect.position+Vector2(0,offset),rect.size)
 _glass(card,
  Color(.12,.19,.48,.90) if index==0 else Color(.22,.12,.45,.92),
  Color(.38,.91,1.0,.86) if index==0 else Color(.92,.51,1.0,.91),true)
 var text_left:float=card.position.x+18
 var text_top:float=card.position.y+38
 _label("01   SWEET PUZZLE" if index==0 else "02   JELLY SURVIVAL",
  Vector2(text_left,text_top),11,Color("#bdeafa") if index==0 else Color("#f3c6ff"))
 _label("BLOCK" if index==0 else "BLOCK",Vector2(text_left,text_top+33),
  30,Color.WHITE)
 _label("PUZZLE" if index==0 else "FALL",Vector2(text_left,text_top+65),
  29,main_color)
 _label("3D CANDIES  /  SWEET COMBOS" if index==0 else "3D JELLIES  /  ARCADE ACTION",
  Vector2(text_left,text_top+85),9,Color("#d2dcff"))
 var tag:=Rect2(Vector2(text_left,card.end.y-44),Vector2(minf(145,card.size.x*.49),30))
 _glass(tag,Color(.02,.30,.45,.88) if index==0 else Color(.35,.11,.44,.88),
  Color(main_color.r,main_color.g,main_color.b,.9))
 _label("PLAY  ▶",Vector2(tag.position.x,tag.position.y+21),14,Color.WHITE,
  HORIZONTAL_ALIGNMENT_CENTER,tag.size.x)
 var preview_width:float=minf(144,card.size.x*.40)
 var board_rect:=Rect2(Vector2(card.end.x-preview_width-14,card.position.y+19),
  Vector2(preview_width,card.size.y-37))
 _mini_board(board_rect,index==1)
 if active:
  draw_arc(card.get_center(),card.size.x*.48,-.6,1.4,22,
   Color(main_color.r,main_color.g,main_color.b,.18),3.0,true)
 draw_circle(Vector2(card.end.x-10,card.position.y+8),3.0,glow_color)

func _draw() -> void:
 var view:Vector2=get_viewport_rect().size
 _starfield(view)
 _planet(Vector2(view.x*.80,view.y*.15),view.x*.145,Color("#161552"),Color("#bb63ff"))
 _planet(Vector2(view.x*.18,view.y*.22),view.x*.065,Color("#06416a"),Color("#60dfff"))
 # Real 3D jelly candy meshes float next to the brand; render once from
 # the same reusable physically-lit atlas used during actual gameplay.
 for sweet in [
  {"kind":1,"x":view.x*.07,"y":view.y*.082,"size":55.0,"period":1.8},
  {"kind":2,"x":view.x*.81,"y":view.y*.20,"size":62.0,"period":1.3},
  {"kind":5,"x":view.x*.018,"y":view.y*.79,"size":54.0,"period":1.5}
 ]:
  var candy:Texture2D=visuals.get_gem_texture(int(sweet["kind"]))
  if candy!=null:
   var side:float=float(sweet["size"])
   var bob:float=sin(clock*float(sweet["period"]))*6.0
   var p:=Vector2(float(sweet["x"]),float(sweet["y"])+bob)
   var tint:Color=GEMS[int(sweet["kind"])]
   draw_circle(p+Vector2(side*.5,side*.5),side*.48,Color(tint.r,tint.g,tint.b,.12))
   draw_texture_rect(candy,Rect2(p,Vector2(side,side)),false,Color(1,1,1,.82))
 var center:float=view.x*.5
 _label("NOVA",Vector2(0,110),55,Color("#1587ef"),HORIZONTAL_ALIGNMENT_CENTER,view.x)
 _label("NOVA",Vector2(0,106),55,Color("#f6fcff"),HORIZONTAL_ALIGNMENT_CENTER,view.x)
 _label("G R I D",Vector2(0,144),27,Color("#9bf9ff"),HORIZONTAL_ALIGNMENT_CENTER,view.x)
 _label("3 D    C A N D Y    G A L A X Y",Vector2(0,171),14,Color("#ffd3ff"),HORIZONTAL_ALIGNMENT_CENTER,view.x)
 var cards:Array[Rect2]=_rectangles()
 _label("C H O O S E    Y O U R    C A N D Y    W O R L D",
  Vector2(0,cards[0].position.y-23),12,Color("#bbd8fd"),HORIZONTAL_ALIGNMENT_CENTER,view.x)
 for i in 2:
  _card(cards[i],i)
 var footer_y:float=cards[1].end.y+20
 if footer_y<view.y-84:
  var footer:=Rect2(Vector2(21,footer_y),Vector2(view.x-42,minf(70,view.y-106-footer_y)))
  _glass(footer,Color(.08,.13,.33,.70),Color(.47,.67,1.0,.48))
  _label("★  GROW YOUR LEGEND",Vector2(footer.position.x+12,footer.position.y+22),
   14,Color("#ffe196"))
  _label("RANKS  •  COMBOS  •  RARE CANDY BOMBS",
   Vector2(footer.position.x+12,footer.position.y+43),10,Color("#c2e1ff"))
 _label("ORIGINAL 3D CANDY ARCADE  •  NO PAY-TO-WIN",
  Vector2(0,view.y-29),10,Color(.72,.82,1.0,.82),HORIZONTAL_ALIGNMENT_CENTER,view.x)
 if chosen>=0:
  draw_rect(Rect2(Vector2.ZERO,view),Color(.02,.02,.08,clampf(transition_elapsed/.28,0.0,1.0)),true)

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
