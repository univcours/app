extends Node2D
## Responsive native cosmic launcher. Every visible action has a real destination.
const VisualsScript = preload("res://scripts/Visuals.gd")
const AudioScript = preload("res://scripts/Audio.gd")
const ProgressionScript = preload("res://scripts/Progression.gd")
const CampaignScript = preload("res://scripts/Campaign.gd")
const SaveStore = preload("res://scripts/SaveStore.gd")
const SafeArea = preload("res://scripts/SafeArea.gd")
const Typography = preload("res://scripts/Typography.gd")
const NeonSkin = preload("res://scripts/NeonSkin.gd")
const GEMS = [Color("#192850"),Color("#ff32a1"),Color("#ffdb27"),Color("#1feaff"),Color("#b65cff"),Color("#4cfb72"),Color("#ff8729"),Color("#248cff")]
const CYAN = Color("#3de4ff")
const PURPLE = Color("#b965ff")
const GOLD = Color("#ffd34b")
# Retain the correct proportions as a shared declaration for regression QA.
const FALL_PREVIEW_COLS:int=10
const FALL_PREVIEW_ROWS:int=18
const FALL_PREVIEW_T=[Vector2i(3,3),Vector2i(4,3),Vector2i(5,3),Vector2i(4,4)]
const FALL_PREVIEW_NEXT=[Vector2i(0,0),Vector2i(0,1),Vector2i(0,2),Vector2i(1,2)]
var visuals
var audio
var progress
var campaign
var clock:float=0.0
var screen:String="home"
var language:String="en"
var reduced_effects:bool=false
var chosen:int=-1
var transition_elapsed:float=0.0
var panel_cache:Dictionary={}
var pressed_key:String=""
var touch_position:Vector2=Vector2(-1000,-1000)
var save_data:Dictionary={}
var stars:Array=[]

func _ready() -> void:
 get_tree().quit_on_go_back=false
 visuals=VisualsScript.new()
 add_child(visuals)
 visuals.configure(GEMS)
 audio=AudioScript.new()
 add_child(audio)
 audio.select_music("menu")
 progress=ProgressionScript.new()
 campaign=CampaignScript.new()
 save_data=SaveStore.read()
 if save_data.get("progression") is Dictionary:
  progress.restore(save_data["progression"])
 if save_data.get("campaign") is Dictionary:
  campaign.restore(save_data["campaign"])
 var cfg:=ConfigFile.new()
 if cfg.load("user://novagrid-visual.cfg")==OK:
  language=String(cfg.get_value("interface","language","en"))
  reduced_effects=bool(cfg.get_value("graphics","reduced_effects",false))
 var rng:=RandomNumberGenerator.new()
 rng.seed=204812
 for i in 65:
  stars.append({"p":Vector2(rng.randf(),rng.randf()),"r":rng.randf_range(.5,1.6),"phase":rng.randf_range(0,TAU)})
 get_viewport().size_changed.connect(queue_redraw)

func _process(delta:float) -> void:
 clock+=delta
 if chosen>=0:
  transition_elapsed+=delta
  if transition_elapsed>.22:
   var error:int=get_tree().change_scene_to_file("res://scenes/Main.tscn")
   if error!=OK:
    printerr("NovaGrid gameplay transition failed: ",error)
    chosen=-1
 queue_redraw()

func _frame() -> Rect2:
 var view:Vector2=get_viewport_rect().size if is_inside_tree() else Vector2(432,960)
 var safe:Rect2=SafeArea.content_rect(view) if is_inside_tree() else Rect2(Vector2.ZERO,view)
 var s:float=minf(safe.size.x/432.0,safe.size.y/960.0)
 var size:Vector2=Vector2(432,960)*s
 return Rect2(safe.position+(safe.size-size)*.5,size)

func _local_transform(origin:Vector2=Vector2.ZERO,local_scale:Vector2=Vector2.ONE) -> void:
 var frame:Rect2=_frame()
 var s:float=frame.size.x/432.0
 draw_set_transform(frame.position+origin*s,0,local_scale*s)

func _real_rect(rect:Rect2) -> Rect2:
 var frame:Rect2=_frame()
 return Rect2(frame.position+rect.position*frame.size.x/432.0,rect.size*frame.size.x/432.0)

