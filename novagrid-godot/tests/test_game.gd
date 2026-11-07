extends SceneTree
## Run: godot --headless --path novagrid-godot --script res://tests/test_game.gd
const Puzzle = preload("res://scripts/Puzzle.gd")
const Falling = preload("res://scripts/Falling.gd")
var errors: Array = []
func expect(value:bool,description:String) -> void:
 if not value:
  errors.append(description)
  printerr("FAIL: "+description)

func _initialize() -> void:
 var p = Puzzle.new()
 expect(p.cells.size()==9 and p.cells[0].size()==9,"Classic reference grid is truly 9x9")
 expect(p.tray.size()==3,"three pieces ready to play")
 var played := false
 for slot in 3:
  if played:
   break
  for y in 9:
   if played:
    break
   for x in 9:
    if p.fits(p.tray[slot],Vector2i(x,y)):
     played = p.place(slot,Vector2i(x,y))
     if played:
      break
 expect(played and p.score==0 and p.moves==1,"piece placement gives zero points until a line is cleared")
 var saved:Dictionary = p.save_state()
 var p2 = Puzzle.new()
 expect(p2.load_state(saved) and p2.score==p.score,"puzzle save round trip")
 expect(p2.undo()==false,"undo snapshots are not persisted")
 p.reset()
 for x in 8:
  p.cells[1][x]=1
 p.tray[0]=[Vector2i(0,0)]
 expect(p.place(0,Vector2i(8,1)),"complete real row")
 expect(p.last_cleared==9 and p.last_groups==1 and p.combo==1 and p.score>0,"completed 9-cell row scores exclusively by clearance")
 expect(p.total_lines==1,"puzzle counts complete rows instead of placement count")
 expect(p.undo() and p.cells[1][0]==1,"undo restores state")
 p.reset()
 for x in 8:
  p.cells[2][x]=1
  p.cells[3][x]=1
 p.tray[0]=[Vector2i(0,0),Vector2i(0,1)]
 expect(p.place(0,Vector2i(8,2)),"two rows at the same time")
 expect(p.last_groups==2 and p.combo==2 and p.total_lines==2 and p.score>=300,
  "simultaneous 2-line clear multiplies the combo and pays more")
 p.reset()
 for yy in 3:
  for xx in 3:
   if xx!=2 or yy!=2:
    p.cells[yy][xx]=2
 p.tray[0]=[Vector2i(0,0)]
 expect(p.place(0,Vector2i(2,2)),"complete original 3x3 sector")
 expect(p.last_groups==1 and p.last_cleared==9 and p.score>0,
  "9x9 Classic awards score for a fully cleared 3x3 sector")
 p.reset()
 p.score=4990
 p.total_lines=17
 for x in 9:
  p.cells[1][x]=1
 p.tray[0]=[Vector2i(0,0)]
 expect(p.place(0,Vector2i(9,1)) and p.bombs==1 and p.last_bomb_award==1,
  "rare bomb requires genuine final line clear and threshold score")
 var before_bomb_score:int=p.score
 p.cells[5][5]=3
 p.cells[4][4]=2
 expect(p.detonate_bomb(Vector2i(5,5))==2,"rare glass bomb clears up to 3x3 occupied area")
 expect(p.score==before_bomb_score and p.bombs==0 and p.total_lines==18,
  "bomb is a tactical rescue and never creates fake points or lines")
 expect(p.detonate_bomb(Vector2i(5,5))==0,"empty bomb inventory cannot activate twice")
 var saved_bomb:Dictionary=p.save_state()
 var copy_bomb=Puzzle.new()
 expect(copy_bomb.load_state(saved_bomb) and copy_bomb.bomb_milestone==1 and copy_bomb.bombs==0,
  "rare bomb milestone survives game save and restore")
 var f = Falling.new()
 expect(f.board.size()==18 and f.board[0].size()==10,"falling board is 10x18")
 expect(f.piece.size()==4 and not f.over,"falling first piece spawns")
 expect(f.ghost_row()>=f.active.y,"ghost projection valid")
 var initial_score:int = f.score
 f.hard_drop()
 expect(f.drops==1 and not f.over and f.lines==0,"hard drop locks without accidental game over")
 expect(f.score==initial_score,"non-clearing hard drop gives exactly ZERO points")
 var snapshot:Dictionary = f.snapshot()
 var f2 = Falling.new()
 expect(f2.restore(snapshot) and f2.drops==1,"falling save round trip")
 var soft_game=Falling.new()
 var previous_score:int=soft_game.score
 soft_game.soft_drop()
 expect(soft_game.score==previous_score,"soft drop gives zero points unless an actual row clears")
 var fake:Dictionary = snapshot.duplicate(true)
 fake["board"]=[]
 expect(not f2.restore(fake),"invalid save rejected")
 if errors.is_empty():
  print("ALL NOVAGRID GODOT RULE TESTS PASSED")
  quit(0)
 else:
  printerr("%d GODOT RULE TESTS FAILED" % errors.size())
  quit(1)
