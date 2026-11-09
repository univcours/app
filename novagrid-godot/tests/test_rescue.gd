extends SceneTree
## Deterministic regression coverage for earned rescues, blocked spawns,
## replay confirmation, save/restore and double-spend prevention.
const Puzzle=preload("res://scripts/Puzzle.gd")
const Falling=preload("res://scripts/Falling.gd")
# Desktop mock: never loads advertisements, only exercises opt-in state.
class FakeRewardAds:
 extends Node
 var show_count:int=0
 func can_offer_rewarded() -> bool:
  return true
 func show_rewarded_for_rescue() -> bool:
  show_count+=1
  return true

var failures:Array[String]=[]

func check(ok:bool,why:String)->void:
 if not ok:
  failures.append(why)
  printerr("RESCUE QA FAIL: "+why)

func _initialize()->void:
 call_deferred("_run")

func _run()->void:
 var p=Puzzle.new()
 p.reset()
 p.total_lines=3
 for x in 8:p.cells[1][x]=1
 p.tray[0]=[Vector2i.ZERO]
 p.tray[1]=[]
 p.tray[2]=[]
 check(p.place(0,Vector2i(8,1)),"real fourth line can be completed")
 check(p.total_lines==4 and p.bombs==1 and p.bomb_milestone==1,
  "four cleared groups earn exactly one blast")
 var won:int=p.score
 p.cells[4][4]=3
 check(p.detonate_bomb(Vector2i(4,4))==1 and p.bombs==0 and p.score==won,
  "rescue burns one charge and never grants fake score")
 check(p.detonate_bomb(Vector2i(4,4))==0,
  "spent blast cannot trigger twice")
 p.reset()
 for y in 9:
  for x in 9:p.cells[y][x]=1
 p.tray[0]=[Vector2i.ZERO]
 p.tray[1]=[]
 p.tray[2]=[]
 p.bombs=1
 p._check_game_over()
 check(not p.over and p.needs_rescue(),"blocked Classic retains earned rescue")
 var rescue_save:Dictionary=p.save_state()
 rescue_save["over"]=true # simulate older build's premature defeat
 var restored=Puzzle.new()
 check(restored.load_state(rescue_save) and not restored.over and restored.bombs==1,
  "legacy premature loss is recovered without losing earned charge")
 check(restored.detonate_bomb(Vector2i(4,4))==9,
  "earned 3x3 blast frees occupied cells")
 check(restored.any_move() and not restored.over and restored.bombs==0,
  "rescue reopens real Classic placements")
 restored.reset()
 for y in 9:
  for x in 9:restored.cells[y][x]=2
 restored.tray[0]=[Vector2i.ZERO]
 restored.tray[1]=[]
 restored.tray[2]=[]
 restored.bombs=0
 restored._check_game_over()
 check(restored.over,"no move and no rescue is genuine Classic game over")
 check(restored.grant_rewarded_blast() and not restored.over and restored.needs_rescue(),
  "confirmed rewarded callback revives blocked Classic with exactly one blast")
 check(restored.bombs==1 and restored.detonate_bomb(Vector2i(4,4))==9,
  "rewarded Classic blast clears occupied grid, not fake lines")
 var f=Falling.new()
 f.reset()
 f.lines=3
 f._award_rescues()
 check(f.rescues==0,"no Blockfall rescue before four real rows")
 f.lines=4
 f._award_rescues()
 check(f.rescues==1 and f.rescue_milestone==1,"four real falling rows earn rescue")
 f.lines=12
 f._award_rescues()
 check(f.rescues==2 and f.rescue_milestone==3,
  "additional earned rescues cap at two and advance milestones")
 f.rescues-=1
 f._award_rescues()
 check(f.rescues==1,"spent Blockfall rescue cannot be farmed from old rows")
 f.reset()
 f.rescues=1
 f.next_kind=1 # O tetromino occupies x=3,4 at spawn
 for x in range(3,6):f.board[0][x]=2
 f._spawn()
 check(f.rescue_pending and not f.over and f.can_rescue(),
  "blocked Blockfall spawn offers available blast before defeat")
 check(not f.tick() and not f.move(1) and f.hard_drop()==0,
  "blocked active piece cannot move, tick or secretly lock")
 var pending:Dictionary=f.snapshot()
 var fp=Falling.new()
 check(fp.restore(pending) and fp.rescue_pending and fp.rescues==1,
  "blocked spawn and remaining earned blast persist on save/restore")
 check(f.detonate_rescue(Vector2i(4,0))==3,
  "Blockfall blast removes obstructing 3x3 area")
 check(not f.rescue_pending and not f.over and f.rescues==0 and f.fits(f.piece,f.active),
  "blast resumes the EXACT stalled tetromino, no skipped piece")
 check(f.drops==0 and f.score==0 and f.lines==0,
  "Blockfall rescue does not fabricate lock, score or cleared rows")
 f.reset()
 f.rescues=2
 f.next_kind=1
 f.board[0][3]=1
 f.board[0][4]=1
 f.board[17][1]=4
 f._spawn()
 check(f.rescue_pending,"two-blast blocked spawn")
 check(f.detonate_rescue(Vector2i(1,17))==1 and f.rescue_pending and f.rescues==1,
  "blast away from obstruction consumes charge but still offers another")
 check(f.detonate_rescue(Vector2i(3,0))==2 and not f.rescue_pending and not f.over,
  "second blast can restore playable state")
 f.reset()
 f.rescues=0
 f.next_kind=1
 f.board[0][3]=1
 f._spawn()
 check(f.over and not f.rescue_pending,"no rescue and blocked spawn is real defeat")
 check(f.grant_rewarded_blast() and not f.over and f.rescue_pending and f.rescues==1,
  "native reward revives Blockfall's EXACT blocked piece")
 check(f.detonate_rescue(Vector2i(3,0))==1 and not f.rescue_pending and not f.over,
  "rewarded Blockfall blast removes obstruction and resumes spawn")
 f.reset()
 check(not f.over and f.score==0 and f.rescues==0 and not f.rescue_pending,
  "Blockfall replay clears earned run charges and pending state")
 var app=load("res://scenes/Main.tscn").instantiate()
 root.add_child(app)
 await process_frame
 app.mode=0
 app.entry="classic"
 app.paused=false
 app.settings_open=false
 app.puzzle.moves=7
 app.puzzle.score=230
 app.puzzle.best=800
 var layout:Dictionary=app._layout()
 check(layout.has("replay") and layout["replay"].size.x>=40,
  "Classic has visible touch-friendly Replay hit box")
 var replay:Vector2=layout["replay"].get_center()
 app._press(replay)
 app._release(replay)
 check(app.restart_confirm and app.paused and app.puzzle.moves==7,
  "Replay asks for confirmation and does not erase the current run immediately")
 var viewport:Vector2=layout["viewport"]
 var modal:=Rect2(Vector2(viewport.x*.09,float(layout["height"])*.34),
  Vector2(viewport.x*.82,222))
 var cancel:Vector2=modal.position+Vector2(modal.size.x*.5,162)
 app._press(cancel)
 app._release(cancel)
 check(not app.restart_confirm and not app.paused and app.puzzle.moves==7,
  "Cancel Replay returns to same game without any lost progress")
 app._press(replay)
 app._release(replay)
 var confirm:Vector2=modal.position+Vector2(modal.size.x*.5,125)
 app._press(confirm)
 app._release(confirm)
 check(not app.restart_confirm and not app.paused and app.puzzle.moves==0 and
  app.puzzle.score==0 and app.puzzle.best>=800,
  "confirmed Classic Replay resets current run but preserves best score")
 app.mode=1
 app.falling.hard_drop()
 var saved_best:int=app.falling.best
 app._press(replay)
 app._release(replay)
 check(app.restart_confirm,"Blockfall also exposes Replay confirmation")
 app._press(confirm)
 app._release(confirm)
 check(app.falling.drops==0 and app.falling.score==0 and app.falling.best>=saved_best,
  "Blockfall Replay resets current run and preserves best")
 # Rewarded ad: two-step opt-in on live HUD. No reward on first tap,
 # show(), skip or cancel; grant only when the actual SDK callback fires.
 var mock=FakeRewardAds.new()
 app.add_child(mock)
 app.native_ads=mock
 app.mode=0
 app.puzzle.reset()
 app.paused=false
 app.settings_open=false
 var ad_button:Vector2=app._layout()["bomb"].get_center()
 app._press(ad_button)
 app._release(ad_button)
 check(app.reward_offer_open and app.paused and mock.show_count==0 and app.puzzle.bombs==0,
  "AD +1 offers clear disclosure without auto-playing or granting reward")
 app._press(cancel)
 app._release(cancel)
 check(not app.reward_offer_open and not app.paused and mock.show_count==0,
  "cancelling voluntary rewarded prompt leaves the run intact")
 app._press(ad_button)
 app._release(ad_button)
 app._press(confirm)
 app._release(confirm)
 check(mock.show_count==1 and app.reward_ad_in_progress and app.puzzle.bombs==0,
  "affirmative consent shows one ad and never grants reward in advance")
 app.rewarded_ad_finished(false)
 check(app.puzzle.bombs==0 and not app.paused,
  "skipped rewarded video does not grant an earned blast")
 app._press(ad_button)
 app._release(ad_button)
 app._press(confirm)
 app._release(confirm)
 app.grant_ad_rescue()
 app.grant_ad_rescue() # duplicate native callback must never credit twice
 check(app.puzzle.bombs==1,
  "a completed rewarded video gives EXACTLY one blast, even on duplicate callback")
 app.rewarded_ad_finished(true)
 check(not app.reward_ad_in_progress and not app.paused,
  "earned reward finishes ad state and resumes gameplay")
 app.queue_free()
 await process_frame
 if failures.is_empty():
  print("ALL NOVAGRID BOTH-MODE REPLAY AND RESCUE QA TESTS PASSED")
  quit(0)
 else:
  printerr("%d RESCUE QA FAILURES"%failures.size())
  quit(1)
