extends RefCounted
## Premium cosmic neon design language. Godot-native panels, icons and controls.
const Typography=preload("res://scripts/Typography.gd")
const NAVY=Color("#06102f")
const CYAN=Color("#00ddff")
const PINK=Color("#ff31ed")
const BLUE=Color("#0985ff")
const WHITE=Color("#f6fbff")
static var cache:Dictionary={}

static func _style(fill:Color,accent:Color,radius:int,active:bool)->StyleBoxFlat:
 var key:String=fill.to_html(true)+accent.to_html(true)+str(radius)+str(active)
 if not cache.has(key):
  var st:=StyleBoxFlat.new()
  st.bg_color=fill
  st.border_color=accent.lightened(.19)
  st.set_corner_radius_all(radius)
  st.set_border_width_all(3 if active else 2)
  st.shadow_color=Color(accent.r,accent.g,accent.b,.52 if active else .38)
  st.shadow_size=19 if active else 15
  st.shadow_offset=Vector2.ZERO
  cache[key]=st
 return cache[key] as StyleBoxFlat

static func beam(c:CanvasItem,a:Vector2,b:Vector2,hue:Color,width:float=1.7)->void:
 c.draw_line(a,b,Color(hue.r,hue.g,hue.b,.16),width*4.5,true)
 c.draw_line(a,b,Color(hue.r,hue.g,hue.b,.50),width*2.0,true)
 c.draw_line(a,b,hue.lightened(.37),width,true)

static func panel(c:CanvasItem,r:Rect2,accent:Color,
 fill:Color=Color("#081337"),radius:int=20,clock:float=0.0,active:bool=false)->void:
 if r.size.x<=0 or r.size.y<=0:return
 c.draw_style_box(_style(fill,accent,radius,active),r)
 if r.size.x<65 or r.size.y<22:return
 var pad:float=minf(radius+2,r.size.x*.18)
 var p:=r.position
 var e:=r.end
 var sheen:=PackedVector2Array([
  Vector2(p.x+pad,p.y+4),Vector2(e.x-pad,p.y+4),
  Vector2(e.x-pad-18,p.y+r.size.y*.41),
  Vector2(p.x+pad+8,p.y+r.size.y*.41)])
 c.draw_colored_polygon(sheen,Color(.32,.63,1,.075))
 c.draw_line(Vector2(p.x+pad,p.y+3),Vector2(e.x-pad,p.y+3),
  Color(1,1,1,.66),1.4,true)
 c.draw_line(Vector2(p.x+pad,p.y+6),Vector2(e.x-pad,p.y+6),
  Color(accent.r,accent.g,accent.b,.35),1.2,true)
 c.draw_line(Vector2(p.x+pad,e.y-3),Vector2(e.x-pad,e.y-3),
  Color(accent.r,accent.g,accent.b,.5),1.4,true)
 # Specular sweep over the edge; coordinates never shift touch targets.
 var shine_x:float=lerpf(p.x+pad,e.x-pad,fposmod(clock*.22+p.y*.0009,1.0))
 c.draw_line(Vector2(shine_x-10,p.y+3),Vector2(shine_x+10,p.y+3),
  Color(1,1,1,.35+.18*sin(clock*2)),2,true)
 c.draw_line(Vector2(p.x+pad+4,e.y-6),Vector2(p.x+r.size.x*.27,e.y-6),
  Color(PINK.r,PINK.g,PINK.b,.42),1.2,true)

static func star(c:CanvasItem,center:Vector2,radius:float,color:Color)->void:
 var vertices:=PackedVector2Array()
 for i in 10:
  var angle:float=-PI*.5+float(i)*PI/5
  vertices.append(center+Vector2(cos(angle),sin(angle))*(radius if i%2==0 else radius*.46))
 vertices.append(vertices[0])
 c.draw_polyline(vertices,Color(color.r,color.g,color.b,.17),5,true)
 c.draw_polyline(vertices,color,2,true)

