extends RefCounted
## Original falling-block rules with seven-bag randomizer, collision, kicks,
## locked grid, hard/soft drop, ghost projection, long-form scoring.
const WallKicks = preload("res://scripts/WallKicks.gd")
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
var hold_kind := -1
var hold_used := false
var rotation_state := 0
var lock_delay_elapsed := 0.0
const LOCK_DELAY_SECONDS := 0.42
const MAX_LOCK_RESETS := 15
var lock_resets := 0
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
 hold_kind = -1
 hold_used = false
 rotation_state = 0
 lock_delay_elapsed = 0.0
 lock_resets = 0
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
 rotation_state = 0
 lock_delay_elapsed = 0.0
 lock_resets = 0
 if not fits(piece,active):
  over = true

func hold_piece() -> bool:
 if over or hold_used:
  return false
 var outgoing:int=kind
 if hold_kind<0:
  hold_kind=outgoing
  _spawn()
 else:
  kind=hold_kind
  hold_kind=outgoing
  piece=_shape(kind)
  active=Vector2i(3,0)
  rotation_state=0
  lock_delay_elapsed=0.0
  lock_resets=0
  if not fits(piece,active):
   over=true
 hold_used=true
 return true

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
 var grounded:bool=not fits(piece,active+Vector2i(0,1))
 active.x += dx
 _reset_lock_after_input(grounded)
 return true

func rotate(direction:int=1) -> bool:
 if over or kind==1:
  return false
 var grounded:bool=not fits(piece,active+Vector2i(0,1))
 # Use permissive rotational tests adapted from the MIT-licensed
 # PokeTetris SRS kick data, preserving our existing 2D piece rendering.
 var rotated:Array=[]
 var minimum:=Vector2i(999,999)
 for tile in piece:
  var q:Vector2i=Vector2i(-tile.y,tile.x) if direction>=0 else Vector2i(tile.y,-tile.x)
  rotated.append(q)
  minimum.x=mini(minimum.x,q.x)
  minimum.y=mini(minimum.y,q.y)
 for i in rotated.size():
  rotated[i]=rotated[i]-minimum
 for offset in WallKicks.offsets(kind,rotation_state,direction):
  var trial:Vector2i=active+offset
  if fits(rotated,trial):
   piece=rotated
   active=trial
   rotation_state=posmod(rotation_state+direction,4)
   _reset_lock_after_input(grounded)
   return true
 return false

func _reset_lock_after_input(grounded:bool) -> void:
 # Keep a generous slide/rotate grace period without allowing an endless
 # grounded piece by alternating left/right on a touchscreen.
 if not grounded:
  return
 if lock_resets<MAX_LOCK_RESETS:
  lock_delay_elapsed=0.0
  lock_resets+=1

func advance_lock(delta:float) -> bool:
 # Standard mobile-friendly lock delay: movement and rotations reset it.
 # Sliding a piece onto the floor is responsive instead of locking instantly.
 if over:
  return false
 if fits(piece,active+Vector2i(0,1)):
  lock_delay_elapsed=0.0
  return false
 lock_delay_elapsed+=maxf(0.0,delta)
 if lock_delay_elapsed>=LOCK_DELAY_SECONDS:
  _lock()
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
  lock_delay_elapsed=0.0
  return false
 # The grounded lock delay is advanced separately each frame.
 return false

func soft_drop() -> bool:
 if over:
  return false
 # Soft dropping changes position but does not grant points.
 return tick()

func hard_drop() -> int:
 if over:
  return 0
 var distance := ghost_row()-active.y
 active.y += distance
 # A hard drop alone is also worth zero: only cleared rows pay.
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
 # Multiple simultaneous rows are rewarded more than separate singles.
 combo = maxi(last_lines,mini(8,combo+1)) if last_lines>0 else 0
 var bonus: int = [0,140,440,850,1500][mini(last_lines,4)] * level
 if last_lines>0 and combo>1:
  bonus += 45*(combo-1)*last_lines
 last_gained = bonus
 score += bonus
 best = maxi(best,score)
 lines += last_lines
 level = 1 + int(lines/10)
 drops += 1
 hold_used=false
 _spawn()

func fall_interval() -> float:
 return maxf(0.14,0.86*pow(0.87,float(level-1)))

func cell_at(col: int,row: int) -> int:
 if col<0 or col>=COLS or row<0 or row>=ROWS:
  return 0
 return int(board[row][col])

func snapshot() -> Dictionary:
 return {"version":1,"board":board.duplicate(true),"bag":bag.duplicate(),
  "kind":kind,"next_kind":next_kind,"hold_kind":hold_kind,"hold_used":hold_used,
  "rotation_state":rotation_state,"lock_delay_elapsed":lock_delay_elapsed,"lock_resets":lock_resets,
  "piece":piece.map(func(p):return [p.x,p.y]),"active":[active.x,active.y],
  "score":score,"best":best,"lines":lines,"level":level,"combo":combo,
  "drops":drops,"over":over}

