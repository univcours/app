extends RefCounted
## Persistent, offline-first, non-monetized metagame.
## Replayable sessions stay free; achievements and daily rewards pay only once.
const RANKS = ["ROOKIE","BRONZE","SILVER","GOLD","EMERALD","SAPPHIRE","DIAMOND","MASTER","NOVA LEGEND"]
const RANK_LEVELS = [1,3,7,12,20,31,45,62,82]
const THEMES = ["NEON","OCEAN","VIOLET","EMERALD","GOLD"]
const THEME_LEVELS = [1,4,9,16,28]
# Offline-only cosmetic auras purchased exclusively with earned Stars.
const SKIN_NAMES = ["CLASSIC","AURORA","PRISM"]
const SKIN_PRICES = [0,35,80]
# Daily rotations preserve three short goals but vary targets and the
# clearing challenge by the UTC day. No server, ad or purchase is needed.
const DAILY_ROTATIONS = [
 {"place":8,"clear":4,"drop":8,"chains":0},
 {"place":10,"clear":2,"drop":6,"chains":2},
 {"place":12,"clear":6,"drop":10,"chains":0},
 {"place":6,"clear":1,"drop":8,"chains":1},
 {"place":9,"clear":5,"drop":6,"chains":0},
 {"place":10,"clear":2,"drop":10,"chains":2},
 {"place":8,"clear":4,"drop":12,"chains":0}
]
const MISSIONS = [
 {"id":"puzzle_plays","label":"PLACE 12 CRYSTALS","target":12,"xp":90,"stars":12},
 {"id":"line_clears","label":"CLEAR 6 LINES","target":6,"xp":120,"stars":18},
 {"id":"falling_drops","label":"DROP 10 BLOCKS","target":10,"xp":95,"stars":12}
]
var xp := 0
var level := 1
var stars := 0
var active_theme := 0
var active_skin:int=0
var owned_skins:Array=[true,false,false]
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

func unlocked_themes() -> int:
 var count:=0
 for minimum_level in THEME_LEVELS:
  if level>=int(minimum_level):
   count+=1
 return maxi(1,count)

func cycle_theme() -> String:
 active_theme=(active_theme+1)%unlocked_themes()
 return String(THEMES[active_theme])

func theme_name() -> String:
 return String(THEMES[clampi(active_theme,0,THEMES.size()-1)])

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
 for mission in missions_for_day(today):
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

func missions_for_day(day:String) -> Array:
 var epoch:float=Time.get_unix_time_from_datetime_string(day+"T00:00:00")
 var row:Dictionary=DAILY_ROTATIONS[posmod(int(floor(epoch/86400.0)),DAILY_ROTATIONS.size())]
 var place_target:int=int(row["place"])
 var drop_target:int=int(row["drop"])
 var middle:Dictionary
 if int(row["chains"])>0:
  var chains:int=int(row["chains"])
  middle={"id":"combo_chains","label":"MAKE %d REAL COMBOS"%chains,
   "label_fr":"RÉUSSIR %d COMBOS"%chains,"target":chains,"xp":125,"stars":18}
 else:
  var clear_target:int=int(row["clear"])
  middle={"id":"line_clears","label":"CLEAR %d GROUPS"%clear_target,
   "label_fr":"EFFACER %d GROUPES"%clear_target,
   "target":clear_target,"xp":120,"stars":18}
 return [
  {"id":"puzzle_plays","label":"PLACE %d CRYSTALS"%place_target,
   "label_fr":"PLACER %d CRISTAUX"%place_target,
   "target":place_target,"xp":90,"stars":12},
  middle,
  {"id":"falling_drops","label":"DROP %d BLOCKS"%drop_target,
   "label_fr":"POSER %d BLOCS"%drop_target,
   "target":drop_target,"xp":95,"stars":12}]

func missions_for_today() -> Array:
 sync_daily(_today())
 return missions_for_day(day_key)

func current_skin_name() -> String:
 return String(SKIN_NAMES[clampi(active_skin,0,SKIN_NAMES.size()-1)])

func next_skin_offer() -> Dictionary:
 var next:int=(active_skin+1)%SKIN_NAMES.size()
 return {"name":String(SKIN_NAMES[next]),"price":int(SKIN_PRICES[next]),
  "owned":bool(owned_skins[next])}

func cycle_or_unlock_skin() -> bool:
 # A purchase is explicit and never spends paid currency or ad rewards.
 var offer:Dictionary=next_skin_offer()
 var next:int=(active_skin+1)%SKIN_NAMES.size()
 if not bool(offer["owned"]):
  if stars<int(offer["price"]):
   last_reward="NEED %d STARS FOR %s"%[int(offer["price"]),offer["name"]]
   return false
  stars-=int(offer["price"])
  owned_skins[next]=true
  last_reward="UNLOCKED %s AURA"%String(offer["name"])
 else:
  last_reward="%s AURA EQUIPPED"%String(offer["name"])
 active_skin=next
 return true

func _days_apart(earlier:String,later:String) -> int:
 var a:float=Time.get_unix_time_from_datetime_string(earlier+"T00:00:00")
 var b:float=Time.get_unix_time_from_datetime_string(later+"T00:00:00")
 return int(round((b-a)/86400.0))

func _advance_daily(kind:String,amount:int) -> void:
 sync_daily(_today())
 if not daily.has(kind):
  return
 var idx:int=-1
 var missions:Array=missions_for_day(day_key)
 for i in missions.size():
  if missions[i]["id"]==kind:
   idx=i
   break
 if idx<0 or bool(daily_claimed.get(kind,false)):
  return
 var mission:Dictionary=missions[idx]
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
 if combo>=2:_advance_daily("combo_chains",1)
 _achievement("combo_3",highest_combo>=3,20)
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
 for mission in missions_for_day(day_key):
  if not bool(daily_claimed.get(mission["id"],false)):
   return {"label":String(mission["label"]),"progress":int(daily.get(mission["id"],0)),
    "target":int(mission["target"])}
 return {"label":"ALL DAILY MISSIONS COMPLETE","progress":3,"target":3}

func snapshot() -> Dictionary:
 return {"version":1,"xp":xp,"level":level,"stars":stars,"active_theme":active_theme,
  "active_skin":active_skin,"owned_skins":owned_skins.duplicate(),
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
 active_theme=clampi(int(raw.get("active_theme",0)),0,unlocked_themes()-1)
 owned_skins=[true,false,false]
 var saved_skins:Variant=raw.get("owned_skins",[])
 if saved_skins is Array and saved_skins.size()==SKIN_NAMES.size():
  for i in range(1,SKIN_NAMES.size()):
   owned_skins[i]=bool(saved_skins[i])
 active_skin=clampi(int(raw.get("active_skin",0)),0,SKIN_NAMES.size()-1)
 if not bool(owned_skins[active_skin]):active_skin=0
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
