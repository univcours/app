extends Node
## Real 3D candy renderer for Godot 4.5.1.
##
## Small, shared orthographic SubViewports bake seven detailed 3D toys to
## ViewportTextures, then the puzzle / Blockfall render them with ONE 2D draw
## per cell. This protects Android fill rate instead of running a 3D world
## for every cube of the 9x9/10x18 boards.
##
## Actual meshes, physically-based StandardMaterial3D with clearcoat, two
## lights, highlights, candy stripe/sugar toppings, and per-shape geometry.
## No remote textures, copyrighted Candy Crush assets or external addons.
const SIZE := 128
var rendered_textures: Array[Texture2D] = []
var render_viewports: Array[SubViewport] = []
var body_mesh: ArrayMesh

func _ready() -> void:
 body_mesh=_rounded_mesh(10)

func build_candies(palette:Array) -> void:
 for viewport in render_viewports:
  if is_instance_valid(viewport):
   viewport.queue_free()
 rendered_textures.clear()
 render_viewports.clear()
 for idx in palette.size():
  var tint:Color=palette[idx]
  var viewport:=SubViewport.new()
  viewport.name="Candy3D_%02d"%idx
  viewport.size=Vector2i(SIZE,SIZE)
  viewport.transparent_bg=true
  viewport.disable_3d=false
  # CRITICAL: independent studios. Without this all seven sweets and lights
  # overlap in one World3D, washing every distinct candy out to white.
  viewport.own_world_3d=true
  viewport.msaa_3d=Viewport.MSAA_2X
  viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS
  add_child(viewport)
  var world:=Node3D.new()
  world.name="SweetStudio"
  viewport.add_child(world)
  var camera:=Camera3D.new()
  camera.name="CandyCamera"
  camera.projection=Camera3D.PROJECTION_ORTHOGONAL
  camera.size=1.90
  camera.position=Vector3(0,0,4.4)
  world.add_child(camera)
  camera.look_at(Vector3.ZERO,Vector3.UP)
  camera.current=true

  var keylight:=DirectionalLight3D.new()
  keylight.name="SoftboxKey"
  keylight.rotation_degrees=Vector3(-37,-29,19)
  keylight.light_color=Color("#fff0dd")
  keylight.light_energy=2.35
  keylight.shadow_enabled=false
  world.add_child(keylight)
  var fill:=DirectionalLight3D.new()
  fill.name="CandyRimLight"
  fill.rotation_degrees=Vector3(22,135,-20)
  fill.light_color=Color("#b2deff")
  fill.light_energy=1.50
  fill.shadow_enabled=false
  world.add_child(fill)
  _make_candy(world,idx,tint)
  viewport.render_target_update_mode=SubViewport.UPDATE_ONCE
  render_viewports.append(viewport)
  rendered_textures.append(viewport.get_texture())

func get_candy_texture(index:int) -> Texture2D:
 if index<0 or index>=rendered_textures.size():
  return null
 return rendered_textures[index]

func candy_count() -> int:
 return rendered_textures.size()

func _coating(base:Color,bright:bool=false) -> StandardMaterial3D:
 var mat:=StandardMaterial3D.new()
 mat.albedo_color=base
 mat.metallic=.10 if not bright else .04
 mat.roughness=.13 if not bright else .07
 mat.clearcoat_enabled=true
 mat.clearcoat=.97
 mat.clearcoat_roughness=.06
 mat.rim_enabled=true
 mat.rim=.32
 mat.rim_tint=.33
 mat.emission_enabled=true
 mat.emission=base.lightened(.30)
 mat.emission_energy_multiplier=.11 if not bright else .26
 return mat

func _add_mesh(parent:Node3D,name:String,mesh:Mesh,mat:Material,
 position:Vector3=Vector3.ZERO,scale:Vector3=Vector3.ONE,
 rotation:Vector3=Vector3.ZERO) -> MeshInstance3D:
 var item:=MeshInstance3D.new()
 item.name=name
 item.mesh=mesh
 item.material_override=mat
 item.position=position
 item.scale=scale
 item.rotation=rotation
 item.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
 parent.add_child(item)
 return item

