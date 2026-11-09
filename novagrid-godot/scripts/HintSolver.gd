extends RefCounted
## Pure, deterministic 9x9 Classic adviser. Never changes the real Puzzle model.
## Only computes legal placements; the player must confirm the actual move.
const COLS := 9
const ROWS := 9

static func _fits(board:Array,shape:Array,origin:Vector2i) -> bool:
 if shape.is_empty():
  return false
 for delta in shape:
  var at:Vector2i=origin+delta
  if at.x<0 or at.x>=COLS or at.y<0 or at.y>=ROWS:
   return false
  if int(board[at.y][at.x])!=0:
   return false
 return true

static func _clear_full_groups(board:Array) -> Dictionary:
 var marked:Dictionary={}
 var groups:int=0
 for y in ROWS:
  var complete:bool=true
  for x in COLS:
   if int(board[y][x])==0:
    complete=false
    break
  if complete:
   groups+=1
   for x in COLS:
    marked[Vector2i(x,y)]=true
 for x in COLS:
  var complete:bool=true
  for y in ROWS:
   if int(board[y][x])==0:
    complete=false
    break
  if complete:
   groups+=1
   for y in ROWS:
    marked[Vector2i(x,y)]=true
 for by in 3:
  for bx in 3:
   var complete:bool=true
   for dy in 3:
    for dx in 3:
     if int(board[by*3+dy][bx*3+dx])==0:
      complete=false
   if complete:
    groups+=1
    for dy in 3:
     for dx in 3:
      marked[Vector2i(bx*3+dx,by*3+dy)]=true
 for position in marked:
  board[position.y][position.x]=0
 return {"groups":groups,"cleared":marked.size()}

static func _follow_up_options(board:Array,tray:Array,placed_slot:int) -> int:
 var choices:int=0
 for slot in range(tray.size()):
  if slot==placed_slot:
   continue
  var shape:Array=tray[slot]
  if shape.is_empty():
   continue
  for y in ROWS:
   for x in COLS:
    if _fits(board,shape,Vector2i(x,y)):
     choices+=1
 return choices

static func _near_clear_potential(board:Array) -> int:
 # Favour building actual groups when no immediate clear exists.
 var potential:int=0
 for y in ROWS:
  var filled:int=0
  for x in COLS:
   if int(board[y][x])>0:
    filled+=1
  if filled>0 and filled<COLS:
   potential+=filled*filled
 for x in COLS:
  var filled:int=0
  for y in ROWS:
   if int(board[y][x])>0:
    filled+=1
  if filled>0 and filled<ROWS:
   potential+=filled*filled
 for by in 3:
  for bx in 3:
   var filled:int=0
   for dy in 3:
    for dx in 3:
     if int(board[by*3+dy][bx*3+dx])>0:
      filled+=1
   if filled>0 and filled<9:
    potential+=filled*filled
 return potential

static func best_move(puzzle,preferred_slot:int=-1) -> Dictionary:
 # Use real Puzzle.fits, simulate every available tray position, and prefer
 # genuine group clears before remaining mobility and future setup.
 if puzzle.over:
  return {}
 var best:Dictionary={}
 var highest:int=-2147483648
 for slot in range(puzzle.tray.size()):
  var shape:Array=puzzle.tray[slot]
  if shape.is_empty():
   continue
  for y in ROWS:
   for x in COLS:
    var origin:=Vector2i(x,y)
    if not puzzle.fits(shape,origin):
     continue
    var trial:Array=puzzle.cells.duplicate(true)
    for delta in shape:
     var at:Vector2i=origin+delta
     trial[at.y][at.x]=1
    var cleared:Dictionary=_clear_full_groups(trial)
    var options:int=_follow_up_options(trial,puzzle.tray,slot)
    var potential:int=_near_clear_potential(trial)
    # A completed group always outranks non-clearing moves.
    var rating:int=int(cleared["groups"])*100000+int(cleared["cleared"])*2000+options*10+potential
    var preferred:bool=slot==preferred_slot and int(best.get("slot",-1))!=preferred_slot
    if rating>highest or (rating==highest and preferred):
     highest=rating
     best={"slot":slot,"origin":origin,"groups":int(cleared["groups"]),
      "cleared":int(cleared["cleared"]),"future_options":options}
 return best
