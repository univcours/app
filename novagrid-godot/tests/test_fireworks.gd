extends SceneTree
## A genuine clear triggers animation and sound, with strict mobile budgets.
const Fireworks=preload("res://scripts/FireworksShow.gd")
const Audio=preload("res://scripts/Audio.gd")
const SaveStore=preload("res://scripts/SaveStore.gd")
var failures:Array[String]=[]

func verify(value:bool,label:String)->void:
 if not value:
  failures.append(label)
  printerr("FIREWORKS FAIL: "+label)

func _initialize()->void:
 call_deferred("_run")

func _run()->void:
 verify(Fireworks.tier_for_groups(0)==0,"no group yields no fireworks")
 verify(Fireworks.tier_for_groups(1)==1,"one group single burst")
 verify(Fireworks.tier_for_groups(2)==2,"two groups double burst")
 verify(Fireworks.tier_for_groups(3)==3,"three groups mega celebration")
 verify(Fireworks.tier_for_groups(4)==4 and Fireworks.tier_for_groups(8)==4,
  "four or more real groups trigger legendary tier")
 var area:=Rect2(Vector2(21,200),Vector2(390,390))
 var fx=Fireworks.new()
 root.add_child(fx)
 fx.launch(0,area,"NOVA")
 verify(not fx.active and fx.shells.is_empty(),"no fake fireworks without a clear")
 var counts:Array[int]=[]
 for groups in [1,2,3,4]:
  fx.launch(groups,area,"NOVA PLAYER")
  counts.append(fx.shells.size())
 verify(counts==[1,2,3,5],"sky rockets grow with genuine clear count")
 fx.launch(4,area,"NOVA PLAYER",true)
 verify(fx.shells.size()==2,"reduced graphics cap simultaneous rockets")
 for frame in 21:fx._process(.06)
 verify(fx.particles.size()<=Fireworks.MAX_LOW_SPARKS,
  "low settings cap all visible fireworks sparks")
 verify(fx.name_emitted and (fx.letters.size()>0 or fx.unicode_label),
  "legendary shower paints the player's name with actual sparks")
 verify(fx.letters.size()<=Fireworks.MAX_LOW_LETTERS,
  "low settings cap letter fragment counts")
 fx.launch(4,area,"أحمد")
 for frame in 21:fx._process(.06)
 verify(fx.unicode_label and fx.player_name=="أحمد",
  "Arabic name stays intact with native font fallback")
 fx.reset_show()
 verify(not fx.active and fx.particles.is_empty() and fx.shells.is_empty(),
  "round restart recycles all particle pools")
 var sounds=Audio.new()
 root.add_child(sounds)
 for key in ["firework_small","firework_double","firework_mega","firework_legendary"]:
  verify(sounds.sounds.has(key),"original fireworks audio exists for "+key)
  if sounds.sounds.has(key):
   var wave:AudioStreamWAV=sounds.sounds[key]
   verify(wave.data.size()>16000,"audible synthesised explosion for "+key)
 var game=load("res://scenes/Main.tscn").instantiate()
 root.add_child(game)
 game.set_process(false)
 await process_frame
 game.entry="classic"
 game.mode=0
 game.paused=false
 game.settings_open=false
 game.puzzle.reset()
 for x in 8:game.puzzle.cells[1][x]=1
 game.puzzle.tray[0]=[Vector2i.ZERO]
 game.puzzle.tray[1]=[]
 game.puzzle.tray[2]=[]
 var initial_score:int=game.puzzle.score
 verify(game.puzzle.place(0,Vector2i(8,1)),"single real row completes")
 var gained:int=game.puzzle.last_gained
 verify(game.puzzle.last_groups==1 and gained>0,"only real clear earns points")
 game._launch_fireworks(game.puzzle.last_groups,gained,game._layout()["board"])
 verify(game.fireworks.tier==1 and game.puzzle.score==initial_score+gained,
  "fireworks are strictly visual and never add free score")
 verify(game._settings_boxes(game._layout()).size()==6,
  "settings offers six usable actions, including player-name editor")
 game.player_name_entry.visible=true
 game.player_name_entry.text="NOVA CHAMP"
 game._save_player_name()
 verify(game.player_name=="NOVA CHAMP",
  "name input commits player-selected identity")
 var saved:Dictionary=SaveStore.read()
 verify(saved.get("player_name","")=="NOVA CHAMP",
  "name survives SaveStore save without changing puzzle schema")
 game.fireworks.launch(4,game._layout()["board"],game.player_name,false)
 verify(game.fireworks.player_name=="NOVA CHAMP",
  "legendary show uses the current persisted player name")
 root.remove_child(game)
 game.free()
 root.remove_child(sounds)
 sounds.free()
 root.remove_child(fx)
 fx.free()
 await process_frame
 if failures.is_empty():
  print("ALL NOVAGRID FIREWORKS AUDIO AND PLAYER-NAME TESTS PASSED")
  quit(0)
 else:
  printerr("%d NOVAGRID FIREWORKS TESTS FAILED" % failures.size())
  quit(1)
