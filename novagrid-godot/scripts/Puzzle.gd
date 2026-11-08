extends RefCounted
## Native 9x9 Classic Puzzle, based on the approved reference composition.
## No HTML/Capacitor dependencies. Can be tested without a renderer.
const COLS := 9
const ROWS := 9
const SECTOR_SIZE := 3
# Genuine line clears, not score thresholds, charge emergency area blasts.
const BOMB_EVERY_LINES := 4
const MAX_BOMBS := 2
const SHAPES = [
 [[0,0]], [[0,0],[1,0]], [[0,0],[1,0],[2,0]],
 [[0,0],[1,0],[2,0],[3,0]], [[0,0],[1,0],[2,0],[3,0],[4,0]],
 [[0,0],[0,1]], [[0,0],[0,1],[0,2]], [[0,0],[0,1],[0,2],[0,3]],
 [[0,0],[1,0],[0,1],[1,1]], [[0,0],[1,0],[2,0],[0,1],[1,1],[2,1]],
 [[0,0],[0,1],[0,2],[1,2]], [[1,0],[1,1],[0,2],[1,2]],
 [[0,0],[1,0],[1,1]], [[0,0],[0,1],[1,1]], [[1,0],[0,1],[1,1]],
 [[0,0],[1,0],[0,1]], [[0,0],[1,0],[2,0],[1,1]],
 [[0,0],[1,0],[2,0],[1,1],[1,2]], [[0,0],[1,0],[2,0],[3,0],[1,1]],
 [[0,0],[0,1],[0,2],[1,2],[2,2]], [[0,0],[1,0],[1,1],[2,1]],
 [[1,0],[2,0],[0,1],[1,1]]
]
var rng := RandomNumberGenerator.new()
var cells: Array = []
var tray: Array = []
var tray_colors: Array = [7,1,5]
var score := 0
var best := 0
var combo := 0
var moves := 0
var over := false
var last_cleared := 0
var last_gained := 0
var last_groups := 0
var total_lines := 0
var bombs := 0
var bomb_milestone := 0
var last_bomb_award := 0
var fever := 0
var fever_moves := 0
var previous: Dictionary = {}

func _init() -> void:
 rng.randomize()
 reset()

func reset() -> void:
 cells.clear()
 for _y in ROWS:
  cells.append(_empty_row())
 score = 0
 combo = 0
 moves = 0
 last_cleared = 0
 last_gained = 0
 last_groups = 0
 total_lines = 0
 bombs = 0
 bomb_milestone = 0
 last_bomb_award = 0
 over = false
 fever = 0
 fever_moves = 0
 previous.clear()
 _new_tray()

func _empty_row() -> Array:
 var row: Array = []
 row.resize(COLS)
 row.fill(0)
 return row

func _copy_shape(raw: Array) -> Array:
 var shape: Array = []
 for cell in raw:
  shape.append(Vector2i(int(cell[0]), int(cell[1])))
 return shape

func shape_size(shape: Array) -> Vector2i:
 var bound := Vector2i(1, 1)
 for p in shape:
  bound.x = maxi(bound.x, p.x + 1)
  bound.y = maxi(bound.y, p.y + 1)
 return bound

func fits(shape: Array, origin: Vector2i) -> bool:
 if shape.is_empty():
  return false
 for p in shape:
  var c: Vector2i = origin + p
  if c.x < 0 or c.x >= COLS or c.y < 0 or c.y >= ROWS:
   return false
  if cells[c.y][c.x] != 0:
   return false
 return true

func shape_fits_anywhere(shape: Array) -> bool:
 if shape.is_empty():
  return false
 for y in ROWS:
  for x in COLS:
   if fits(shape, Vector2i(x, y)):
    return true
 return false

func _choose_shape() -> Array:
 # First pieces are approachable, challenge gently increases with mastery.
 var limit := 12 if moves < 12 else (18 if moves < 35 else SHAPES.size())
 return _copy_shape(SHAPES[rng.randi_range(0, limit - 1)])

func _new_tray() -> void:
 tray.clear()
 var palette:Array=[7,1,5,2,6,4,3]
 var phase:int=int(moves/3)%palette.size()
 tray_colors=[7,1,5] if moves==0 else [palette[phase],palette[(phase+2)%palette.size()],palette[(phase+4)%palette.size()]]
 for _i in 3:
  tray.append(_choose_shape())
 # As long as the board has a possible fit, grant at least two
 # legal choices early on. No secretly changed game board.
 var playable: Array = []
 for raw in SHAPES:
  var shape := _copy_shape(raw)
  if shape_fits_anywhere(shape):
   playable.append(shape)
 if not playable.is_empty():
  var target := 2 if moves < 36 else 1
  var choices := 0
  for shape in tray:
   if shape_fits_anywhere(shape):
    choices += 1
  for i in 3:
   if choices >= target:
    break
   if not shape_fits_anywhere(tray[i]):
    tray[i] = playable[rng.randi_range(0, playable.size() - 1)].duplicate()
    choices += 1

