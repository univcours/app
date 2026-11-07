extends RefCounted
## Deterministic rules for an original 10x12 endless Block Puzzle.
## No HTML/Capacitor dependencies. Can be tested without a renderer.
const COLS := 10
const ROWS := 12
const BOMB_MILESTONES = [
 {"score":5000,"lines":18},{"score":14500,"lines":45},
 {"score":32000,"lines":95},{"score":56000,"lines":155},
 {"score":90000,"lines":240}
]
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

func _snapshot() -> Dictionary:
 return {"cells": cells.duplicate(true), "tray": tray.duplicate(true),
  "score": score, "best": best, "combo": combo, "moves": moves,
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
 var color_id: int = 1 + (moves + slot * 2) % 6
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
 for p in marked:
  cells[p.y][p.x] = 0
 last_cleared = marked.size()
 last_groups = clear_rows.size() + clear_columns.size()
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
 # Both a genuine high score and a sustained clear count are required.
 # Milestones never pay twice, even across sessions or undo restores.
 while last_groups>0 and bomb_milestone<BOMB_MILESTONES.size() and bombs<MAX_BOMBS:
  var target:Dictionary=BOMB_MILESTONES[bomb_milestone]
  if score<int(target["score"]) or total_lines<int(target["lines"]):
   break
  bombs+=1
  last_bomb_award+=1
  bomb_milestone+=1
 tray[slot] = []
 var need_more := true
 for piece in tray:
  if not piece.is_empty():
   need_more = false
   break
 if need_more:
  _new_tray()
 over = not any_move()
 return true

func bomb_charge() -> int:
 if bomb_milestone>=BOMB_MILESTONES.size():
  return 100
 var target:Dictionary=BOMB_MILESTONES[bomb_milestone]
 var score_ratio:float=float(score)/float(target["score"])
 var line_ratio:float=float(total_lines)/float(target["lines"])
 return clampi(int(round(100.0*minf(score_ratio,line_ratio))),0,100)

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
 over=not any_move()
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
  "fever": fever, "fever_moves": fever_moves, "over": over,
  "total_lines": total_lines, "bombs": bombs, "bomb_milestone": bomb_milestone}

func load_state(raw: Dictionary) -> bool:
 var board_value: Variant = raw.get("cells", [])
 if not board_value is Array or board_value.size() != ROWS:
  return false
 for row in board_value:
  if not row is Array or row.size() != COLS:
   return false
  for value in row:
   if int(value) < 0 or int(value) > 6:
    return false
 var tray_value: Variant = raw.get("tray", [])
 if not tray_value is Array or tray_value.size() != 3:
  return false
 var decoded: Array = []
 for shape in tray_value:
  if not shape is Array:
   return false
  var points: Array = []
  for p in shape:
   if p is Vector2i:
    points.append(p)
   elif p is Array and p.size() == 2:
    points.append(Vector2i(int(p[0]), int(p[1])))
   else:
    return false
  decoded.append(points)
 cells = board_value.duplicate(true)
 tray = decoded
 score = maxi(0, int(raw.get("score", 0)))
 best = maxi(score, int(raw.get("best", score)))
 combo = maxi(0, int(raw.get("combo", 0)))
 moves = maxi(0, int(raw.get("moves", 0)))
 fever = clampi(int(raw.get("fever", 0)), 0, 100)
 fever_moves = clampi(int(raw.get("fever_moves", 0)), 0, 5)
 total_lines=maxi(0,int(raw.get("total_lines",0)))
 bombs=clampi(int(raw.get("bombs",0)),0,MAX_BOMBS)
 bomb_milestone=clampi(int(raw.get("bomb_milestone",0)),0,BOMB_MILESTONES.size())
 last_cleared=0
 last_gained=0
 last_groups=0
 last_bomb_award=0
 over = bool(raw.get("over", false))
 return true