func _rectangles() -> Array[Rect2]:
 var result:Array[Rect2]=[]
 for i in 4:
  result.append(_real_rect(Rect2(28,462+i*100,376,84)))
 return result

func _map_nodes() -> Array[Rect2]:
 return [_real_rect(Rect2(86,300,84,84)),_real_rect(Rect2(269,466,84,84)),_real_rect(Rect2(96,644,84,84))]

func _targets() -> Dictionary:
 var result:Dictionary={}
 if screen=="home":
  var cards:Array[Rect2]=_rectangles()
  for i in 4: result["mode"+str(i)]=cards[i]
  result["settings"]=_real_rect(Rect2(346,26,60,60))
  result["nav_home"]=_real_rect(Rect2(28,883,125,46))
  result["nav_map"]=_real_rect(Rect2(153,883,125,46))
  result["nav_settings"]=_real_rect(Rect2(278,883,126,46))
 else:
  result["back"]=_real_rect(Rect2(26,30,58,58))
  if screen=="map":
   var nodes:Array[Rect2]=_map_nodes()
   for i in nodes.size(): result["stage"+str(i+1)]=nodes[i]
  elif screen=="daily":
   result["daily_play"]=_real_rect(Rect2(38,759,356,78))
  elif screen=="settings":
   for i in 4: result[["sound","music","quality","language"][i]]=_real_rect(Rect2(34,235+i*106,364,78))
 return result

func _tr(en:String,fr:String) -> String:
 return fr if language=="fr" else en

func _text(message:String,pos:Vector2,size:int=18,color:Color=Color.WHITE,width:float=-1,align:HorizontalAlignment=HORIZONTAL_ALIGNMENT_LEFT) -> void:
 Typography.draw_neon(self,message,pos,size,color,align,width)

func _center(message:String,y:float,size:int=18,color:Color=Color.WHITE) -> void:
 _text(message,Vector2(0,y),size,color,432,HORIZONTAL_ALIGNMENT_CENTER)

func _panel(rect:Rect2,accent:Color,fill:Color=Color("#071331"),radius:int=22) -> void:
 NeonSkin.panel(self,rect,accent,fill,radius,clock,
  pressed_key!="")

func _sparkle(pos:Vector2,radius:float,color:Color) -> void:
 draw_line(pos-Vector2(radius,0),pos+Vector2(radius,0),Color(color,.7),1.2,true)
 draw_line(pos-Vector2(0,radius*1.4),pos+Vector2(0,radius*1.4),Color(color,.7),1.2,true)
 draw_circle(pos,radius*.22,Color.WHITE)

func _planet(center:Vector2,radius:float,color:Color) -> void:
 for glow in range(5,0,-1): draw_circle(center,radius+glow*2.5,Color(color,.025))
 draw_circle(center,radius,Color("#080c2d"))
 for i in range(32,0,-1):
  var f:float=float(i)/32.0
  draw_circle(center-Vector2(radius*.21,radius*.16)*(1-f),radius*f,Color(color.darkened(.45*(1-f)),.065))
 draw_arc(center,radius,PI*1.01,PI*1.76,40,color.lightened(.3),2,true)
 for i in 6:
  var y:float=center.y+radius*(float(i)/6-.5)*1.6
  var half:float=sqrt(maxf(0,radius*radius-pow(y-center.y,2)))
  draw_line(Vector2(center.x-half*.85,y),Vector2(center.x+half*.75,y+radius*.10),Color(color,.14),3,true)

func _crystal(rect:Rect2,kind:int,depth:float=0.0) -> void:
 var tint:Color=GEMS[kind]
 if depth>0:
  var p:Vector2=rect.position
  var e:Vector2=rect.end
  var d:=Vector2(depth,-depth*.55)
  draw_colored_polygon(PackedVector2Array([p,p+d,Vector2(e.x,p.y)+d,Vector2(e.x,p.y)]),tint.lightened(.42))
  draw_colored_polygon(PackedVector2Array([Vector2(e.x,p.y),Vector2(e.x,p.y)+d,e+d,e]),tint.darkened(.20))
  draw_polyline(PackedVector2Array([p,p+d,Vector2(e.x,p.y)+d,e+d,e]),tint.lightened(.7),1.1,true)
 var texture:Texture2D=visuals.get_gem_texture(kind)
 if texture!=null: draw_texture_rect(texture,rect,false)
 else: draw_rect(rect,tint)

