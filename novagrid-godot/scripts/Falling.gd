extends RefCounted
## Original falling-block rules with seven-bag randomizer, collision, kicks,
## locked grid, hard/soft drop, ghost projection, long-form scoring.
const COLS := 10
const ROWS := 18
const FORMS = [
 [[0,1],[1,1],[2,1],[3,1]], # I
 [[0,0],[1,0],[0,1],[1,1]], # O
 [[1,0],[0,1],[1,1],[2,1]], # T
 [[0,0],[0,1],[1,1],[2,1]], # J
 [[2,0],[0,1],[1,1],[2,1]], # L
 [[1,0],[2,0],[0,1],[1,1]], # S
 [[0,0],[1,0],[1,1],[2,1]]  # Z
]
var rng := RandomNumberGenerator.new()
var board: Array = []
var bag: Array = []
var piece: Array = []
var active := Vector2i.ZERO
var kind := 0
var next_kind := 0
var score := 0
var best := 0
var lines := 0
var level := 1
var combo := 0
var drops := 0
var over := false
var last_lines := 0
var last_gained := 0

func _init() -> void:
 rng.randomize()
 reset()

func _row() -> Array:
 var result: Array = []
 result.resize(COLS)
 result.fill(0)
 return result

func _shape(kind_id: int) -> Array:
 var result: Array = []
 for raw in FORMS[kind_id]:
  result.append(Vector2i(int(raw[0]), int(raw[1])))
 return result

func reset() -> void:
 board.clear()
 for _y in ROWS:
  board.append(_row())
 bag.clear()
 score = 0
 lines = 0
 level = 1
 combo = 0
 drops = 0
 over = false
 last_lines = 0
 last_gained = 0
 next_kind = _take()
 _spawn()

func _take() -> int:
 if bag.is_empty():
  bag = [0,1,2,3,4,5,6]
  # Fisher-Yates using this instance's seeded RNG.
  for i in range(bag.size()-1,0,-1):
   var j := rng.randi_range(0,i)
   var temp: int = bag[i]
   bag[i] = bag[j]
   bag[j] = temp
 return int(bag.pop_back())

func _spawn() -> void:
 kind = next_kind
 next_kind = _take()
 piece = _shape(kind)
 active = Vector2i(3,0)
 if not fits(piece,active):
  over = true

func fits(shape: Array, at: Vector2i) -> bool:
 for p in shape:
  var c: Vector2i = p + at
  if c.x < 0 or c.x >= COLS or c.y >= ROWS:
   return false
  if c.y >= 0 and board[c.y][c.x] != 0:
   return false
 return true

func move(dx: int) -> bool:
 if over or not fits(piece,active+Vector2i(dx,0)):
  return false
 active.x += dx
 return true

func rotate() -> bool:
 if over or kind == 1:
  return false
 var rotated: Array = []
 var min_x := 999
 var min_y := 999
 for p in piece:
  var v := Vector2i(-p.y,p.x)
  rotated.append(v)
  min_x = mini(min_x,v.x)
  min_y = mini(min_y,v.y)
 for i in rotated.size():
  rotated[i] = rotated[i] - Vector2i(min_x,min_y)
 for kick in [0,-1,1,-2,2]:
  var trial := active + Vector2i(kick,0)
  if fits(rotated,trial):
   piece = rotated
   active = trial
   return true
 return false

func ghost_row() -> int:
 var y := active.y
 while fits(piece,Vector2i(active.x,y+1)):
  y += 1
 return y

func tick() -> bool:
 if over:
  return false
 if fits(piece,active+Vector2i(0,1)):
  active.y += 1
  return false
 _lock()
 return true

func soft_drop() -> bool:
 if over:
  return false
 var locked := tick()
 if not locked:
  score += 1
  best = maxi(score,best)
 return locked

func hard_drop() -> int:
 if over:
  return 0
 var distance := ghost_row()-active.y
 active.y += distance
 score += distance*2
 best = maxi(best,score)
 _lock()
 return distance

func _lock() -> void:
 last_lines = 0
 for p in piece:
  var c: Vector2i = active+p
  if c.y < 0:
   over = true
   return
  board[c.y][c.x] = kind+1
 var y := ROWS-1
 while y >= 0:
  var full := true
  for x in COLS:
   if board[y][x] == 0:
    full = false
    break
  if full:
   board.remove_at(y)
   board.insert(0,_row())
   last_lines += 1
  else:
   y -= 1
 combo = combo+1 if last_lines>0 else 0
 var bonus: int = [0,100,300,500,800][mini(last_lines,4)] * level
 if last_lines>0 and combo>1:
  bonus += 50*(combo-1)
 last_gained = bonus
 score += bonus
 best = maxi(best,score)
 lines += last_lines
 level = 1 + int(lines/10)
 drops += 1
 _spawn()

func fall_interval() -> float:
 return maxf(0.14,0.86*pow(0.87,float(level-1)))

func cell_at(col: int,row: int) -> int:
 if col<0 or col>=COLS or row<0 or row>=ROWS:
  return 0
 return int(board[row][col])

func snapshot() -> Dictionary:
 return {"version":1,"board":board.duplicate(true),"bag":bag.duplicate(),
  "kind":kind,"next_kind":next_kind,
  "piece":piece.map(func(p):return [p.x,p.y]),"active":[active.x,active.y],
  "score":score,"best":best,"lines":lines,"level":level,"combo":combo,
  "drops":drops,"over":over}

func restore(raw: Dictionary) -> bool:
 var source: Variant = raw.get("board",[])
 if not source is Array or source.size()!=ROWS:
  return false
 for row in source:
  if not row is Array or row.size()!=COLS:
   return false
  for cell in row:
   if int(cell)<0 or int(cell)>7:
    return false
 var positions: Variant = raw.get("piece",[])
 var next_position: Variant = raw.get("active",[])
 if not positions is Array or positions.size()!=4:
  return false
 if not next_position is Array or next_position.size()!=2:
  return false
 var decoded: Array = []
 for p in positions:
  if not p is Array or p.size()!=2:
   return false
  decoded.append(Vector2i(int(p[0]),int(p[1])))
 var candidate_kind := int(raw.get("kind",0))
 var candidate_next := int(raw.get("next_kind",0))
 if candidate_kind<0 or candidate_kind>6 or candidate_next<0 or candidate_next>6:
  return false
 board=source.duplicate(true)
 bag=raw.get("bag",[]).duplicate()
 piece=decoded
 kind=candidate_kind
 next_kind=candidate_next
 active=Vector2i(int(next_position[0]),int(next_position[1]))
 score=maxi(0,int(raw.get("score",0)))
 best=maxi(score,int(raw.get("best",score)))
 lines=maxi(0,int(raw.get("lines",0)))
 level=maxi(1,int(raw.get("level",1)))
 combo=maxi(0,int(raw.get("combo",0)))
 drops=maxi(0,int(raw.get("drops",0)))
 over=bool(raw.get("over",false))
 return true
