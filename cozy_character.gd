extends Node3D
const BlenderModels = preload("res://blender_models.gd")
# Original stylized, textured characters. The mesh is shared across all villagers.
static var ball: SphereMesh
static var textures: Dictionary = {}
static var quality_level := 2
static var foot_mesh: PlaneMesh
static var foot_material: ShaderMaterial
var foot_shadow: MeshInstance3D
var body: Node3D
var scarf_tail: MeshInstance3D
var legs: Array[Node3D] = []
var arms: Array[Node3D] = []
var walk_time := 0.0
var ground_offset := 0.0
var eyes: Array[MeshInstance3D] = []
var eye_scales: Array[Vector3] = []
var autonomous_idle := false
var idle_time := 0.0
var movement_weight := 0.0

static func finish_material(tint: Color, cloth: bool, hair := false) -> StandardMaterial3D:
	var key := tint.to_html() + str(cloth) + str(hair)
	if not textures.has(key):
		var size := 128 if cloth or hair else 64
		var img := Image.create(size,size,false,Image.FORMAT_RGBA8)
		var normal := Image.create(size,size,false,Image.FORMAT_RGBA8)
		for y in size:
			for x in size:
				var u := float(x)/float(size)
				var v := float(y)/float(size)
				var grain := sin(float(x)*2.17+float(y)*1.39)*cos(float(y)*2.41-float(x)*0.87)
				var amount := grain*0.008
				var nx := 0.0
				var ny := 0.0
				if cloth:
					var wx := sin(u*TAU*24.0)
					var wy := sin(v*TAU*24.0)
					var weave := wx*wy*0.020
					var seam := 1.0-smoothstep(0.009,0.026,absf(u-0.5))
					var stitches := smoothstep(0.2,0.65,sin(v*TAU*18.0))
					amount += weave + 0.035*sin(v*TAU)*sin(u*TAU*2.0) - seam*0.035 + seam*stitches*0.045
					nx = cos(u*TAU*24.0)*wy*0.13
					ny = cos(v*TAU*24.0)*wx*0.13
				elif hair:
					var strands := u*TAU*16.0 + sin(v*TAU)*0.65
					amount += sin(strands)*0.035 + sin(strands*2.0)*0.012
					nx = cos(strands)*0.18
				img.set_pixel(x,y,tint.lightened(amount) if amount>=0.0 else tint.darkened(-amount))
				var n := Vector3(nx,ny,1.0).normalized()
				normal.set_pixel(x,y,Color(n.x*0.5+0.5,n.y*0.5+0.5,n.z*0.5+0.5))
		img.generate_mipmaps()
		normal.generate_mipmaps()
		var mat := StandardMaterial3D.new()
		mat.albedo_texture = ImageTexture.create_from_image(img)
		mat.roughness = 0.88 if cloth else (0.62 if hair else 0.93)
		mat.metallic_specular = 0.10 if hair else 0.05
		if cloth or hair:
			mat.normal_texture = ImageTexture.create_from_image(normal)
			mat.normal_scale = 0.35
			mat.normal_enabled = quality_level>=2
		mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC if quality_level>=2 else BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
		textures[key] = mat
	return textures[key]

func shape(parent: Node3D, label: String, pos: Vector3, size: Vector3, tint: Color, cloth := false, shadow := false) -> MeshInstance3D:
	if ball == null:
		ball = SphereMesh.new()
		ball.radius = 0.5
		ball.height = 1.0
		ball.radial_segments = [8,12,16,24][quality_level]
		ball.rings = [4,6,8,12][quality_level]
	var part := MeshInstance3D.new()
	part.name = label
	var imported := BlenderModels.character_mesh(label)
	part.mesh = imported if imported != null else ball
	var is_hair := label in ["Hair cap","Back hair","Side lock","Fringe","Bun"]
	part.material_override = finish_material(tint,cloth,is_hair)
	part.position = pos
	part.scale = size
	if not shadow:
		part.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(part)
	return part

const HAIR_COLORS := ["674637","ad804d","393236","ad624c","d9b875","ac768d","77729a","b5aaa1"]
const CLOTH_COLORS := ["517b91","6e8964","91596b","b29554","49778c","b46454","c4a4c9","e7d5b1"]
const SKINS := ["f2c39b","fae1c8","dba071","b87a52","81513c","54392f"]
const IRIS := ["403432","775039","56796a","506f8a","56515f"]