func _stars() -> void:
 for star in stars:
  var at:Vector2=star["p"]*Vector2(432,960)
  var alpha:float=.23+.33*sin(clock*.8+float(star["phase"]))
  draw_circle(at,float(star["r"]),Color(.8,.87,1,alpha))
 for i in 5:
  _sparkle(Vector2(28+i*88,192+fposmod(i*157.0,586)),2.3+sin(clock+i),Color("#cc85ff"))

func _hero() -> void:
 var bob:float=sin(clock*1.1)*4.5 if not reduced_effects else 0.0
 _local_transform(Vector2(216,391+bob),Vector2(1,.27))
 for i in range(7,0,-1): draw_arc(Vector2.ZERO,130+i,0,TAU,100,Color(.5,.16,1,.025*i),2,true)
 draw_arc(Vector2.ZERO,144,0,TAU,100,Color("#9c5aff"),3,true)
 draw_arc(Vector2.ZERO,124,0,TAU,100,CYAN,2,true)
 _local_transform()
 for block in [Vector3(135,330,4),Vector3(189,330,4),Vector3(243,330,3),Vector3(135,275,4),Vector3(189,275,2),Vector3(243,275,3),Vector3(189,220,2)]:
  _crystal(Rect2(block.x,block.y+bob,55,56),int(block.z),17)
 _sparkle(Vector2(298,247+bob),10,GOLD)
 _sparkle(Vector2(129,320+bob),6,PURPLE)
 _sparkle(Vector2(213,395+bob),9,CYAN)

func _home() -> void:
 _panel(Rect2(28,28,145,54),Color("#ff31ed"))
 _text("★",Vector2(40,63),29,GOLD)
 _text(str(progress.stars),Vector2(78,62),23)
 _panel(Rect2(188,28,145,54),CYAN)
 _text("LV "+str(progress.level),Vector2(205,62),22,Color("#d9e5ff"))
 _panel(Rect2(346,26,60,60),Color("#ff31ed"))
 NeonSkin.icon(self,"settings",Vector2(376,56),31,CYAN)
 _planet(Vector2(57,229),26,Color("#8566ff"))
 _planet(Vector2(386,157),40,Color("#5277fb"))
 _panel(Rect2(26,96,380,89),Color("#ff31ed"),Color("#07123c"),39)
 NeonSkin.star(self,Vector2(51,140),14,Color("#ff31ed"))
 for ring in 3:
  draw_arc(Vector2(219,143),143+ring*2,PI*1.10,PI*1.89,64,
   Color(CYAN.r,CYAN.g,CYAN.b,.05+ring*.05),1.5,true)
 var moving:float=115+fposmod(clock*27.0,194.0)
 _sparkle(Vector2(moving,101),3.5+sin(clock*2.0),CYAN)
 NeonSkin.logo(self,154,48,clock)
 _center(_tr("Cosmic Block Puzzle","Puzzle cosmique"),207,18,Color("#cbefff"))
 _hero()
 _center(_tr("YOUR NEXT ADVENTURE AWAITS","VOTRE AVENTURE COMMENCE"),440,11,Color("#aeb5e8"))
 var titles:Array=[_tr("Classic","Classique"),_tr("Daily Challenge","Défi du jour"),"Blockfall",_tr("Galaxy Stages","Étapes galactiques")]
 var subtitles:Array=[_tr("9 × 9 Puzzle","Puzzle 9 × 9"),_tr("A new challenge every day","Un nouveau défi chaque jour"),_tr("Endless block action","Blocs en chute libre"),_tr("3 handcrafted missions","3 missions faites à la main")]
 var hues:Array=[CYAN,NeonSkin.PINK,CYAN,NeonSkin.PINK]
 for i in 4:
  var box:=Rect2(28,462+i*100,376,84)
  var hue:Color=hues[i]
  if pressed_key=="mode"+str(i): box=box.grow(-2)
  NeonSkin.mode_button(self,box,titles[i],subtitles[i],
   ["classic","daily","blockfall","galaxy"][i],hue,clock,
   pressed_key=="mode"+str(i))
 var track:=Rect2(28,883,376,46)
 NeonSkin.navigation(self,track,["HOME","STAGES","SETTINGS"],0,clock)

