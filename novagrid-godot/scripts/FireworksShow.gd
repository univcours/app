extends Node2D
## Native mobile-friendly sky fireworks. Never touches gameplay, points or ads.
const COLORS=[Color("#ff38df"),Color("#45f0ff"),Color("#ffe34a"),
 Color("#aa62ff"),Color("#59ff85"),Color("#ff9145")]
const MAX_SPARKS=180
const MAX_LOW_SPARKS=48
const MAX_LETTERS=270
const MAX_LOW_LETTERS=72
# A tiny original pixel alphabet allows a player's Latin name to be made
# from real individually moving luminous fragments, without using a texture.
const FONT={
"A":"01110/10001/10001/11111/10001/10001/10001",
"B":"11110/10001/10001/11110/10001/10001/11110",
"C":"01111/10000/10000/10000/10000/10000/01111",
"D":"11110/10001/10001/10001/10001/10001/11110",
"E":"11111/10000/10000/11110/10000/10000/11111",
"F":"11111/10000/10000/11110/10000/10000/10000",
"G":"01111/10000/10000/10111/10001/10001/01111",
"H":"10001/10001/10001/11111/10001/10001/10001",
"I":"11111/00100/00100/00100/00100/00100/11111",
"J":"00111/00010/00010/00010/10010/10010/01100",
"K":"10001/10010/10100/11000/10100/10010/10001",
"L":"10000/10000/10000/10000/10000/10000/11111",
"M":"10001/11011/10101/10101/10001/10001/10001",
"N":"10001/11001/10101/10011/10001/10001/10001",
"O":"01110/10001/10001/10001/10001/10001/01110",
"P":"11110/10001/10001/11110/10000/10000/10000",
"Q":"01110/10001/10001/10001/10101/10010/01101",
"R":"11110/10001/10001/11110/10100/10010/10001",
"S":"01111/10000/10000/01110/00001/00001/11110",
"T":"11111/00100/00100/00100/00100/00100/00100",
"U":"10001/10001/10001/10001/10001/10001/01110",
"V":"10001/10001/10001/10001/10001/01010/00100",
"W":"10001/10001/10001/10101/10101/10101/01010",
"X":"10001/10001/01010/00100/01010/10001/10001",
"Y":"10001/10001/01010/00100/00100/00100/00100",
"Z":"11111/00001/00010/00100/01000/10000/11111",
"0":"01110/10001/10011/10101/11001/10001/01110",
"1":"00100/01100/00100/00100/00100/00100/01110",
"2":"01110/10001/00001/00010/00100/01000/11111",
"3":"11110/00001/00001/01110/00001/00001/11110",
"4":"00010/00110/01010/10010/11111/00010/00010",
"5":"11111/10000/10000/11110/00001/00001/11110",
"6":"01111/10000/10000/11110/10001/10001/01110",
"7":"11111/00001/00010/00100/01000/01000/01000",
"8":"01110/10001/10001/01110/10001/10001/01110",
"9":"01110/10001/10001/01111/00001/00001/11110",
"-":"00000/00000/00000/11111/00000/00000/00000",
"_":"00000/00000/00000/00000/00000/00000/11111",
" ":"00000/00000/00000/00000/00000/00000/00000"}

var particles:Array=[]
var shells:Array=[]
var letters:Array=[]
var active:bool=false
var age:float=0.0
var tier:int=0
var reduced_effects:bool=false
var player_name:String="NOVA PLAYER"
var name_emitted:bool=false
var unicode_label:bool=false
var display_zone:Rect2=Rect2()
var gen:=RandomNumberGenerator.new()

static func tier_for_groups(groups:int)->int:
 if groups<=0:return 0
 return mini(groups,4)

static func level_label(groups:int)->String:
 match tier_for_groups(groups):
  1:return "STAR CLEAR"
  2:return "DOUBLE FIREWORKS"
  3:return "MEGA FIREWORKS"
  4:return "LEGENDARY FIREWORKS"
 return ""

func launch(groups:int,board:Rect2,nickname:String="NOVA PLAYER",low_fx:bool=false)->void:
 reset_show()
 tier=tier_for_groups(groups)
 if tier==0:return
 active=true
 reduced_effects=low_fx
 player_name=nickname.strip_edges().substr(0,16)
 if player_name.is_empty():player_name="NOVA PLAYER"
 display_zone=board
 gen.randomize()
 var quantity:int=[0,1,2,3,5][tier]
 if reduced_effects:quantity=mini(quantity,2)
 for i in quantity:
  var spread:float=(float(i)-float(quantity-1)*.5)*board.size.x*.18
  var goal:=Vector2(board.get_center().x+spread,
   maxf(98.0,board.position.y-18.0+float(i%3)*25.0))
  var start:=Vector2(board.get_center().x+spread*.3,board.end.y-10.0)
  shells.append({"start":start,"goal":goal,"delay":float(i)*.23,
   "exploded":false,"color":COLORS[(i+groups)%COLORS.size()]})
 queue_redraw()

func reset_show()->void:
 particles.clear()
 shells.clear()
 letters.clear()
 active=false
 age=0.0
 tier=0
 name_emitted=false
 unicode_label=false
 queue_redraw()

