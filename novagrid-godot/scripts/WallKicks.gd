extends RefCounted
## MIT-licensed SRS-style kick tables sourced from Juan Cerrone's PokeTetris.
## Original file and MIT notice: res://third_party/poketetris/
## This adapter converts the upstream Vector2 tests to Godot 4's grid
## coordinates, and supplies conservative fallbacks for NovaGrid's mobile board.
const TABLES = preload("res://third_party/poketetris/Constants.gd")

static func offsets(kind_id:int,from_rotation:int,direction:int=1) -> Array[Vector2i]:
 var table: Array = TABLES.KICK_TABLE_I if kind_id==0 else TABLES.KICK_TABLE
 var from_state:int=posmod(from_rotation,4)
 var table_state:int=from_state if direction>=0 else posmod(from_state-1,4)
 var offsets_for_turn: Array = table[table_state]
 var result: Array[Vector2i] = []
 for raw in offsets_for_turn:
  var point:=Vector2i(roundi(raw.x),roundi(raw.y))
  if direction<0:
   point=-point
  if not result.has(point):
   result.append(point)
 # More conservative room for rotations along the floor on slim portrait boards.
 # This adds only legal candidate offsets: all attempts still call fits().
 for extra in [Vector2i(0,-1),Vector2i(0,-2),Vector2i(-1,0),Vector2i(1,0)]:
  if not result.has(extra):
   result.append(extra)
 return result