func _heading(title:String,subtitle:String) -> void:
 _panel(Rect2(26,30,58,58),CYAN)
 NeonSkin.icon(self,"back",Vector2(55,59),30,CYAN)
 _text(title,Vector2(101,68),29)
 _center(subtitle,122,14,Color("#bfc8f1"))

func _map() -> void:
 _heading(_tr("Galaxy Stages","Étapes galactiques"),_tr("Three worlds. One cosmic journey.","Trois mondes. Un voyage cosmique."))
 _planet(Vector2(68,217),53,Color("#6753d3"))
 _planet(Vector2(399,627),45,Color("#2c6cce"))
 var points:=PackedVector2Array([Vector2(128,342),Vector2(180,405),Vector2(311,508),Vector2(280,589),Vector2(138,686)])
 var curve:=Curve2D.new()
 curve.add_point(points[0],Vector2.ZERO,Vector2(150,5))
 curve.add_point(points[2],Vector2(-7,-120),Vector2(-5,120))
 curve.add_point(points[4],Vector2(130,-18),Vector2.ZERO)
 var path:PackedVector2Array=curve.get_baked_points()
 for thickness in [15,9,4]: draw_polyline(path,Color(.37,.22,1,.06+float(15-thickness)*.018),thickness,true)
 draw_polyline(path,Color("#87b5ff"),1.7,true)
 var centers:Array=[Vector2(128,342),Vector2(311,508),Vector2(138,686)]
 for i in 3:
  var center:Vector2=centers[i]
  var open:bool=i+1<=campaign.unlocked
  var earned:int=int(campaign.completed.get(str(i+1),0))
  var accent:Color=GOLD if i+1==campaign.unlocked else CYAN if open else Color("#7385bd")
  _local_transform(center+Vector2(0,29),Vector2(1,.34))
  draw_circle(Vector2.ZERO,46,Color(accent,.16))
  draw_arc(Vector2.ZERO,45,0,TAU,64,accent,3,true)
  _local_transform()
  _panel(Rect2(center-Vector2(35,30),Vector2(70,60)),accent,Color(accent.darkened(.80)),26)
  if open:
   _text(str(i+1),center+Vector2(-35,11),31,Color.WHITE,70,HORIZONTAL_ALIGNMENT_CENTER)
  else:
   draw_arc(center-Vector2(0,5),8,PI,TAU,20,Color("#cad4ef"),2.2,true)
   draw_rect(Rect2(center-Vector2(12,5),Vector2(24,20)),Color("#cad4ef"))
   draw_circle(center+Vector2(0,2),2.4,Color("#24315e"))
   draw_line(center+Vector2(0,2),center+Vector2(0,8),Color("#24315e"),2,true)
  for s in 3:
   _text("★",center+Vector2(-29+s*20,-47),20,GOLD if s<earned else Color("#53618e"))
  var name:String=CampaignScript.NAMES[i]
  _text(name,center+Vector2(-82,65),14,Color("#e5eaff"),164,HORIZONTAL_ALIGNMENT_CENTER)
 var done:int=campaign.completed.size()
 _panel(Rect2(28,823,376,106),Color("#ff31ed"),Color("#081636"))
 _text(_tr("Your constellation","Votre constellation"),Vector2(48,858),24)
 _text(_tr("Missions completed","Missions terminées")+"  %d / 3"%done,Vector2(48,886),15,Color("#c6d4ff"))
 draw_rect(Rect2(48,903,336,6),Color("#262650"))
 if done>0: draw_rect(Rect2(48,903,112*done,6),GOLD)