func any_move() -> bool:
 for shape in tray:
  if not shape.is_empty() and shape_fits_anywhere(shape):
   return true
 return false

func can_rescue() -> bool:
 if bombs<=0:return false
 for row in cells:
  for value in row:
   if int(value)>0:return true
 return false

func needs_rescue() -> bool:
 return not any_move() and can_rescue() and not over

func _check_game_over() -> void:
 over=not any_move() and not can_rescue()

func _award_bombs() -> void:
 # Advance milestone even when inventory is full; no double awards after
 # spending a saved charge.
 while total_lines >= (bomb_milestone+1)*BOMB_EVERY_LINES:
  bomb_milestone+=1
  if bombs<MAX_BOMBS:
   bombs+=1
   last_bomb_award+=1

func _snapshot() -> Dictionary:
 return {"cells": cells.duplicate(true), "tray": tray.duplicate(true),
  "score": score, "best": best, "combo": combo, "moves": moves,
  "tray_colors": tray_colors.duplicate(),
  "fever": fever, "fever_moves": fever_moves, "over": over,
  "total_lines": total_lines, "bombs": bombs,
  "bomb_milestone": bomb_milestone}

func undo() -> bool:
 if previous.is_empty():
  return false
 load_state(previous)
 previous.clear()
 return true

func place(slot: int, origin: Vector2i) -> bool:
 if over or slot < 0 or slot >= tray.size():
  return false
 var shape: Array = tray[slot]
 if not fits(shape, origin):
  return false
 previous = _snapshot()
 # Every placed crystal retains the exact hue shown in its tray preview.
 var color_id:int=int(tray_colors[slot])
 for p in shape:
  var at: Vector2i = origin + p
  cells[at.y][at.x] = color_id
 var clear_rows: Array = []
 var clear_columns: Array = []
 for y in ROWS:
  var full := true
  for x in COLS:
   if cells[y][x] == 0:
    full = false
    break
  if full:
   clear_rows.append(y)
 for x in COLS:
  var full := true
  for y in ROWS:
   if cells[y][x] == 0:
    full = false
    break
  if full:
   clear_columns.append(x)
 var marked: Dictionary = {}
 for y in clear_rows:
  for x in COLS:
   marked[Vector2i(x, y)] = true
 for x in clear_columns:
  for y in ROWS:
   marked[Vector2i(x, y)] = true
 var clear_sectors: Array = []
 for by in 3:
  for bx in 3:
   var sector_full := true
   for dy in 3:
    for dx in 3:
     if cells[by*3+dy][bx*3+dx] == 0:
      sector_full = false
   if sector_full:
    clear_sectors.append(Vector2i(bx,by))
    for dy in 3:
     for dx in 3:
      marked[Vector2i(bx*3+dx,by*3+dy)] = true
 for p in marked:
  cells[p.y][p.x] = 0
 last_cleared = marked.size()
 last_groups = clear_rows.size() + clear_columns.size() + clear_sectors.size()
 last_bomb_award = 0
 # A placement is NOT a scoring event. Completing multiple lines at once
 # earns a larger per-group multiplier and raises the displayed combo.
 combo = maxi(last_groups,mini(8,combo+1)) if last_groups>0 else 0
 moves += 1
 var points: int = 0
 if last_groups>0:
  points = int(round(120.0*last_groups*(1.0+.65*float(last_groups-1))+
   18.0*maxi(0,combo-1)*last_groups))
  total_lines += last_groups
 if fever_moves>0:
  # Fever never produces points from a non-clearing placement.
  if last_groups>0:
   points *= 2
  fever_moves -= 1
  if fever_moves==0:
   fever=0
 elif last_groups>0:
  fever=mini(100,fever+last_groups*27+mini(combo,5)*9)
  if fever>=100:
   fever_moves=5
 elif fever>0:
  fever=maxi(0,fever-5)
 last_gained=points
 score+=points
 best=maxi(best,score)
 # Every four actually completed groups earns one emergency 3x3 blast.
 if last_groups>0:
  _award_bombs()
 tray[slot] = []
 var need_more := true
 for piece in tray:
  if not piece.is_empty():
   need_more = false
   break
 if need_more:
  _new_tray()
 _check_game_over()
 return true

func bomb_charge() -> int:
 if bombs>=MAX_BOMBS:return 100
 return clampi(int(round(100.0*float(total_lines%BOMB_EVERY_LINES)/float(BOMB_EVERY_LINES))),0,100)