func _saved_integer(value:Variant,minimum:int,maximum:int) -> bool:
 if not (value is int or value is float):
  return false
 var number:float=float(value)
 return is_finite(number) and number==floor(number) and number>=minimum and number<=maximum

func _valid_shape(decoded:Array,kind_id:int) -> bool:
 # A restored tetromino must be the saved kind in a legal orientation.
 # Normalize both sets because the original I spawn has a one-row offset.
 var expected:Array=_shape(kind_id)
 for orientation in 4:
  var minimum:=Vector2i(999,999)
  for point in expected:
   minimum.x=mini(minimum.x,point.x)
   minimum.y=mini(minimum.y,point.y)
  var candidate_min:=Vector2i(999,999)
  for point in decoded:
   candidate_min.x=mini(candidate_min.x,point.x)
   candidate_min.y=mini(candidate_min.y,point.y)
  var matches:bool=true
  for point in decoded:
   if not expected.has(point-candidate_min+minimum):
    matches=false
  if matches:
   return true
  for index in expected.size():
   var point:Vector2i=expected[index]
   expected[index]=Vector2i(-point.y,point.x)
 return false

func restore(raw: Dictionary) -> bool:
 # Validate the complete candidate before changing any live state. JSON may
 # contain nulls, dictionaries or fractional numbers where integers belong.
 if not _saved_integer(raw.get("version",1),1,1):
  return false
 var source:Variant=raw.get("board",[])
 if not source is Array or source.size()!=ROWS:
  return false
 for row in source:
  if not row is Array or row.size()!=COLS:
   return false
  for cell in row:
   if not _saved_integer(cell,0,7):
    return false
 for key in ["kind","next_kind"]:
  if not _saved_integer(raw.get(key,0),0,6):
   return false
 if not _saved_integer(raw.get("hold_kind",-1),-1,6):
  return false
 var saved_bag:Variant=raw.get("bag",[])
 if not saved_bag is Array or saved_bag.size()>7:
  return false
 var unique_bag:Dictionary={}
 for item in saved_bag:
  if not _saved_integer(item,0,6) or unique_bag.has(int(item)):
   return false
  unique_bag[int(item)]=true
 var positions:Variant=raw.get("piece",[])
 var next_position:Variant=raw.get("active",[])
 if not positions is Array or positions.size()!=4:
  return false
 if not next_position is Array or next_position.size()!=2:
  return false
 if not _saved_integer(next_position[0],-4,COLS-1) or not _saved_integer(next_position[1],-4,ROWS-1):
  return false
 var decoded:Array=[]
 for point in positions:
  if not point is Array or point.size()!=2:
   return false
  if not _saved_integer(point[0],0,3) or not _saved_integer(point[1],0,3):
   return false
  var cell:=Vector2i(int(point[0]),int(point[1]))
  if decoded.has(cell):
   return false
  decoded.append(cell)
 var candidate_kind:int=int(raw.get("kind",0))
 if not _valid_shape(decoded,candidate_kind):
  return false
 var candidate_active:=Vector2i(int(next_position[0]),int(next_position[1]))
 if not raw.get("over",false) is bool or not raw.get("hold_used",false) is bool:
  return false
 var candidate_over:bool=raw.get("over",false)
 for cell in decoded:
  var at:Vector2i=candidate_active+cell
  if at.x<0 or at.x>=COLS or at.y>=ROWS:
   return false
  if not candidate_over and at.y>=0 and int(source[at.y][at.x])!=0:
   return false
 for key in ["score","best","lines","combo","drops"]:
  if not _saved_integer(raw.get(key,0),0,2147483647):
   return false
 if not _saved_integer(raw.get("level",1),1,2147483647):
  return false
 if not _saved_integer(raw.get("rotation_state",0),0,3) or not _saved_integer(raw.get("lock_resets",0),0,MAX_LOCK_RESETS):
  return false
 var saved_lock:Variant=raw.get("lock_delay_elapsed",0.0)
 if not (saved_lock is int or saved_lock is float) or not is_finite(float(saved_lock)) or float(saved_lock)<0.0 or float(saved_lock)>LOCK_DELAY_SECONDS:
  return false
 board=source.duplicate(true)
 bag=saved_bag.map(func(value):return int(value))
 piece=decoded
 kind=candidate_kind
 next_kind=int(raw.get("next_kind",0))
 hold_kind=int(raw.get("hold_kind",-1))
 hold_used=raw.get("hold_used",false)
 rotation_state=int(raw.get("rotation_state",0))
 lock_delay_elapsed=float(saved_lock)
 lock_resets=int(raw.get("lock_resets",0))
 active=candidate_active
 score=int(raw.get("score",0))
 best=maxi(score,int(raw.get("best",score)))
 lines=int(raw.get("lines",0))
 level=int(raw.get("level",1))
 combo=int(raw.get("combo",0))
 drops=int(raw.get("drops",0))
 over=candidate_over
 last_lines=0
 last_gained=0
 return true
