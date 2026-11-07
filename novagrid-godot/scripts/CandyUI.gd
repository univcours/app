extends RefCounted
## Original Candy Galaxy vector UI. Drawn inside the same CanvasItem as real
## gameplay: no texture atlas downloads, no copyrighted fonts or screenshots.
## All panels are cached by visual parameters to avoid per-frame allocations.
const PINK=Color("#ff79c9")
const MINT=Color("#80f9df")
const LILAC=Color("#c69cff")
const CREAM=Color("#fff4d6")
const OUTLINE=Color("#562163")
const SHADOW=Color("#230c43")
static var _cached_styles:Dictionary={}

static func candy_text(canvas:CanvasItem,font:Font,message:String,pos:Vector2,
 size:int,ink:Color=Color.WHITE,
 alignment:HorizontalAlignment=HORIZONTAL_ALIGNMENT_LEFT,
 width:float=-1.0) -> void:
 if message.is_empty() or font==null:
  return
 var strong:bool=size>=18
 var stroke:int=3 if strong else (2 if size>=12 else 1)
 var rim:Color=OUTLINE if strong else Color("#401853")
 # Each letter AND number has a dark jelly extrusion, sugar rim and pearly face.
 canvas.draw_string_outline(font,pos+Vector2(1.4,2.7),message,alignment,width,
  size,stroke+1,Color(SHADOW.r,SHADOW.g,SHADOW.b,.9))
 canvas.draw_string_outline(font,pos,message,alignment,width,size,stroke,rim)
 var face:Color=ink.lerp(CREAM,.12) if strong else ink
 canvas.draw_string(font,pos,message,alignment,width,size,face)
 if size>=16:
  # Raised white edge on each glyph, not a detached glow behind the label.
  canvas.draw_string(font,pos+Vector2(-.5,-.8),message,alignment,width,size,
   Color(1,1,1,.22))

static func _panel_style(fill:Color,edge:Color,strong:bool) -> StyleBoxFlat:
 var key:String=fill.to_html(true)+"|"+edge.to_html(true)+("|1" if strong else "|0")
 if _cached_styles.has(key):
  return _cached_styles[key]
 var style:=StyleBoxFlat.new()
 style.bg_color=fill
 style.border_color=edge
 style.set_corner_radius_all(21 if strong else 14)
 style.set_border_width_all(3 if strong else 2)
 style.shadow_color=Color(.17,.03,.28,.68)
 style.shadow_size=11 if strong else 6
 style.shadow_offset=Vector2(0,4 if strong else 2)
 style.anti_aliasing=true
 style.anti_aliasing_size=1.0
 _cached_styles[key]=style
 return style

static func candy_panel(canvas:CanvasItem,box:Rect2,base:Color,edge:Color,
 strong:bool=false,clock:float=0.0) -> void:
 if box.size.x<=2 or box.size.y<=2:
  return
 var tint:Color=base.lerp(Color("#8d3689"),.20)
 # Keep background dark enough that the glass candy tiles remain readable.
 tint.a=base.a
 canvas.draw_style_box(_panel_style(tint,edge,strong),box)
 var left:float=box.position.x
 var right:float=box.end.x
 var top:float=box.position.y
 var bottom:float=box.end.y
 var radius:float=16.0 if strong else 10.0
 if box.size.x>40.0 and box.size.y>15.0:
  canvas.draw_line(Vector2(left+radius,top+3),Vector2(right-radius,top+3),
   Color("#fff6ff")*Color(1,1,1,.7),2.2 if strong else 1.35,true)
  canvas.draw_line(Vector2(left+radius,top+6),Vector2(right-radius,top+6),
   Color(edge.r,edge.g,edge.b,.38),1.6,true)
  canvas.draw_line(Vector2(left+radius,bottom-3),Vector2(right-radius,bottom-3),
   Color("#3f175f"),2.0,true)
 if box.size.x>80.0 and box.size.y>34.0:
  var x:float=left+radius+fposmod(clock*15.0,maxf(1.0,box.size.x-2.0*radius))
  var sparkle:Color=Color(1,.96,1,.27)
  canvas.draw_circle(Vector2(x,top+5),2.1,sparkle)
  canvas.draw_circle(Vector2(right-13,top+12),2.4,Color(1,1,1,.4))

static func candy_button(canvas:CanvasItem,box:Rect2,caption:String,font:Font,
 active:bool=false,small:bool=false,clock:float=0.0) -> void:
 var fill:Color=Color("#d943ad") if active else Color("#6852bf")
 var edge:Color=Color("#ffe5a8") if active else Color("#bcefff")
 candy_panel(canvas,box,fill,edge,true,clock)
 if box.size.y>23:
  canvas.draw_line(box.position+Vector2(13,box.size.y*.29),
   box.position+Vector2(box.size.x-13,box.size.y*.29),
   Color(1,.91,1,.42),1.0,true)
 var size:int=12 if small else 14
 candy_text(canvas,font,caption,Vector2(box.position.x,box.position.y+box.size.y*.64),
  size,CREAM,HORIZONTAL_ALIGNMENT_CENTER,box.size.x)

static func candy_badge(canvas:CanvasItem,box:Rect2,title:String,font:Font,
 accent:Color=PINK,clock:float=0.0) -> void:
 candy_panel(canvas,box,Color("#722e81"),accent,false,clock)
 candy_text(canvas,font,title,Vector2(box.position.x,box.position.y+box.size.y*.67),
  12,CREAM,HORIZONTAL_ALIGNMENT_CENTER,box.size.x)

static func candy_meter(canvas:CanvasItem,rect:Rect2,value:float,
 accent:Color=PINK,clock:float=0.0) -> void:
 if rect.size.x<3.0 or rect.size.y<3.0:
  return
 var amount:float=clampf(value,0.0,1.0)
 var track:Color=Color("#2e174d")
 canvas.draw_rect(rect,track,true)
 canvas.draw_rect(rect,Color("#e7c9ff"),false,1.0)
 var inner:Rect2=rect.grow(-1.6)
 inner.size.x*=amount
 if inner.size.x<=0.0:
  return
 canvas.draw_rect(inner,accent,true)
 canvas.draw_line(inner.position+Vector2(0,1),
  Vector2(inner.end.x,inner.position.y+1),Color(1,1,1,.77),1.2,true)
 canvas.draw_line(Vector2(inner.position.x,inner.end.y-1),
  inner.end-Vector2(0,1),Color("#492269"),1.1,true)
 if inner.size.x>16.0:
  var shimmer_x:float=inner.position.x+fposmod(clock*18.0,inner.size.x)
  canvas.draw_circle(Vector2(shimmer_x,inner.get_center().y),1.6,Color(1,1,1,.6))

static func reset_style_cache() -> void:
 _cached_styles.clear()