func detonate_bomb(center:Vector2i) -> int:
 if bombs<=0 or over or center.x<0 or center.x>=COLS or center.y<0 or center.y>=ROWS:
  return 0
 var removed:int=0
 for y in range(maxi(0,center.y-1),mini(ROWS,center.y+2)):
  for x in range(maxi(0,center.x-1),mini(COLS,center.x+2)):
   if int(cells[y][x])>0:
    removed+=1
 if removed==0:
  return 0 # Never waste a rare bomb on empty space.
 for y in range(maxi(0,center.y-1),mini(ROWS,center.y+2)):
  for x in range(maxi(0,center.x-1),mini(COLS,center.x+2)):
   cells[y][x]=0
 bombs-=1
 combo=0
 last_cleared=removed
 last_groups=0
 last_gained=0
 last_bomb_award=0
 # Rescue action: no points, XP, lines, or free recharge.
 previous.clear()
 _check_game_over()
 return removed

func save_state() -> Dictionary:
 var raw_tray: Array = []
 for shape in tray:
  var item: Array = []
  for p in shape:
   item.append([p.x, p.y])
  raw_tray.append(item)
 return {"version": 1, "cells": cells.duplicate(true), "tray": raw_tray,
  "score": score, "best": best, "combo": combo, "moves": moves,
  "tray_colors": tray_colors.duplicate(),
  "fever": fever, "fever_moves": fever_moves, "over": over,
  "total_lines": total_lines, "bombs": bombs, "bomb_milestone": bomb_milestone}

func _saved_integer(value:Variant,minimum:int,maximum:int) -> bool:
 if not (value is int or value is float):
  return false
 var number:float=float(value)
 return is_finite(number) and number==floor(number) and number>=minimum and number<=maximum

func load_state(raw: Dictionary) -> bool:
 # Undo snapshots predate the version field; version 1 JSON stays compatible.
 if not _saved_integer(raw.get("version",1),1,1):
  return false
 var board_value:Variant=raw.get("cells",[])
 if not board_value is Array:
  return false
 var legacy:bool=board_value.size()==12
 if not legacy and board_value.size()!=ROWS:
  return false
 for row in board_value:
  if not row is Array or row.size()!=(10 if legacy else COLS):
   return false
  for value in row:
   if not _saved_integer(value,0,7):
    return false
 var tray_value:Variant=raw.get("tray",[])
 if not tray_value is Array or tray_value.size()!=3:
  return false
 var decoded:Array=[]
 for shape in tray_value:
  if not shape is Array or shape.size()>6:
   return false
  var points:Array=[]
  for point in shape:
   var cell:Vector2i
   if point is Vector2i:
    cell=point
   elif point is Array and point.size()==2:
    if not _saved_integer(point[0],0,COLS-1) or not _saved_integer(point[1],0,ROWS-1):
     return false
    cell=Vector2i(int(point[0]),int(point[1]))
   else:
    return false
   if cell.x<0 or cell.x>=COLS or cell.y<0 or cell.y>=ROWS or points.has(cell):
    return false
   points.append(cell)
  # Empty slots represent already placed pieces. Nonempty slots must be one
  # of the game's real shapes, or a corrupt save can create invisible cells.
  if not points.is_empty():
   var matches:bool=false
   for form in SHAPES:
    var expected:Array=_copy_shape(form)
    if expected.size()==points.size():
     var same:bool=true
     for cell in points:
      if not expected.has(cell):same=false
     if same:matches=true
   if not matches:return false
  decoded.append(points)
 var stored_colors:Variant=raw.get("tray_colors",[7,1,5])
 if not stored_colors is Array or stored_colors.size()!=3:
  return false
 for color in stored_colors:
  if not _saved_integer(color,1,7):return false
 for key in ["score","best","combo","moves","total_lines"]:
  if not _saved_integer(raw.get(key,0),0,2147483647):return false
 var maxima:Dictionary={"fever":100,"fever_moves":5,"bombs":MAX_BOMBS,"bomb_milestone":2147483647}
 for key in maxima:
  if not _saved_integer(raw.get(key,0),0,int(maxima[key])):return false
 if not raw.get("over",false) is bool:return false
 # Mutations only start after all validation passes. Legacy 10x12 boards
 # restart safely while retaining score, tray and earned milestone fields.
 cells=board_value.duplicate(true)
 if legacy:
  cells=[]
  for _y in ROWS:cells.append(_empty_row())
 tray=decoded
 tray_colors=stored_colors.map(func(value):return int(value))
 score=int(raw.get("score",0))
 best=maxi(score,int(raw.get("best",score)))
 combo=int(raw.get("combo",0))
 moves=int(raw.get("moves",0))
 fever=int(raw.get("fever",0))
 fever_moves=int(raw.get("fever_moves",0))
 total_lines=int(raw.get("total_lines",0))
 bombs=int(raw.get("bombs",0))
 bomb_milestone=int(raw.get("bomb_milestone",0))
 last_cleared=0
 last_gained=0
 last_groups=0
 last_bomb_award=0
 # Migrate unfair loss from older builds if a rescue is still earned.
 _check_game_over()
 previous.clear()
 return true