const HAIRSTYLES := ["Curto repicado","Bob ondulado","Coque alto","Longo ondulado","Tranças","Cacheado"]
const OUTFITS := ["Camiseta","Jardineira","Cachecol","Jaqueta","Vestido","Esportivo","Uniforme"]
const HAIR_NAMES := ["Castanho","Mel","Preto","Cobre","Loiro","Rosa","Lavanda","Cinza"]
const CLOTH_NAMES := ["Azul","Verde","Vinho","Mostarda","Lago","Terracota","Lilás","Creme"]

func asset_mesh(part: MeshInstance3D, id: String) -> bool:
	var data := BlenderModels.parts(id)
	if data.is_empty(): return false
	part.mesh = data[0][0] as Mesh
	return true

func configure_player(look: Array,profile: Dictionary,offset: float) -> void:
	configure(Color(HAIR_COLORS[clampi(int(look[1]),0,HAIR_COLORS.size()-1)]),Color(CLOTH_COLORS[clampi(int(look[3]),0,CLOTH_COLORS.size()-1)]),Color(SKINS[clampi(int(profile.get("skin",0)),0,SKINS.size()-1)]),clampi(int(look[0]),0,HAIRSTYLES.size()-1),clampi(int(look[2]),0,OUTFITS.size()-1),offset,clampi(int(profile.get("eye_shape",0)),0,2),Color(IRIS[clampi(int(profile.get("eye_color",0)),0,IRIS.size()-1)]))

