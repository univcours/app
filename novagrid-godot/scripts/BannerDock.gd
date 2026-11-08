extends RefCounted
## NovaGrid dedicated native Android banner dock.
## Godot uses logical pixels; Poing AdMob returns native physical pixels.
## The native banner is anchored at BOTTOM within the Android safe area.
const GAP:float=9.0

static func logical_reservation(physical_banner_px:float,logical_view:Vector2,
 native_window:Vector2)->float:
 if physical_banner_px<=0.0 or logical_view.y<=0.0 or native_window.y<=0.0:
  return 0.0
 # Round UP so the advert and its entire touch surface remain below the game.
 return ceil(physical_banner_px*logical_view.y/native_window.y)+GAP

static func can_reserve(safe:Rect2,logical_reserve:float)->bool:
 if safe.size.x<=0.0 or logical_reserve<=GAP or logical_reserve>=safe.size.y:
  return false
 var remaining:float=safe.size.y-logical_reserve
 # On very compact phones, omit the banner rather than squeeze the playing
 # grid or move a gameplay button inside the native advertisement.
 var header:float=clampf(remaining*.22,132.0,194.0)
 var tray_height:float=clampf(remaining*.10,58.0,112.0)
 var puzzle_size:float=minf(safe.size.x-32.0,remaining-header-tray_height-132.0)
 return remaining>=520.0 and puzzle_size>=safe.size.x*.70

static func dock_rect(safe:Rect2,logical_reserve:float)->Rect2:
 if logical_reserve<=0.0:
  return Rect2(safe.end,Vector2.ZERO)
 return Rect2(Vector2(safe.position.x,safe.end.y-logical_reserve),
  Vector2(safe.size.x,logical_reserve))