func _daily() -> void:
 _heading(_tr("Daily Challenge","Défi du jour"),progress.day_key+"  ·  UTC")
 _planet(Vector2(216,242),68,Color("#8e4bca"))
 _crystal(Rect2(188,203,50,56),2,15)
 _panel(Rect2(28,344,376,172),GOLD)
 _center(_tr("CLEAR 6 GROUPS","ÉLIMINEZ 6 GROUPES"),389,26,GOLD)
 _center(_tr("Same crystals. A fresh puzzle every day.","Les mêmes cristaux. Un défi par jour."),420,15,Color("#d8dff4"))
 _center(_tr("Complete rows, columns or 3 × 3 boxes.","Complétez lignes, colonnes ou carrés 3 × 3."),448,14,Color("#d8dff4"))
 _center(_tr("Daily reward can be earned once.","La récompense est accordée une seule fois."),485,13,Color("#a9b6dc"))
 var daily:Dictionary=save_data.get("daily",{}) if save_data.get("daily",{}) is Dictionary else {}
 if daily.get("reward_day","")==progress.day_key:
  _center(_tr("TODAY’S REWARD EARNED","RÉCOMPENSE DU JOUR OBTENUE"),542,12,GOLD)
 _text(_tr("DAILY MISSIONS","MISSIONS DU JOUR"),Vector2(34,566),13,Color("#c2c6f1"))
 for i in progress.MISSIONS.size():
  var mission:Dictionary=progress.MISSIONS[i]
  var amount:int=int(progress.daily.get(mission["id"],0))
  var target:int=mission["target"]
  var y:float=596+i*47
  var labels:Array=[_tr("Place 12 crystals","Placez 12 cristaux"),_tr("Clear 6 groups","Éliminez 6 groupes"),_tr("Drop 10 blocks","Lâchez 10 blocs")]
  _text(labels[i],Vector2(36,y),16,Color("#e1e6ff"))
  _text("%d / %d"%[amount,target],Vector2(0,y),14,GOLD,395,HORIZONTAL_ALIGNMENT_RIGHT)
  draw_rect(Rect2(36,y+11,359,4),Color("#27294f"))
  if amount>0: draw_rect(Rect2(36,y+11,359*float(amount)/target,4),CYAN)
 _panel(Rect2(38,759,356,78),GOLD,Color("#55311a"))
 _center(_tr("PLAY TODAY'S PUZZLE","JOUER AU DÉFI DU JOUR"),808,24)
 _center(_tr("Your Classic run is saved separately.","Votre partie classique est sauvegardée."),887,13,Color("#a9b4d9"))

func _settings() -> void:
 _heading(_tr("Settings","Réglages"),_tr("Make this galaxy yours.","Votre galaxie, vos préférences."))
 var labels:Array=[_tr("Sound effects","Effets sonores"),_tr("Music","Musique"),_tr("Visual effects","Effets visuels"),_tr("Language","Langue")]
 var values:Array=[_tr("ON","OUI") if audio.sounds_enabled else _tr("OFF","NON"),_tr("ON","OUI") if audio.music_enabled else _tr("OFF","NON"),_tr("LOW","RÉDUITS") if reduced_effects else _tr("FULL","COMPLETS"),"FRANÇAIS" if language=="fr" else "ENGLISH"]
 for i in 4:
  var row:=Rect2(34,235+i*106,364,78)
  _panel(row,CYAN if i<2 else Color("#ff31ed"))
  _text(labels[i],row.position+Vector2(20,33),22)
  _text(values[i],row.position+Vector2(20,59),13,Color("#cbd8ff"))
  NeonSkin.icon(self,["sound","music","effects","language"][i],
   row.position+Vector2(326,39),20,CYAN if i%2==0 else NeonSkin.PINK)
 _center(_tr("Every setting is saved on this device.","Vos préférences sont sauvegardées ici."),750,15,Color("#b4c2e6"))
 _center("NovaGrid · Cosmic Edition",884,17,Color("#8c9dce"))

func _draw() -> void:
 if visuals==null: return
 var view:Vector2=get_viewport_rect().size
 draw_rect(Rect2(Vector2.ZERO,view),Color(.012,.012,.055,.42))
 var frame:Rect2=_frame()
 var s:float=frame.size.x/432.0
 draw_set_transform(frame.position,0,Vector2(s,s))
 _stars()
 match screen:
  "map": _map()
  "daily": _daily()
  "settings": _settings()
  _: _home()
 draw_set_transform(Vector2.ZERO)
 if chosen>=0:
  draw_rect(Rect2(Vector2.ZERO,view),Color(.01,.01,.05,clampf(transition_elapsed/.25,0,1)))