func configure(hair: Color, shirt: Color, skin: Color, hairstyle: int, outfit: int, offset: float,eye_shape:=0,iris:=Color("3a3030")) -> void:
	if is_instance_valid(body) and body.get_parent() == self:
		remove_child(body)
		body.queue_free()
	body = Node3D.new()
	legs.clear()
	arms.clear()
	eyes.clear()
	eye_scales.clear()
	scarf_tail=null
	ground_offset = offset
	body.position.y = offset
	add_child(body)
	setup_foot_shadow(offset)
	var pants := Color("566875") if outfit==1 else Color("626d58")
	var shoes := Color("705346")
	var vivid := Color.from_hsv(shirt.h,clampf(shirt.s*1.17,0.0,0.93),shirt.v,shirt.a)
	var cloth := vivid if outfit!=2 else vivid.lightened(0.08)
	var torso:=shape(body,"Torso",Vector3(0,0.78,0),Vector3(0.60,0.62,0.42),cloth,true,true)
	if outfit>=3:
		asset_mesh(torso,"character_garment_"+("jacket" if outfit==3 else ("dress" if outfit==4 else "shirt")))
	if outfit==4 or outfit==6:
		var skirt:=shape(body,"Skirt",Vector3(0,0.51,0),Vector3(0.72,0.37,0.50),cloth.darkened(.18),true,true)
		asset_mesh(skirt,"character_garment_skirt")
	if outfit==3 or outfit==6:
		for side in [-1,1]:
			shape(body,"Lapel",Vector3(side*.11,.94,.205),Vector3(.12,.24,.045),cloth.lightened(.27),true).rotation.z=side*.28
		for j in 3:
			shape(body,"Button",Vector3(0,.87-j*.10,.221),Vector3(.041,.041,.025),Color("e4cb98"))
	if outfit==5:
		for side in [-1,1]:
			shape(body,"Sport stripe",Vector3(side*.20,.79,.195),Vector3(.045,.38,.034),Color("eee7d4"),true)
	if outfit==0:
		shape(body,"Pocket",Vector3(-0.104,0.84,0.176),Vector3(0.16,0.14,0.044),cloth.lightened(0.13),true)
	if outfit==1:
		for side in [-1,1]:
			var strap:=shape(body,"Strap",Vector3(side*0.126,0.969,0.147),Vector3(0.067,0.183,0.046),pants,true)
			strap.rotation.z=side*-0.25
	shape(body,"Collar",Vector3(0,1.04,0.11),Vector3(0.30,0.10,0.26),cloth.lightened(0.25),true)
	for side in [-1,1]:
		var leg := Node3D.new()
		leg.position = Vector3(side*0.145,0.55,0)
		body.add_child(leg)
		legs.append(leg)
		if outfit in [4,5,6]:
			shape(leg,"Lower leg",Vector3(0,-.24,0),Vector3(.17,.42,.18),skin)
			if outfit==5:
				var shorts:=shape(leg,"Shorts",Vector3(0,-.065,0),Vector3(.29,.24,.30),cloth.darkened(.28),true,true)
				asset_mesh(shorts,"character_garment_shorts")
			shape(leg,"Sock",Vector3(0,-.37,0),Vector3(.19,.13,.19),Color("f3ebd8"),true)
		else:
			shape(leg,"Trouser",Vector3(0,-0.20,0),Vector3(0.25,0.45,0.26),pants,true,true)
		var shoe:=shape(leg,"Shoe",Vector3(0,-0.46,0.075),Vector3(0.29,0.17,0.38),cloth.darkened(.30) if outfit==5 else shoes)
		if outfit==3:
			asset_mesh(shoe,"character_garment_boots")
		shape(leg,"Sole",Vector3(0,-.515,.075),Vector3(.29,.055,.37),Color("e9dfce"))
		var arm := Node3D.new()
		arm.position = Vector3(side*0.34,0.94,0)
		body.add_child(arm)
		arms.append(arm)
		arm.rotation.z = side*0.16
		var sleeve:=shape(arm,"Sleeve",Vector3(0,-0.10,0),Vector3(0.25,0.24 if outfit in [4,5,6] else 0.34,0.25),cloth,true)
		asset_mesh(sleeve,"character_garment_sleeve")
		shape(arm,"Hand",Vector3(0,-0.31,0.02),Vector3(0.19,0.25,0.20),skin)
	shape(body,"Neck",Vector3(0,1.08,0),Vector3(0.24,0.23,0.25),skin)
	shape(body,"Head",Vector3(0,1.37,0),Vector3(0.80,0.76,0.69),skin,false,true)
	var hair_model:=shape(body,"Hair cap",Vector3(0,1.37,0),Vector3.ONE,hair,false,true)
	var sculpted:=asset_mesh(hair_model,"character_style_"+str(clampi(hairstyle,0,5)))
	if not sculpted:
		hair_model.position=Vector3(0,1.55,-.095)
		hair_model.scale=Vector3(.79,.51,.72)
		shape(body,"Back hair",Vector3(0,1.37,-0.23),Vector3(0.73,0.63,0.42),hair)
	for side in [-1,1]:
		shape(body,"Ear",Vector3(side*0.365,1.37,0),Vector3(0.16,0.22,0.17),skin)
		var white:=shape(body,"Eye white",Vector3(side*.149,1.43,.318),[Vector3(.155,.183,.042),Vector3(.17,.16,.043),Vector3(.17,.105,.041)][eye_shape],Color("fff6e5"))
		var eye := shape(body,"Eye",Vector3(side*0.149-.013,1.43,0.343),[Vector3(.099,.145,.032),Vector3(.111,.12,.032),Vector3(.112,.081,.031)][eye_shape],iris)
		var glint := shape(body,"Eye highlight",Vector3(side*0.149-0.035,1.43+[.031,.023,.013][eye_shape],0.363),Vector3(0.026,0.028,0.012),Color("fff5e4"))
		for part in [white,eye,glint]:
			eyes.append(part)
			eye_scales.append(part.scale)
		var brow := shape(body,"Brow",Vector3(side*0.135,1.535,0.300),Vector3(0.092,0.024,0.018),hair.darkened(0.10))
		brow.rotation.z=side*0.10
		shape(body,"Cheek",Vector3(side*0.218,1.32,0.283),Vector3(0.117,0.052,0.024),skin.lerp(Color("db8d83"),0.50))
	shape(body,"Nose",Vector3(0,1.35,0.335),Vector3(0.105,0.086,0.105),skin.lightened(0.10))
	shape(body,"Smile",Vector3(0,1.26,0.311),Vector3(0.090,0.025,0.019),Color("995e52"))
	if not sculpted:
		match hairstyle:
			1:
				for side in [-1,1]:
					shape(body,"Side lock",Vector3(side*0.30,1.47,0.15),Vector3(0.23,0.45,0.31),hair)
				shape(body,"Fringe",Vector3(-0.12,1.61,0.24),Vector3(0.48,0.24,0.27),hair.lightened(0.06)).rotation.z = 0.25
			2:
				shape(body,"Bun",Vector3(0,1.77,-0.18),Vector3(0.38,0.34,0.36),hair)
				shape(body,"Fringe",Vector3(0.14,1.60,0.24),Vector3(0.44,0.23,0.25),hair).rotation.z = -0.22
			_:
				for j in 3:
					shape(body,"Fringe",Vector3((j-1)*0.20,1.59+0.025*j,0.24),Vector3(0.29,0.26,0.27),hair.lightened(0.025*j))
	if outfit==1:
		shape(body,"Overall bib",Vector3(0,0.81,0.18),Vector3(0.37,0.39,0.06),pants,true)
	elif outfit==2:
		shape(body,"Scarf",Vector3(0,1.04,0.17),Vector3(0.43,0.15,0.16),Color("e5bb77"),true)
		scarf_tail=shape(body,"Scarf tail",Vector3(0.12,0.91,0.20),Vector3(0.14,0.25,0.055),Color("e5bb77"),true)

