extends RefCounted
## Convert the physical Android safe rectangle into the logical canvas.
static func content_rect(viewport:Vector2,physical:Vector2=Vector2.ZERO,safe:Rect2=Rect2()) -> Rect2:
 var window:Vector2=physical
 var area:Rect2=safe
 if window==Vector2.ZERO:
  if OS.get_name()!="Android" and OS.get_name()!="iOS":
   return Rect2(Vector2.ZERO,viewport)
  window=Vector2(DisplayServer.window_get_size())
  area=Rect2(DisplayServer.get_display_safe_area())
 if window.x<=0 or window.y<=0 or not area.has_area():
  return Rect2(Vector2.ZERO,viewport)
 var ratio:Vector2=viewport/window
 return Rect2(area.position*ratio,area.size*ratio).intersection(Rect2(Vector2.ZERO,viewport))
