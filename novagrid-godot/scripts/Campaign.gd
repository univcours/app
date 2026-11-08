extends RefCounted
## Native port of the three verified handcrafted missions in web/stages.js.
## Isolated version: retired 14,000-stage saves cannot imply native victories.
const TOTAL_STAGES := 3
const NAMES := ["Crystal Bloom", "Rocket Rush", "Nebula Guardian"]
const KINDS := ["candy", "rocket", "bomb"]
var unlocked := 1
var completed:Dictionary = {}

static func stage_config(level:int) -> Dictionary:
 if level < 1 or level > TOTAL_STAGES:
  return {}
 var i:int=level-1
 return {"level":level,"name":NAMES[i],"kind":KINDS[i],"score_target":[260,800,1400][i],
  "special_target":[2,3,3][i],"min_moves":[6,10,12][i],"boss":level==3,"mode":0}

static func initial_board(level:int) -> Array:
 var result:Array=[]
 for y in 9:
  var row:Array=[]
  row.resize(9)
  row.fill(0)
  result.append(row)
 if level==2:
  for x in 5: result[4][x]=3
 elif level==3:
  for x in 6: result[2][x]=4
  for y in range(5,8): result[y][7]=4
 return result

static func apply_turn(level:int,puzzle,run:Dictionary) -> Dictionary:
 var cfg:Dictionary=stage_config(level)
 var next:Dictionary=run.duplicate(true)
 next["max_combo"]=maxi(int(next.get("max_combo",0)),puzzle.combo)
 next["removed"]=0
 if cfg.is_empty() or puzzle.last_groups<=0:
  return next
 var kind:String=cfg["kind"]
 if kind=="candy":
  next["specials"]=int(next.get("specials",0))+puzzle.last_groups
  puzzle.score+=15*puzzle.last_groups
  puzzle.last_gained+=15*puzzle.last_groups
 else:
  var candidates:Array=[]
  if kind=="rocket":
   for y in 9:
    var row:Array=[]
    for x in 9: row.append(Vector2i(x,y))
    candidates.append(row)
   for x in 9:
    var column:Array=[]
    for y in 9: column.append(Vector2i(x,y))
    candidates.append(column)
  else:
   for y in range(1,8):
    for x in range(1,8):
     var patch:Array=[]
     for dy in range(-1,2):
      for dx in range(-1,2): patch.append(Vector2i(x+dx,y+dy))
     candidates.append(patch)
  var best:Array=[]
  var count:int=-1
  for option in candidates:
   var occupied:int=0
   for cell in option:
    if puzzle.cells[cell.y][cell.x]!=0: occupied+=1
   if occupied>count:
    count=occupied
    best=option
  for cell in best: puzzle.cells[cell.y][cell.x]=0
  next["removed"]=maxi(0,count)
  next["specials"]=int(next.get("specials",0))+1
  var bonus:int=(40 if kind=="rocket" else 60)+maxi(0,count)*12
  puzzle.score+=bonus
  puzzle.last_gained+=bonus
 puzzle.best=maxi(puzzle.best,puzzle.score)
 puzzle.over=not puzzle.any_move()
 return next

static func won(level:int,puzzle,run:Dictionary) -> bool:
 var cfg:Dictionary=stage_config(level)
 return not cfg.is_empty() and puzzle.moves>=int(cfg["min_moves"]) and puzzle.score>=int(cfg["score_target"]) and int(run.get("specials",0))>=int(cfg["special_target"])

static func rank_result(level:int,puzzle,run:Dictionary) -> int:
 if not won(level,puzzle,run): return 0
 var ratio:float=float(puzzle.score)/float(stage_config(level)["score_target"])
 var combo:int=int(run.get("max_combo",0))
 return 3 if ratio>=1.6 and combo>=3 else 2 if ratio>=1.25 or combo>=2 else 1

func record_result(level:int,puzzle,run:Dictionary) -> int:
 if level<1 or level>unlocked: return 0
 var stars:int=rank_result(level,puzzle,run)
 if stars<=0: return 0
 var key:String=str(level)
 completed[key]=maxi(stars,int(completed.get(key,0)))
 unlocked=mini(TOTAL_STAGES,maxi(unlocked,level+1))
 return stars

func snapshot() -> Dictionary:
 return {"version":1,"completed":completed.duplicate(true),"unlocked":unlocked}

func restore(raw:Dictionary) -> bool:
 if int(raw.get("version",0))!=1 or not raw.get("completed",{}) is Dictionary:
  return false
 var clean:Dictionary={}
 var data:Dictionary=raw.get("completed",{})
 for level in range(1,TOTAL_STAGES+1):
  var stars:Variant=data.get(str(level),data.get(level,0))
  if not (stars is int or stars is float): break
  if int(stars)<1 or int(stars)>3 or float(stars)!=float(int(stars)): break
  clean[str(level)]=int(stars)
 completed=clean
 unlocked=mini(TOTAL_STAGES,completed.size()+1)
 return true