static func icon(c:CanvasItem,kind:String,at:Vector2,size:float,tint:Color)->void:
 var u:float=size/24
 match kind:
  "classic","modes":
   for x in 2:
    for y in 2:
     var p:Vector2=at+Vector2((x-.5)*13,(y-.5)*13)*u
     c.draw_rect(Rect2(p-Vector2.ONE*4.7*u,Vector2.ONE*9.4*u),
      Color(tint.r,tint.g,tint.b,.14),true)
     c.draw_rect(Rect2(p-Vector2.ONE*4.7*u,Vector2.ONE*9.4*u),
      tint,false,1.8*u)
  "daily":
   c.draw_rect(Rect2(at-Vector2(11,10)*u,Vector2(22,21)*u),tint,false,2*u)
   beam(c,at+Vector2(-10,-3)*u,at+Vector2(10,-3)*u,tint,1.2*u)
   for x in [-5,2,9]:
    for y in [2,8]: c.draw_circle(at+Vector2(x,y)*u,1.5*u,tint)
  "blockfall":
   for p in [Vector2(0,-12),Vector2(-8,-4),Vector2(0,-4),Vector2(-16,4),Vector2(-8,4)]:
    c.draw_rect(Rect2(at+p*u,Vector2.ONE*7*u),tint,false,1.8*u)
  "galaxy","progress":
   c.draw_arc(at,11*u,-1.3,PI+1,34,tint,2*u,true)
   c.draw_arc(at,16*u,.5,PI+.1,34,tint,1.5*u,true)
   star(c,at,6*u,tint)
  "home":
   beam(c,at+Vector2(-11,0)*u,at+Vector2(0,-10)*u,tint,1.3*u)
   beam(c,at+Vector2(0,-10)*u,at+Vector2(11,0)*u,tint,1.3*u)
   beam(c,at+Vector2(-8,-1)*u,at+Vector2(-8,10)*u,tint,1.3*u)
   beam(c,at+Vector2(8,-1)*u,at+Vector2(8,10)*u,tint,1.3*u)
   beam(c,at+Vector2(-8,10)*u,at+Vector2(8,10)*u,tint,1.3*u)
  "settings":
   c.draw_arc(at,9*u,0,TAU,40,tint,2*u,true)
   c.draw_arc(at,4*u,0,TAU,32,tint,1.7*u,true)
   for i in 8:
    var d:Vector2=Vector2.RIGHT.rotated(i*TAU/8.0)
    beam(c,at+d*11*u,at+d*14*u,tint,1.3*u)
  "back":
   beam(c,at+Vector2(4,-9)*u,at+Vector2(-5,0)*u,tint,2*u)
   beam(c,at+Vector2(-5,0)*u,at+Vector2(4,9)*u,tint,2*u)
  "settings":
   c.draw_arc(at,9.0*u,0,TAU,48,tint,2.2*u,true)
   c.draw_arc(at,3.8*u,0,TAU,32,tint,2.0*u,true)
   for i in 8:
    var d:Vector2=Vector2.RIGHT.rotated(float(i)*TAU/8.0)
    beam(c,at+d*11*u,at+d*14*u,tint,1.4*u)
  "sound":
   beam(c,at+Vector2(-11,-5)*u,at+Vector2(-5,-5)*u,tint,1.7*u)
   beam(c,at+Vector2(-5,-5)*u,at+Vector2(1,-10)*u,tint,1.7*u)
   beam(c,at+Vector2(1,-10)*u,at+Vector2(1,10)*u,tint,1.7*u)
   beam(c,at+Vector2(1,10)*u,at+Vector2(-5,5)*u,tint,1.7*u)
   beam(c,at+Vector2(-5,5)*u,at+Vector2(-11,5)*u,tint,1.7*u)
   c.draw_arc(at+Vector2(1,0)*u,8*u,-PI*.48,PI*.48,24,tint,1.8*u,true)
  "music":
   beam(c,at+Vector2(0,-12)*u,at+Vector2(0,7)*u,tint,2.2*u)
   beam(c,at+Vector2(0,-12)*u,at+Vector2(11,-9)*u,tint,2.2*u)
   beam(c,at+Vector2(11,-9)*u,at+Vector2(11,5)*u,tint,2.2*u)
   c.draw_circle(at+Vector2(-4,8)*u,4.4*u,tint)
   c.draw_circle(at+Vector2(7,6)*u,4.4*u,tint)
  "effects":
   star(c,at,11*u,tint)
   star(c,at+Vector2(11,-9)*u,5*u,CYAN)
  "language":
   c.draw_arc(at,12*u,0,TAU,48,tint,1.8*u,true)
   c.draw_arc(at,7*u,-PI*.5,PI*.5,30,tint,1.4*u,true)
   c.draw_arc(at,7*u,PI*.5,PI*1.5,30,tint,1.4*u,true)
   beam(c,at+Vector2(-11,0)*u,at+Vector2(11,0)*u,tint,1.0*u)
   beam(c,at+Vector2(0,-12)*u,at+Vector2(0,12)*u,tint,1.0*u)
  "pause":
   c.draw_rect(Rect2(at+Vector2(-6,-10)*u,Vector2(4,20)*u),tint,true)
   c.draw_rect(Rect2(at+Vector2(2,-10)*u,Vector2(4,20)*u),tint,true)
  _:
   star(c,at,11*u,tint)

