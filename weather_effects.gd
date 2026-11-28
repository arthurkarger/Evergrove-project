extends Node3D

const STREAMS := {
	"sun":preload("res://assets/weather/sun.ogg"),
	"wind":preload("res://assets/weather/wind.ogg"),
	"rain":preload("res://assets/weather/rain.ogg")}
var loops: Dictionary={}
var thunder:=AudioStreamPlayer.new()
var lightning:=DirectionalLight3D.new()
var drops: GPUParticles3D
var splashes: GPUParticles3D
var leaves: GPUParticles3D
var streaks: GPUParticles3D
var butterflies: GPUParticles3D
var clouds:=MeshInstance3D.new()
var fish:=Node3D.new()
var fish_clock:=0.
var fish_wait:=2.
var strike_wait:=8.
var rumble_delay:=-1.
var flash:=0.
var rng:=RandomNumberGenerator.new()
var quality:=-1
var outside:=false

func pigment(tint: Color) -> StandardMaterial3D:
	var mat:=StandardMaterial3D.new()
	mat.albedo_color=tint
	mat.roughness=.9
	if tint.a<1:
		mat.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
	return mat

func box(size: Vector3,tint: Color) -> Mesh:
	var mesh:=BoxMesh.new()
	mesh.size=size
	mesh.material=pigment(tint)
	return mesh

func emitter(mesh: Mesh,extent: Vector3,height: float,velocity: Vector3,seconds: float) -> GPUParticles3D:
	var node:=GPUParticles3D.new()
	node.emitting=false
	node.lifetime=seconds
	node.fixed_fps=24
	node.local_coords=false
	node.visibility_aabb=AABB(Vector3(-17,-8,-17),Vector3(34,23,34))
	node.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	node.draw_pass_1=mesh
	var motion:=ParticleProcessMaterial.new()
	motion.emission_shape=ParticleProcessMaterial.EMISSION_SHAPE_BOX
	motion.emission_box_extents=extent
	motion.direction=velocity.normalized()
	motion.spread=4
	motion.gravity=Vector3.ZERO
	motion.initial_velocity_min=velocity.length()*.94
	motion.initial_velocity_max=velocity.length()*1.06
	motion.scale_min=.72
	motion.scale_max=1.18
	node.process_material=motion
	add_child(node)
	node.position.y=height
	return node

func _ready() -> void:
	rng.randomize()
	drops=emitter(box(Vector3(.017,.38,.017),Color(.71,.85,.93,.48)),Vector3(10,.25,9),6,Vector3(-1,-12,.35),.51)
	var ring:=TorusMesh.new()
	ring.inner_radius=.073
	ring.outer_radius=.098
	ring.rings=10
	ring.ring_segments=3
	ring.material=pigment(Color(.70,.86,.90,.55))
	splashes=emitter(ring,Vector3(9,.006,8),.085,Vector3.UP*.06,.32)
	leaves=emitter(box(Vector3(.115,.012,.057),Color("c4a359")),Vector3(7,1.1,8),1.45,Vector3(3,-.34,.6),2.1)
	var leaf_motion:=leaves.process_material as ParticleProcessMaterial
	leaf_motion.angular_velocity_min=-120
	leaf_motion.angular_velocity_max=115
	streaks=emitter(box(Vector3(.55,.012,.016),Color(.88,.94,.85,.37)),Vector3(9,.9,8),1.6,Vector3(5,.12,.85),1.)
	var wings:=PlaneMesh.new()
	wings.size=Vector2(.26,.16)
	wings.subdivide_width=1
	var flutter:=Shader.new()
	flutter.code="""shader_type spatial;
render_mode cull_disabled;
void vertex(){ VERTEX.y+=abs(VERTEX.x)*(.45+.8*sin(TIME*20.+MODEL_MATRIX[3].x)); VERTEX.z+=.12*sin(TIME*4.+MODEL_MATRIX[3].z); }
void fragment(){vec2 u=UV-.5; if(length(vec2((abs(u.x)-.24)*3.8,u.y*2.1))>1.) discard; ALBEDO=mix(vec3(.96,.72,.23),vec3(.36,.19,.09),smoothstep(.29,.47,abs(u.x)));}"""
	var wing_mat:=ShaderMaterial.new()
	wing_mat.shader=flutter
	wings.material=wing_mat
	butterflies=emitter(wings,Vector3(5,.35,5),1.05,Vector3(.45,.04,.25),3.1)
	make_clouds()
	var shape:=SphereMesh.new()
	shape.radial_segments=8
	shape.rings=4
	shape.radius=.5
	shape.height=1.
	shape.material=pigment(Color("507e80"))
	for tail in [false,true]:
		var part:=MeshInstance3D.new()
		part.mesh=shape
		part.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		part.scale=Vector3(.19,.065,.38) if not tail else Vector3(.15,.03,.11)
		part.position.z=-.20 if tail else 0.
		fish.add_child(part)
	add_child(fish)
	fish.top_level=true
	fish.hide()
	add_child(lightning)
	lightning.rotation_degrees=Vector3(-65,35,0)
	lightning.light_color=Color("d5e4ff")
	lightning.light_energy=0
	lightning.shadow_enabled=false
	lightning.sky_mode=DirectionalLight3D.SKY_MODE_LIGHT_ONLY
	lightning.hide()
	for id in STREAMS:
		var player:=AudioStreamPlayer.new()
		player.stream=STREAMS[id]
		(player.stream as AudioStreamOggVorbis).loop=true
		add_child(player)
		loops[id]=player
	thunder.stream=preload("res://assets/weather/thunder.ogg")
	thunder.volume_db=-12
	add_child(thunder)
	hide()