func _process(delta:float)->void:
 if not active:return
 # Don't simulate a multi-second background gap on returning to the game.
 delta=minf(delta,.07)
 age+=delta
 for i in range(shells.size()):
  var rocket:Dictionary=shells[i]
  if not bool(rocket["exploded"]) and age>=float(rocket["delay"])+.36:
   rocket["exploded"]=true
   shells[i]=rocket
   _explode(rocket["goal"],rocket["color"],i)
 for i in range(particles.size()-1,-1,-1):
  var p:Dictionary=particles[i]
  p["life"]=float(p["life"])-delta
  if float(p["life"])<=0.0:
   particles.remove_at(i)
   continue
  p["pos"]=Vector2(p["pos"])+Vector2(p["velocity"])*delta
  p["velocity"]=Vector2(p["velocity"])*maxf(0.0,1.0-delta*.42)+Vector2(0,90.0*delta)
  particles[i]=p
 if tier==4:
  if age>=1.0 and not name_emitted:
   name_emitted=true
   _write_name_in_sparks()
  for i in range(letters.size()):
   var p:Dictionary=letters[i]
   if age<1.75:
    p["pos"]=Vector2(p["pos"]).lerp(Vector2(p["target"]),clampf(delta*13.0,0.0,1.0))
   elif age>=2.8:
    p["velocity"]=Vector2(p["velocity"])+Vector2(0,160.0*delta)
    p["pos"]=Vector2(p["pos"])+Vector2(p["velocity"])*delta
   else:
    p["pos"]=Vector2(p["target"])
   letters[i]=p
 if age>5.0:reset_show()
 else:queue_redraw()

func _explode(center:Vector2,color:Color,shell_index:int)->void:
 var quantity:int=20+tier*10
 if reduced_effects:quantity=13
 var capacity:int=MAX_LOW_SPARKS if reduced_effects else MAX_SPARKS
 for i in quantity:
  if particles.size()>=capacity:break
  var angle:float=TAU*(float(i)/float(quantity)+gen.randf_range(-.012,.012))
  var force:float=gen.randf_range(65.0,110.0)+float(tier)*15.0
  var tint:Color=color.lerp(COLORS[(i+shell_index)%COLORS.size()],.72)
  particles.append({"pos":center,"velocity":Vector2(cos(angle),sin(angle))*force,
   "life":gen.randf_range(.90,1.5),"max_life":1.5,
   "color":tint,"size":gen.randf_range(1.2,2.6)})

func _write_name_in_sparks()->void:
 var upper:String=player_name.to_upper()
 for c in upper:
  if not FONT.has(c):
   unicode_label=true
   return
 var dot:float=minf(3.9,display_zone.size.x/(float(maxi(1,upper.length()))*6.4))
 var width:float=float(upper.length()*6-1)*dot
 var left:float=display_zone.get_center().x-width*.5
 var top:float=display_zone.position.y+maxf(36.0,display_zone.size.y*.19)
 # Generate all glyph positions before capping so no player's name is cut off.
 var points:Array[Vector2]=[]
 for index in range(upper.length()):
  var rows:PackedStringArray=String(FONT[upper.substr(index,1)]).split("/")
  for y in range(rows.size()):
   for x in range(rows[y].length()):
    if rows[y].substr(x,1)=="1":
     points.append(Vector2(left+float(index*6+x)*dot,top+float(y)*dot))
 var capacity:int=MAX_LOW_LETTERS if reduced_effects else MAX_LETTERS
 if points.size()>capacity:
  # Preserve the actual name in all writing systems and accessibility modes.
  unicode_label=true
  return
 for i in range(points.size()):
  var target:Vector2=points[i]
  letters.append({"pos":target+Vector2(gen.randf_range(-75,75),gen.randf_range(55,125)),
   "target":target,"velocity":Vector2(gen.randf_range(-28,28),gen.randf_range(-65,-15)),
   "color":COLORS[i%COLORS.size()]})

func _draw()->void:
 if not active:return
 for shell in shells:
  if bool(shell["exploded"]):continue
  var t:float=(age-float(shell["delay"]))/.36
  if t<=0.0 or t>=1.0:continue
  var pos:Vector2=Vector2(shell["start"]).lerp(Vector2(shell["goal"]),t)
  var tint:Color=shell["color"]
  draw_line(pos+Vector2(0,18),pos,Color(tint.r,tint.g,tint.b,.38),5,true)
  draw_line(pos+Vector2(0,12),pos,Color(1,1,1,.92),1.5,true)
  draw_circle(pos,3.2,tint)
 for p in particles:
  var fade:float=clampf(float(p["life"])/float(p["max_life"]),0.0,1.0)
  var pos:Vector2=p["pos"]
  var v:Vector2=p["velocity"]
  var color:Color=p["color"]
  draw_line(pos-v.normalized()*minf(14.0,v.length()*.09),pos,
   Color(color.r,color.g,color.b,fade*.66),2.9,true)
  draw_circle(pos,maxf(.4,float(p["size"])*fade*1.6),
   Color(color.r,color.g,color.b,fade*.22))
  draw_circle(pos,maxf(.38,float(p["size"])*fade*.65),Color(1,1,1,fade*.95))
 if tier==4 and age>=1.0 and age<=4.5:
  var alpha:float=clampf((4.5-age)*.9,0.0,1.0)
  if unicode_label and age<2.82:
   # Exact Arabic/non-Latin nickname, not replaced with generic ASCII.
   var pos:=Vector2(display_zone.position.x,display_zone.position.y+display_zone.size.y*.30)
   draw_string(ThemeDB.fallback_font,pos,player_name,
    HORIZONTAL_ALIGNMENT_CENTER,display_zone.size.x,24,Color(1,.90,.67,alpha))
  for letter in letters:
   var pos:Vector2=letter["pos"]
   var color:Color=letter["color"]
   draw_circle(pos,3.3,Color(color.r,color.g,color.b,alpha*.23))
   draw_circle(pos,1.55,Color(1,1,1,alpha))
