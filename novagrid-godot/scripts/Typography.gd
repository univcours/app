extends RefCounted
## NovaGrid's complete and exclusive text-font policy.
## Orbitron: logos/headings; Oxanium: buttons/menus; Inter: UI and small text.
## All three fonts are bundled under the SIL Open Font License.
const ORBITRON:Font = preload("res://assets/fonts/Orbitron.ttf")
const OXANIUM:Font = preload("res://assets/fonts/Oxanium.ttf")
const INTER:Font = preload("res://assets/fonts/Inter.ttf")

static func covers(face:Font,value:String) -> bool:
 for index in value.length():
  var code:int=value.unicode_at(index)
  if code!=10 and code!=13 and code!=9 and not face.has_char(code):
   return false
 return true

static func font_for(value:String,point_size:int) -> Font:
 # The same policy applies in every menu, HUD, stage and pause overlay.
 var primary:Font=ORBITRON if point_size>=28 else OXANIUM if point_size>=16 else INTER
 if covers(primary,value):
  return primary
 # If special characters or French accents are missing from a display font,
 # resolve them ONLY through one of the other two approved typefaces.
 for candidate:Font in [INTER,OXANIUM,ORBITRON]:
  if covers(candidate,value):
   return candidate
 # No system/default/third-party fallback is ever used.
 return INTER

static func draw_neon(canvas:CanvasItem,value:String,position:Vector2,
 point_size:int,color:Color=Color.WHITE,
 alignment:HorizontalAlignment=HORIZONTAL_ALIGNMENT_LEFT,width:float=-1.0) -> void:
 var face:Font=font_for(value,point_size)
 var render_size:int=point_size
 # Fit long French labels inside the same touch targets without truncation.
 if width>0.0:
  while render_size>11 and face.get_string_size(value,HORIZONTAL_ALIGNMENT_LEFT,-1.0,render_size).x>width-5.0:
   render_size-=1
 var tint:Color=color
 if point_size>=28:
  canvas.draw_string_outline(face,position,value,alignment,width,render_size,7,
   Color(tint.r,tint.g,tint.b,.11))
  canvas.draw_string_outline(face,position,value,alignment,width,render_size,4,
   Color(tint.r,tint.g,tint.b,.27))
  canvas.draw_string_outline(face,position,value,alignment,width,render_size,2,
   Color(tint.r,tint.g,tint.b,.47))
 elif point_size>=16:
  canvas.draw_string_outline(face,position,value,alignment,width,render_size,3,
   Color(tint.r,tint.g,tint.b,.21))
  canvas.draw_string_outline(face,position,value,alignment,width,render_size,1,
   Color(tint.r,tint.g,tint.b,.32))
 else:
  canvas.draw_string_outline(face,position,value,alignment,width,render_size,1,
   Color(tint.r,tint.g,tint.b,.23))
 canvas.draw_string(face,position,value,alignment,width,render_size,color)