func _make_candy(parent:Node3D,index:int,base:Color) -> void:
 var kind:int=posmod(index-1,7)
 var material:StandardMaterial3D=_coating(base)
 var round_body:=SphereMesh.new()
 round_body.radius=.72
 round_body.height=1.44
 round_body.radial_segments=40
 round_body.rings=20
 var jelly_mesh:Mesh=body_mesh
 var scaling:=Vector3(.98,.98,1.0)
 var tilt:=Vector3(-.11,.14,-.08)
 match kind:
  0: # Ruby cherry candy: inflated heart-like round jelly.
   jelly_mesh=round_body
   scaling=Vector3(.97,.99,.55)
  1: # Golden caramel: super-rounded square toffee.
   scaling=Vector3(.96,.95,1.05)
   tilt=Vector3(-.08,.17,.11)
  2: # Bubblegum blue jelly bonbon.
   jelly_mesh=round_body
   scaling=Vector3(1.02,.94,.57)
  3: # Amethyst faceted plum candy.
   scaling=Vector3(.87,1.02,1.13)
   tilt=Vector3(-.10,.18,.58)
  4: # Emerald gummy tablet.
   scaling=Vector3(.99,.90,1.0)
   tilt=Vector3(-.08,-.18,-.08)
  5: # Orange citrus pillow.
   scaling=Vector3(1.06,.89,1.0)
   tilt=Vector3(-.12,.19,.19)
  6: # Sapphire lozenge.
   jelly_mesh=round_body
   scaling=Vector3(1.02,.96,.56)
 _add_mesh(parent,"Real3D_Candy_Body",jelly_mesh,material,Vector3.ZERO,scaling,tilt)

 # Raised confectionery stripes, sugar sprinkles and sweet emblems.
 var icing:StandardMaterial3D=_coating(Color("#fff3f7"),true)
 var glow:StandardMaterial3D=_coating(base.lightened(.55),true)
 var mint:StandardMaterial3D=_coating(Color("#fff8d3"),true)
 var tiny:=SphereMesh.new()
 tiny.radius=.10
 tiny.height=.20
 tiny.radial_segments=20
 tiny.rings=10
 var marker:Vector3=Vector3(-.18,.21,.42 if jelly_mesh==body_mesh else .39)
 _add_mesh(parent,"SweetGlossReflection",tiny,icing,marker,
  Vector3(1.55,.44,.18),Vector3(0,0,.30))
 _add_mesh(parent,"SweetSecondGlint",tiny,glow,Vector3(.34,-.28,.38),
  Vector3(.60,.19,.18),Vector3(0,0,-.45))

 if kind==1 or kind==5:
  var stripe:=BoxMesh.new()
  stripe.size=Vector3(.10,1.00,.035)
  for i in 2:
   var x:float=-.26+float(i)*.52
   _add_mesh(parent,"SugarStripe%d"%i,stripe,icing,
    Vector3(x,0,.39),Vector3.ONE,Vector3(0,0,-.25))
 elif kind==2 or kind==6:
  var swirl:=TorusMesh.new()
  swirl.inner_radius=.37
  swirl.outer_radius=.43
  swirl.rings=32
  swirl.ring_segments=20
  _add_mesh(parent,"SpunSugarRing",swirl,mint,Vector3(0,.02,.41),
   Vector3(.87,.87,.33),Vector3(PI*.5,0,0))
 elif kind==3:
  for i in 5:
   var px:float=cos(float(i)*TAU/5.0)*.28
   var py:float=sin(float(i)*TAU/5.0)*.28
   _add_mesh(parent,"SugarCrystal%d"%i,tiny,icing,Vector3(px,py,.40),
    Vector3(.48,.48,.23))
 elif kind==4:
  var dots:StandardMaterial3D=_coating(Color("#b8ff69"),true)
  for i in 3:
   _add_mesh(parent,"LimeDot%d"%i,tiny,dots,
    Vector3(-.23+float(i)*.23,-.23+float(i%2)*.18,.39),
    Vector3(.50,.50,.22))

func _rounded_mesh(segments:int) -> ArrayMesh:
 # Smooth-sided physically-3D rounded cube, not a flat sprite. Every face
 # is subdivided and projected onto a sphere around the inner cuboid.
 var mesh:=ArrayMesh.new()
 var vertices:=PackedVector3Array()
 var normals:=PackedVector3Array()
 var uv:=PackedVector2Array()
 var indices:=PackedInt32Array()
 var half:=Vector3(.64,.64,.25)
 var radius:=.24
 var faces=[
  [Vector3(0,0,1),Vector3(1,0,0),Vector3(0,1,0),half.z,half.x,half.y],
  [Vector3(0,0,-1),Vector3(0,1,0),Vector3(1,0,0),half.z,half.y,half.x],
  [Vector3(1,0,0),Vector3(0,1,0),Vector3(0,0,1),half.x,half.y,half.z],
  [Vector3(-1,0,0),Vector3(0,0,1),Vector3(0,1,0),half.x,half.z,half.y],
  [Vector3(0,1,0),Vector3(0,0,1),Vector3(1,0,0),half.y,half.z,half.x],
  [Vector3(0,-1,0),Vector3(1,0,0),Vector3(0,0,1),half.y,half.x,half.z]
 ]
 for face in faces:
  var outward:Vector3=face[0]
  var horizontal:Vector3=face[1]
  var vertical:Vector3=face[2]
  var normal_extent:float=float(face[3])
  var u_extent:float=float(face[4])
  var v_extent:float=float(face[5])
  var base_index:int=vertices.size()
  for y in range(segments+1):
   for x in range(segments+1):
    var u:float=float(x)/float(segments)
    var v:float=float(y)/float(segments)
    var raw:Vector3=outward*normal_extent+horizontal*(2.0*u-1.0)*u_extent+vertical*(2.0*v-1.0)*v_extent
    var inside:Vector3=Vector3(
     clampf(raw.x,-half.x+radius,half.x-radius),
     clampf(raw.y,-half.y+radius,half.y-radius),
     clampf(raw.z,-half.z+radius,half.z-radius)
    )
    var normal:Vector3=(raw-inside).normalized()
    vertices.append(inside+normal*radius)
    normals.append(normal)
    uv.append(Vector2(u,v))
  for y in segments:
   for x in segments:
    var a:int=base_index+y*(segments+1)+x
    var b:int=a+1
    var c:int=a+segments+1
    var d:int=c+1
    indices.append_array(PackedInt32Array([a,b,d,a,d,c]))
 var arrays=[]
 arrays.resize(Mesh.ARRAY_MAX)
 arrays[Mesh.ARRAY_VERTEX]=vertices
 arrays[Mesh.ARRAY_NORMAL]=normals
 arrays[Mesh.ARRAY_TEX_UV]=uv
 arrays[Mesh.ARRAY_INDEX]=indices
 mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
 return mesh