func _launch(index:int,entry:String="",stage:int=1) -> void:
 if chosen>=0: return
 if entry=="stage" and (stage<1 or stage>campaign.unlocked or stage>CampaignScript.TOTAL_STAGES): return
 var session:Node=get_node_or_null("/root/Session")
 if session==null: return
 session.set("start_mode",index)
 session.set("entry",entry if entry!="" else "classic" if index==0 else "blockfall")
 session.set("stage",stage)
 chosen=index
 transition_elapsed=0
 audio.effect("tap")

func _activate(key:String) -> void:
 if chosen>=0: return
 var sound_key:String="tap"
 if key in ["settings","nav_settings","mode1","mode3","nav_map"]:
  sound_key="popup"
 elif key=="back" or key=="nav_home":
  sound_key="close"
 elif key in ["sound","music","quality","language"]:
  sound_key="toggle"
 audio.effect(sound_key)
 match key:
  "mode0": _launch(0,"classic")
  "mode1": screen="daily"
  "mode2": _launch(1,"blockfall")
  "mode3": screen="map"
  "settings": screen="settings"
  "nav_home": screen="home"
  "nav_map": screen="map"
  "nav_settings": screen="settings"
  "back": screen="home"
  "daily_play": _launch(0,"daily")
  "sound": audio.toggle_sound()
  "music": audio.toggle_music("menu")
  "quality":
   reduced_effects=not reduced_effects
   _save_preferences()
   visuals.reduced_effects=reduced_effects
   visuals.sky_material.set_shader_parameter("reduced_effects",reduced_effects)
   visuals.sky_material.set_shader_parameter("activity",.45 if reduced_effects else .75)
   visuals.sky_material.set_shader_parameter("motion_speed",0.0 if reduced_effects else .08)
  "language":
   language="fr" if language=="en" else "en"
   _save_preferences()
  _:
   if key.begins_with("stage"):
    var level:int=int(key.trim_prefix("stage"))
    if level>=1 and level<=campaign.unlocked:
     _launch(0,"stage",level)
    else:
     audio.effect("invalid")
 queue_redraw()

func _save_preferences() -> void:
 var cfg:=ConfigFile.new()
 cfg.load("user://novagrid-visual.cfg")
 cfg.set_value("graphics","reduced_effects",reduced_effects)
 cfg.set_value("interface","language",language)
 cfg.save("user://novagrid-visual.cfg")

func _press(pos:Vector2) -> void:
 pressed_key=""
 touch_position=pos
 if chosen>=0: return
 var targets:Dictionary=_targets()
 for key in targets:
  if targets[key].has_point(pos):
   pressed_key=key
   break
 queue_redraw()

func _release(pos:Vector2) -> void:
 var targets:Dictionary=_targets()
 if pressed_key!="" and targets.has(pressed_key) and targets[pressed_key].has_point(pos):
  _activate(pressed_key)
 pressed_key=""
 touch_position=Vector2(-1000,-1000)
 queue_redraw()

func _input(event:InputEvent) -> void:
 if event is InputEventScreenTouch and event.index==0:
  if event.pressed: _press(event.position)
  else: _release(event.position)
  get_viewport().set_input_as_handled()
 elif not OS.has_feature("mobile") and event is InputEventMouseButton and event.button_index==MOUSE_BUTTON_LEFT:
  if event.pressed: _press(event.position)
  else: _release(event.position)
 elif event is InputEventKey and event.pressed and not event.echo:
  match event.keycode:
   KEY_ESCAPE: screen="home"
   KEY_ENTER,KEY_1: _launch(0,"classic")
   KEY_2: _launch(1,"blockfall")

func _notification(what:int) -> void:
 if what==NOTIFICATION_WM_GO_BACK_REQUEST:
  if screen!="home":
   screen="home"
   queue_redraw()
  else:get_tree().quit()
