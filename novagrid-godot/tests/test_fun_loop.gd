extends SceneTree
## Reward integrity: varied UTC goals, authentic Super Combos and Stars-only
## cosmetic unlocks / native menu save / cached mobile glass shaders.
const Progression=preload("res://scripts/Progression.gd")
const SaveStore=preload("res://scripts/SaveStore.gd")
var failures:Array[String]=[]

func check(ok:bool,description:String)->void:
 if not ok:
  failures.append(description)
  printerr("FUN LOOP FAIL: "+description)

func _initialize()->void:
 call_deferred("_run")

func _run()->void:
 var p=Progression.new()
 var today:String=p._today()
 var epoch:float=Time.get_unix_time_from_datetime_string(today+"T00:00:00")
 var versions:Dictionary={}
 var chain_day:String=""
 var clear_day:String=""
 for i in 7:
  var date:String=Time.get_date_string_from_unix_time(epoch+float(i+1)*86400.0)
  var missions:Array=p.missions_for_day(date)
  check(missions.size()==3,"every UTC day presents exactly three missions")
  var ids:Dictionary={}
  var signature:String=""
  for m in missions:
   ids[String(m["id"])]=true
   check(int(m["target"])>=1 and int(m["target"])<=12,
    "mission is short and attainable "+String(m["id"]))
   check(not String(m["label_fr"]).is_empty(),"daily mission has French translation")
   signature+="|"+String(m["label"])
  versions[signature]=true
  check(ids.has("puzzle_plays") and ids.has("falling_drops"),
   "daily targets cover both Classic and Blockfall")
  if ids.has("combo_chains") and chain_day=="":chain_day=date
  if ids.has("line_clears") and clear_day=="":clear_day=date
 check(versions.size()>=4,"daily mission goals vary across the week")
 check(chain_day!="" and clear_day!="",
  "weekly mission schedule alternates clears and real combo chains")
 var short_missions:Array=p.missions_for_today()
 var place:int=int(short_missions[0]["target"])
 var before:int=p.stars
 for i in place:p.placed_piece()
 check(bool(p.daily_claimed.get("puzzle_plays",false)),
  "real Classic placements complete short daily task")
 check(p.stars==before+22,"first placement achievement and mission award genuine Stars")
 before=p.stars
 p.placed_piece()
 check(p.stars==before,"replayed placement never pays mission twice")
 p.sync_daily(chain_day)
 var combo_goal:int=0
 for m in p.missions_for_day(chain_day):
  if m["id"]=="combo_chains":combo_goal=int(m["target"])
 check(combo_goal>0,"combo day really offers combo-chains objective")
 for i in combo_goal:p.cleared_lines(1,2)
 check(bool(p.daily_claimed.get("combo_chains",false)),
  "only real combo >=2 contributes to daily combo mission")
 before=p.stars
 p.cleared_lines(1,2)
 check(p.stars==before,"combo mission cannot pay twice after completion")
 p.sync_daily(clear_day if clear_day>chain_day else Time.get_date_string_from_unix_time(
  Time.get_unix_time_from_datetime_string(chain_day+"T00:00:00")+8.0*86400.0))
 # Directly inspect a known clear-type day without fake reward events.
 check(p.missions_for_day(clear_day)[1]["id"]=="line_clears",
  "other daily rotation includes genuine line-clear goal")
 var shop=Progression.new()
 shop.stars=20
 var cheap_snapshot:Dictionary=shop.snapshot()
 check(not shop.cycle_or_unlock_skin(),"not enough earned Stars blocks cosmetic unlock")
 check(shop.stars==20 and shop.active_skin==0 and
  shop.snapshot()["owned_skins"]==cheap_snapshot["owned_skins"],
  "failed skin unlock cannot deduct stars or modify ownership")
 shop.stars=115
 check(shop.cycle_or_unlock_skin() and shop.active_skin==1 and shop.stars==80,
  "AURORA costs exactly 35 earned Stars")
 check(shop.cycle_or_unlock_skin() and shop.active_skin==2 and shop.stars==0,
  "PRISM costs exactly 80 earned Stars")
 check(shop.cycle_or_unlock_skin() and shop.active_skin==0 and shop.stars==0,
  "owned CLASSIC skin can be selected for free")
 check(shop.cycle_or_unlock_skin() and shop.active_skin==1 and shop.stars==0,
  "switching to an already owned skin costs no Stars")
 var saved:Dictionary=shop.snapshot()
 var copy=Progression.new()
 check(copy.restore(saved) and copy.active_skin==1 and
  copy.owned_skins==shop.owned_skins,"cosmetic ownership and selected shader persist")
 var legacy:Dictionary=saved.duplicate(true)
 legacy.erase("active_skin")
 legacy.erase("owned_skins")
 check(copy.restore(legacy) and copy.active_skin==0 and
  copy.owned_skins==[true,false,false],
  "pre-sprint progression saves restore safely")
 # Real UI + shader integration. No stale fixture can receive paid currency.
 var welcome=load("res://scenes/Welcome.tscn").instantiate()
 root.add_child(welcome)
 welcome.screen="settings"
 var target:Dictionary=welcome._targets()
 check(target.has("skin") and target["skin"].size.y>=44.0,
  "native settings has a large reachable crystal-skin tap target")
 welcome.progress.stars=115
 welcome._activate("skin")
 check(welcome.progress.active_skin==1 and welcome.progress.stars==80,
  "the real settings action buys the selected aura")
 var state:Dictionary=SaveStore.read()
 check(state.has("progression") and int(state["progression"]["active_skin"])==1,
  "skin purchase is persisted atomically, without affecting game state")
 var vp:SubViewport=welcome.visuals.tile_viewports[2]
 var mat:ShaderMaterial=(vp.get_child(0).material as ShaderMaterial)
 check(is_equal_approx(float(mat.get_shader_parameter("inner_illumination")),1.55),
  "AURORA changes actual baked neon crystal shader illumination")
 var game=load("res://scenes/Main.tscn").instantiate()
 root.add_child(game)
 check(game.progress.active_skin==1,"Classic and Blockfall load purchased aura")
 check(is_equal_approx(float(
   (game.visuals.tile_viewports[2].get_child(0).material as ShaderMaterial
   ).get_shader_parameter("inner_illumination")),1.55),
  "gameplay draws purchased shader instead of showing a fake store preview")
 game.queue_free()
 welcome.queue_free()
 await process_frame
 if failures.is_empty():
  print("ALL NOVAGRID FUN LOOP DAILY COMBO AND AURA TESTS PASSED")
  quit(0)
 else:
  printerr("%d NOVAGRID FUN LOOP TESTS FAILED"%failures.size())
  quit(1)