func _process(delta: float) -> void:
	if autonomous_idle and is_visible_in_tree(): pose(Vector2.ZERO,delta)

func pose(direction: Vector2, delta: float, running := false) -> void:
	var moving := direction.length_squared()>0.01
	if moving:
		rotation.y = lerp_angle(rotation.y,atan2(direction.x,direction.y),minf(delta*13.0,1.0))
		walk_time += delta*(15.5 if running else 10.5)
	idle_time += delta
	movement_weight=move_toward(movement_weight,1.0 if moving else 0.0,delta*5.5)
	var swing := sin(walk_time)*(0.78 if running else 0.55)*movement_weight
	var blink_phase := fposmod(idle_time+float(get_instance_id()%17)*0.23,4.8)
	var blink := 1.0-0.92*maxf(0.0,1.0-absf(blink_phase-4.55)/0.105)
	for i in eyes.size():
		eyes[i].scale=Vector3(eye_scales[i].x,eye_scales[i].y*blink,eye_scales[i].z)
		if i%3==2: eyes[i].visible=blink>0.35
	for i in legs.size():
		var side := 1.0 if i==0 else -1.0
		legs[i].rotation.x = lerpf(legs[i].rotation.x,swing*side,minf(delta*16.0,1.0))
		arms[i].rotation.x = lerpf(arms[i].rotation.x,-swing*side*0.72,minf(delta*16.0,1.0))
	body.position.y = ground_offset + absf(sin(walk_time))*(0.065 if running else 0.042)*movement_weight
	body.rotation.z=sin(walk_time)*0.043*movement_weight
	body.rotation.y=sin(walk_time)*0.07*movement_weight + sin(idle_time*1.03)*0.025*(1.0-movement_weight)
	if is_instance_valid(scarf_tail):
		scarf_tail.rotation.z=0.1+0.12*sin(walk_time-0.6)*movement_weight+0.035*sin(idle_time*2.1)
	body.scale.y=1.0+sin(idle_time*2.4)*0.006*(1.0-movement_weight)

static func set_quality(level: int) -> void:
	quality_level = clampi(level,0,3)
	if foot_material != null: foot_material.set_shader_parameter("strength",0.0 if quality_level==0 else (0.20 if quality_level==1 else 0.33))
	if ball != null:
		ball.radial_segments = [8,12,16,24][quality_level]
		ball.rings = [4,6,8,12][quality_level]
	for key in textures:
		var mat: StandardMaterial3D = textures[key]
		mat.normal_enabled = mat.normal_texture != null and quality_level>=2
		mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC if quality_level>=2 else BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS

func setup_foot_shadow(offset: float) -> void:
	if foot_mesh == null:
		foot_mesh = PlaneMesh.new()
		foot_mesh.size=Vector2(0.94,0.69)
	if foot_material == null:
		var shader := Shader.new()
		shader.code = """
shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, shadows_disabled;
uniform float strength = 0.33;
void fragment() {
	float r=length((UV-0.5)*2.0);
	ALBEDO=vec3(0.09,0.12,0.09);
	ALPHA=(1.0-smoothstep(0.12,1.0,r))*strength;
}
"""
		foot_material=ShaderMaterial.new()
		foot_material.shader=shader
	if not is_instance_valid(foot_shadow):
		foot_shadow=MeshInstance3D.new()
		foot_shadow.mesh=foot_mesh
		foot_shadow.material_override=foot_material
		foot_shadow.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(foot_shadow)
	foot_shadow.position.y=offset+0.075

var hand_prop: Node3D
func use_tool(model: Node3D) -> void:
	if is_instance_valid(hand_prop): hand_prop.queue_free()
	hand_prop=model
	arms[1].add_child(model)
	model.position=Vector3(0,-0.3,0.12)
	model.scale=Vector3.ONE*0.72
	model.rotation.x=-1.6
	var motion:=model.create_tween()
	motion.tween_property(model,"rotation:x",0.6,0.18).set_trans(Tween.TRANS_SINE)
	motion.tween_property(model,"rotation:x",-0.8,0.17)
	motion.tween_callback(model.queue_free)