static func logo(c:CanvasItem,baseline:float,size:int,time:float)->void:
 # The two-tone Orbitron wordmark from the user's approved style reference.
 var face:Font=Typography.ORBITRON
 var left_width:float=face.get_string_size("Nova",HORIZONTAL_ALIGNMENT_LEFT,-1,size).x
 var right_width:float=face.get_string_size("Grid",HORIZONTAL_ALIGNMENT_LEFT,-1,size).x
 var x:float=(432.0-left_width-right_width)*.5
 Typography.draw_neon(c,"Nova",Vector2(x,baseline),size,Color("#b4f7ff"))
 Typography.draw_neon(c,"Grid",Vector2(x+left_width,baseline),size,Color("#ffc1ff"))
 # Energetic cyan and pink accent beams, never added to touch coordinates.
 c.draw_arc(Vector2(220,baseline-10),146,-PI*.63,-PI*.17,48,
  Color(CYAN.r,CYAN.g,CYAN.b,.35),1.8,true)
 c.draw_arc(Vector2(220,baseline-13),153,PI*.28,PI*.67,48,
  Color(PINK.r,PINK.g,PINK.b,.32),1.8,true)
 var sparkle_x:float=77+fposmod(time*24,285.0)
 star(c,Vector2(sparkle_x,baseline-55),3.5,CYAN)

static func mode_button(c:CanvasItem,r:Rect2,title:String,subtitle:String,
 kind:String,color:Color,clock:float,pressed:bool=false)->void:
 panel(c,r,color,Color("#081737"),23,clock,pressed)
 var center:Vector2=r.position+Vector2(35,r.size.y*.5)
 icon(c,kind,center,32,color)
 beam(c,r.position+Vector2(70,16),Vector2(r.position.x+70,r.end.y-16),color,1)
 Typography.draw_neon(c,title,r.position+Vector2(88,35),24,WHITE,
  HORIZONTAL_ALIGNMENT_LEFT,r.size.x-138)
 Typography.draw_neon(c,subtitle,r.position+Vector2(89,60),13,Color("#bddafa"),
  HORIZONTAL_ALIGNMENT_LEFT,r.size.x-145)
 for j in 2:
  var x:float=r.end.x-23+j*7
  beam(c,Vector2(x-6,r.position.y+31),Vector2(x,r.position.y+42),color,1.3)
  beam(c,Vector2(x,r.position.y+42),Vector2(x-6,r.position.y+53),color,1.3)

static func navigation(c:CanvasItem,r:Rect2,items:Array,selected:int,time:float)->void:
 panel(c,r,PINK,Color("#07102e"),16,time)
 var step:float=r.size.x/float(items.size())
 for i in items.size():
  var q:=Rect2(r.position+Vector2(i*step+3,3),Vector2(step-6,r.size.y-6))
  if i==selected:panel(c,q,CYAN,Color("#073974"),12,time,true)
  elif i>0:c.draw_line(q.position+Vector2(0,8),q.position+Vector2(0,q.size.y-8),Color("#7496ff",.55),1,true)
  icon(c,"home" if i==0 else "galaxy" if i==1 else "settings",q.position+Vector2(q.size.x*.5,11),16,
   CYAN if i==selected else PINK)
  Typography.draw_neon(c,String(items[i]),q.position+Vector2(0,q.size.y-6),11,WHITE,
   HORIZONTAL_ALIGNMENT_CENTER,q.size.x)
