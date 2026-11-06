extends SceneTree
## Run: godot --headless --path novagrid-godot --script res://tests/test_game.gd
const Puzzle = preload("res://scripts/Puzzle.gd")
const Falling = preload("res://scripts/Falling.gd")
const Crystal = preload("res://scripts/Crystal3D.gd")
var errors: Array = []
func expect(value:bool,description:String) -> void:
 if not value:
  errors.append(description)
  printerr("FAIL: "+description)

func _initialize() -> void:
 var p = Puzzle.new()
 expect(p.cells.size()==12 and p.cells[0].size()==10,"puzzle is 10x12")
 expect(p.tray.size()==3,"three pieces ready to play")
 var played := false
 for slot in 3:
  if played:
   break
  for y in 12:
   if played:
    break
   for x in 10:
    if p.fits(p.tray[slot],Vector2i(x,y)):
     played = p.place(slot,Vector2i(x,y))
     if played:
      break
 expect(played and p.score>0 and p.moves==1,"puzzle piece placement scores")
 var saved:Dictionary = p.save_state()
 var p2 = Puzzle.new()
 expect(p2.load_state(saved) and p2.score==p.score,"puzzle save round trip")
 expect(p2.undo()==false,"undo snapshots are not persisted")
 p.reset()
 for x in 9:
  p.cells[1][x]=1
 p.tray[0]=[Vector2i(0,0)]
 expect(p.place(0,Vector2i(9,1)),"complete real row")
 expect(p.last_cleared==10 and p.combo==1,"row clears ten cells")
 expect(p.undo() and p.cells[1][0]==1,"undo restores state")
 var f = Falling.new()
 expect(f.board.size()==18 and f.board[0].size()==10,"falling board is 10x18")
 expect(f.piece.size()==4 and not f.over,"falling first piece spawns")
 expect(f.ghost_row()>=f.active.y,"ghost projection valid")
 var initial_score:int = f.score
 f.hard_drop()
 expect(f.drops==1 and not f.over and f.lines==0,"hard drop locks without accidental game over")
 expect(f.score-initial_score<100,"non-clearing fall does not grant fake 1200 points")
 var snapshot:Dictionary = f.snapshot()
 var f2 = Falling.new()
 expect(f2.restore(snapshot) and f2.drops==1,"falling save round trip")
 var fake:Dictionary = snapshot.duplicate(true)
 fake["board"]=[]
 expect(not f2.restore(fake),"invalid save rejected")
 var glass_mesh:ArrayMesh = Crystal.make_beveled_cube()
 expect(glass_mesh.get_surface_count()==1,"real 3D rounded crystal mesh generated")
 var arrays:Array = glass_mesh.surface_get_arrays(0)
 expect((arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array).size()>=400,
  "3D mesh contains curved beveled geometry, not flat rectangles")
 expect((arrays[Mesh.ARRAY_NORMAL] as PackedVector3Array).size()==
  (arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array).size(),
  "3D mesh includes smooth surface normals")
 if errors.is_empty():
  print("ALL NOVAGRID GODOT RULE TESTS PASSED")
  quit(0)
 else:
  printerr("%d GODOT RULE TESTS FAILED" % errors.size())
  quit(1)