func make_clouds() -> void:
	var plane:=PlaneMesh.new()
	plane.size=Vector2(245,205)
	var shader:=Shader.new()
	shader.code="""shader_type spatial;
render_mode unshaded,cull_disabled,depth_draw_never,fog_disabled;
uniform float cover=0.;
uniform vec4 tint:source_color=vec4(.65,.72,.77,1.);
float hash(vec2 p){return fract(sin(dot(p,vec2(27.1,93.4)))*4137.54);}
float noise2(vec2 p){vec2 i=floor(p),f=fract(p); f=f*f*(3.-2.*f);return mix(mix(hash(i),hash(i+vec2(1,0)),f.x),mix(hash(i+vec2(0,1)),hash(i+1.),f.x),f.y);}
void fragment(){vec2 p=UV*15.+TIME*vec2(.013,.006);float n=noise2(p)*.62+noise2(p*2.1)*.26+noise2(p*5.)*.12; ALBEDO=tint.rgb*mix(.67,1.12,n); ALPHA=smoothstep(.51-.27*cover,.79-.20*cover,n)*cover;}"""
	var mat:=ShaderMaterial.new()
	mat.shader=shader
	clouds.mesh=plane
	clouds.material_override=mat
	clouds.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(clouds)
	clouds.position.y=36

func set_quality(level: int) -> void:
	if quality==level: return
	quality=level
	drops.amount=[70,120,200,310][level]
	splashes.amount=[6,12,22,34][level]
	streaks.amount=[3,5,9,14][level]
	leaves.amount=[4,8,13,19][level]
	butterflies.amount=[3,4,5,7][level]

func emit_fraction(node: GPUParticles3D,fraction: float) -> void:
	node.amount_ratio=clampf(fraction,0,1)
	node.emitting=fraction>.02

func set_outdoors(on: bool) -> void:
	if on==outside: return
	outside=on
	visible=on
	if not on:
		for node in [drops,splashes,leaves,streaks,butterflies]: node.emitting=false
		for player in loops.values(): player.stop()
		thunder.stop()
		rumble_delay=-1
		flash=0
		lightning.hide()
		fish.hide()

func mix_loop(id: String,gain: float) -> void:
	var player: AudioStreamPlayer=loops[id]
	if gain<.001:
		if player.playing: player.stop()
		return
	player.volume_db=linear_to_db(gain)
	if not player.playing and DisplayServer.get_name()!="headless": player.play()

func apply(weather,center: Vector3,daylight: float) -> void:
	if not outside: return
	position=Vector3(center.x,center.y-.51,center.z)
	var l: Vector3=weather.levels
	emit_fraction(drops,l.x)
	emit_fraction(splashes,l.x)
	emit_fraction(leaves,smoothstep(.2,.94,l.y))
	emit_fraction(streaks,smoothstep(.45,.96,l.y))
	emit_fraction(butterflies,daylight*(1.-l.x)*weather.spawn_multiplier(&"butterflies")*.40)
	var cloud_mat:=clouds.material_override as ShaderMaterial
	clouds.visible=l.z>.02
	cloud_mat.set_shader_parameter("cover",l.z)
	cloud_mat.set_shader_parameter("tint",Color("526079").lerp(Color("d5d9d4"),daylight*(1.-.67*l.z)))
	mix_loop("sun",(.03+.16*daylight)*(1.-l.z)*(1.-l.y))
	mix_loop("rain",.45*l.x)
	mix_loop("wind",.44*l.y)

func step(delta: float,weather,shore,center: Vector3) -> void:
	if not outside: return
	if weather.kind=="storm" and weather.levels.x>.70:
		strike_wait-=delta
		if strike_wait<=0:
			flash=.35
			rumble_delay=rng.randf_range(.45,1.6)
			strike_wait=rng.randf_range(9,19)
	if rumble_delay>=0:
		rumble_delay-=delta
		if rumble_delay<0 and DisplayServer.get_name()!="headless": thunder.play()
	flash=maxf(0,flash-delta)
	lightning.visible=flash>.001
	lightning.light_energy=1.9*smoothstep(0,.23,flash)
	fish_wait-=delta*weather.spawn_multiplier(&"fish")
	if fish.visible:
		fish_clock+=delta
		fish.translate_object_local(Vector3(0,0,delta*.30))
		fish.scale=Vector3.ONE*clampf(sin(PI*fish_clock/2.6)*4.,.01,1.)
		if fish_clock>=2.6 or shore.distance_at(Vector2(fish.position.x,fish.position.z))>-.35: fish.hide()
	if fish_wait<=0:
		fish_wait=rng.randf_range(4,8)
		for i in 6:
			var p:=Vector2(center.x,center.z)+Vector2(rng.randf_range(-7,7),rng.randf_range(-6,6))
			if shore.distance_at(p)>-.7: continue
			fish_clock=0
			fish.position=Vector3(p.x,shore.height_at(p)+.075,p.y)
			fish.rotation.y=rng.randf_range(-PI,PI)
			fish.scale=Vector3.ONE*.02
			fish.show()
			break
