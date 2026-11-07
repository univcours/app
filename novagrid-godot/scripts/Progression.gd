extends RefCounted
## Persistent, offline-first, non-monetized metagame.
## Replayable sessions stay free; achievements and daily rewards pay only once.
const RANKS = ["ROOKIE","BRONZE","SILVER","GOLD","EMERALD","SAPPHIRE","DIAMOND","MASTER","NOVA LEGEND"]
const RANK_LEVELS = [1,3,7,12,20,31,45,62,82]
const MISSIONS = [
 {"id":"puzzle_plays","label":"PLACE 12 CRYSTALS","target":12,"xp":90,"stars":12},
 {"id":"line_clears","label":"CLEAR 6 LINES","target":6,"xp":120,"stars":18},
 {"id":"falling_drops","label":"DROP 10 BLOCKS","target":10,"xp":95,"stars":12}
]
var xp := 0
var level := 1
var stars := 0
var total_plays := 0
var total_clears := 0
var total_drops := 0
var highest_combo := 0
var achievements: Dictionary = {}
var day_key := ""
var last_login := ""
var streak := 0
var daily: Dictionary = {}
var daily_claimed: Dictionary = {}
var last_reward := ""
var last_level_gained := 0

func _init() -> void:
 sync_daily(_today())

func _today() -> String:
 # Stable UTC date used for persistent, deterministic daily progress.
 var t:Dictionary = Time.get_date_dict_from_system(true)
 return "%04d-%02d-%02d" % [int(t["year"]),int(t["month"]),int(t["day"])]

func xp_to_level_start(lv:int) -> int:
 var n:int = maxi(0,lv-1)
 return n*120+n*n*35

func level_progress() -> float:
 var current:int = xp_to_level_start(level)
 var next:int = xp_to_level_start(level+1)
 return clampf(float(xp-current)/float(maxi(1,next-current)),0.0,1.0)

func rank_name() -> String:
 var result:String = RANKS[0]
 for i in RANK_LEVELS.size():
  if level>=RANK_LEVELS[i]:
   result=RANKS[i]
 return result

func _grant_xp(amount:int) -> void:
 xp += maxi(0,amount)
 var before:int=level
 while level<200 and xp>=xp_to_level_start(level+1):
  level += 1
 last_level_gained=level-before
 if last_level_gained>0:
  last_reward="LEVEL UP • %d" % level

func sync_daily(today:String) -> void:
 if today.length()!=10:
  return
 if day_key==today:
  return
 # Never allow clock rollback to reset claims or collect a second login bonus.
 if day_key!="" and today<day_key:
  return
 day_key=today
 daily.clear()
 daily_claimed.clear()
 for mission in MISSIONS:
  daily[String(mission["id"])]=0
  daily_claimed[String(mission["id"])]=false
 if last_login=="" or today>last_login:
  if last_login!="" and _days_apart(last_login,today)==1:
   streak+=1
  else:
   streak=1
  last_login=today
  stars+=5+mini(streak,7)*2
  last_reward="DAILY STREAK %d" % streak

func _days_apart(earlier:String,later:String) -> int:
 var a:float=Time.get_unix_time_from_datetime_string(earlier+"T00:00:00")
 var b:float=Time.get_unix_time_from_datetime_string(later+"T00:00:00")
 return int(round((b-a)/86400.0))

func _advance_daily(kind:String,amount:int) -> void:
 sync_daily(_today())
 if not daily.has(kind):
  return
 var idx:int=-1
 for i in MISSIONS.size():
  if MISSIONS[i]["id"]==kind:
   idx=i
   break
 if idx<0 or bool(daily_claimed.get(kind,false)):
  return
 var mission:Dictionary=MISSIONS[idx]
 daily[kind]=mini(int(mission["target"]),int(daily.get(kind,0))+amount)
 if int(daily[kind])>=int(mission["target"]):
  daily_claimed[kind]=true
  stars+=int(mission["stars"])
  _grant_xp(int(mission["xp"]))
  last_reward="MISSION COMPLETE +%d STARS" % int(mission["stars"])

func _achievement(id:String,requirement:bool,bonus:int) -> void:
 if not requirement or bool(achievements.get(id,false)):
  return
 achievements[id]=true
 stars+=bonus
 last_reward="ACHIEVEMENT +%d STARS" % bonus

func placed_piece() -> void:
 total_plays+=1
 _grant_xp(6)
 _advance_daily("puzzle_plays",1)
 _achievement("first_crystal",total_plays>=1,10)
 _achievement("crystal_builder",total_plays>=25,25)
 _achievement("cosmic_builder",total_plays>=100,75)

func cleared_lines(count:int,combo:int=0) -> void:
 if count<=0:
  return
 total_clears+=count
 highest_combo=maxi(highest_combo,combo)
 _grant_xp(12*count+mini(8,combo)*5)
 _advance_daily("line_clears",count)
 _achievement("first_clear",total_clears>=1,10)
 _achievement("nebula_clearer",total_clears>=30,30)
 _achievement("galactic_master",total_clears>=150,100)
 _achievement("combo_5",highest_combo>=5,35)

func locked_falling_piece() -> void:
 total_drops+=1
 _grant_xp(5)
 _advance_daily("falling_drops",1)
 _achievement("first_drop",total_drops>=1,10)
 _achievement("falling_ace",total_drops>=50,50)

func next_mission() -> Dictionary:
 sync_daily(_today())
 for mission in MISSIONS:
  if not bool(daily_claimed.get(mission["id"],false)):
   return {"label":String(mission["label"]),"progress":int(daily.get(mission["id"],0)),
    "target":int(mission["target"])}
 return {"label":"ALL DAILY MISSIONS COMPLETE","progress":3,"target":3}

func snapshot() -> Dictionary:
 return {"version":1,"xp":xp,"level":level,"stars":stars,
  "total_plays":total_plays,"total_clears":total_clears,
  "total_drops":total_drops,"highest_combo":highest_combo,
  "achievements":achievements.duplicate(true),
  "day_key":day_key,"last_login":last_login,
  "streak":streak,"daily":daily.duplicate(true),
  "daily_claimed":daily_claimed.duplicate(true)}

func restore(raw:Dictionary) -> bool:
 if int(raw.get("version",0))!=1:
  return false
 var value:int=int(raw.get("xp",-1))
 if value<0:
  return false
 xp=mini(value,100000000)
 level=1
 while level<200 and xp>=xp_to_level_start(level+1):
  level+=1
 stars=clampi(int(raw.get("stars",0)),0,100000000)
 total_plays=maxi(0,int(raw.get("total_plays",0)))
 total_clears=maxi(0,int(raw.get("total_clears",0)))
 total_drops=maxi(0,int(raw.get("total_drops",0)))
 highest_combo=maxi(0,int(raw.get("highest_combo",0)))
 var saved_achievements:Variant=raw.get("achievements",{})
 achievements=saved_achievements.duplicate(true) if saved_achievements is Dictionary else {}
 day_key=String(raw.get("day_key",""))
 last_login=String(raw.get("last_login",""))
 streak=clampi(int(raw.get("streak",0)),0,9999)
 var saved_daily:Variant=raw.get("daily",{})
 var saved_claimed:Variant=raw.get("daily_claimed",{})
 daily=saved_daily.duplicate(true) if saved_daily is Dictionary else {}
 daily_claimed=saved_claimed.duplicate(true) if saved_claimed is Dictionary else {}
 sync_daily(_today())
 return true
