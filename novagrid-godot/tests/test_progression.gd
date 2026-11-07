extends SceneTree
## Independent metagame QA: reward integrity, day boundaries, ranks and restores.
const Progression = preload("res://scripts/Progression.gd")
var failures: Array = []
func check(ok:bool,label:String) -> void:
 if not ok:
  failures.append(label)
  printerr("PROGRESSION FAIL: "+label)

func _initialize() -> void:
 var p=Progression.new()
 check(p.level==1 and p.rank_name()=="ROOKIE","level-one novice rank")
 check(p.level_progress()>=0.0 and p.level_progress()<=1.0,"bounded progress")
 var initial_stars:int=p.stars
 for i in 12:
  p.placed_piece()
 check(p.total_plays==12 and p.xp>=12*6,"XP credited for valid placements")
 check(bool(p.daily_claimed.get("puzzle_plays",false)),"daily placement mission completed")
 check(p.stars>=initial_stars+12+10,"daily and first achievement paid")
 var earned:int=p.stars
 p._advance_daily("puzzle_plays",1)
 check(p.stars==earned,"same daily mission cannot pay twice")
 for i in 55:
  p.locked_falling_piece()
 check(p.total_drops==55 and p.achievements.get("falling_ace",false),"falling achievements")
 check(p.rank_name()!="ROOKIE","rank increases with XP")
 p.cleared_lines(6,5)
 check(p.highest_combo==5 and p.achievements.get("combo_5",false),"real combo milestone")
 var original:Dictionary=p.snapshot()
 var copy=Progression.new()
 check(copy.restore(original),"offline progress restore")
 check(copy.xp==p.xp and copy.stars==p.stars and copy.total_drops==p.total_drops,"progress persistence")
 var previous_stars:int=copy.stars
 copy.sync_daily(copy.day_key)
 check(copy.stars==previous_stars,"same-day login cannot duplicate")
 var yesterday:String=copy.day_key
 var next_day:String=Time.get_date_string_from_unix_time(Time.get_unix_time_from_datetime_string(yesterday+"T00:00:00")+86400.0)
 copy.sync_daily(next_day)
 check(copy.streak>=2 and copy.stars>previous_stars,"consecutive-day bonus")
 var other=Progression.new()
 check(not other.restore({"version":0}),"invalid save rejected")
 if failures.is_empty():
  print("ALL NOVAGRID METAGAME TESTS PASSED")
  quit(0)
 else:
  printerr("%d NOVAGRID METAGAME TESTS FAILED" % failures.size())
  quit(1)
