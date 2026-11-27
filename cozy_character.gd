extends Node3D
# Original stylized, textured characters. The mesh is shared across all villagers.
static var ball: SphereMesh
static var textures: Dictionary = {}
var body: Node3D
var legs: Array[Node3D] = []
var arms: Array[Node3D] = []
var walk_time := 0.0
var ground_offset := 0.0

static func finish_material(tint: Color, cloth: bool) -> StandardMaterial3D:
	var key := tint.to_html() + str(cloth)
	if not textures.has(key):
		var img := Image.create(64,64,false,Image.FORMAT_RGBA8)
		for y in 64:
			for x in 64:
				var grain := sin(float(x)*2.17+float(y)*1.39)*cos(float(y)*2.41-float(x)*0.87)
				var weave := 0.0
				if cloth:
					weave = (0.022 if x%4==0 else -0.008)+(0.018 if y%4==0 else -0.008)
				var amount := grain*0.012 + weave
				img.set_pixel(x,y,tint.lightened(amount) if amount>=0.0 else tint.darkened(-amount))
		img.generate_mipmaps()
		var mat := StandardMaterial3D.new()
		mat.albedo_texture = ImageTexture.create_from_image(img)
		mat.roughness = 0.92
		mat.metallic_specular = 0.05
		mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
		textures[key] = mat
	return textures[key]

func shape(parent: Node3D, label: String, pos: Vector3, size: Vector3, tint: Color, cloth := false, shadow := false) -> MeshInstance3D:
	if ball == null:
		ball = SphereMesh.new()
		ball.radius = 0.5
		ball.height = 1.0
		ball.radial_segments = 16
		ball.rings = 8
	var part := MeshInstance3D.new()
	part.name = label
	part.mesh = ball
	part.material_override = finish_material(tint,cloth)
	part.position = pos
	part.scale = size
	if not shadow:
		part.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(part)
	return part

func configure(hair: Color, shirt: Color, skin: Color, hairstyle: int, outfit: int, offset: float) -> void:
	if is_instance_valid(body) and body.get_parent() == self:
		remove_child(body)
		body.queue_free()
	body = Node3D.new()
	legs.clear()
	arms.clear()
	ground_offset = offset
	body.position.y = offset
	add_child(body)
	var pants := Color("566875") if outfit==1 else Color("626d58")
	var shoes := Color("705346")
	var cloth := shirt if outfit!=2 else shirt.lightened(0.12)
	shape(body,"Torso",Vector3(0,0.78,0),Vector3(0.57,0.62,0.38),cloth,true,true)
	shape(body,"Collar",Vector3(0,1.04,0.11),Vector3(0.30,0.10,0.26),cloth.lightened(0.25),true)
	for side in [-1,1]:
		var leg := Node3D.new()
		leg.position = Vector3(side*0.145,0.55,0)
		body.add_child(leg)
		legs.append(leg)
		shape(leg,"Trouser",Vector3(0,-0.20,0),Vector3(0.25,0.45,0.26),pants,true,true)
		shape(leg,"Shoe",Vector3(0,-0.46,0.075),Vector3(0.29,0.17,0.38),shoes)
		var arm := Node3D.new()
		arm.position = Vector3(side*0.34,0.94,0)
		body.add_child(arm)
		arms.append(arm)
		arm.rotation.z = side*0.16
		shape(arm,"Sleeve",Vector3(0,-0.13,0),Vector3(0.24,0.32,0.24),cloth,true)
		shape(arm,"Hand",Vector3(0,-0.31,0.02),Vector3(0.19,0.25,0.20),skin)
	shape(body,"Neck",Vector3(0,1.08,0),Vector3(0.24,0.23,0.25),skin)
	shape(body,"Head",Vector3(0,1.37,0),Vector3(0.76,0.76,0.66),skin,false,true)
	shape(body,"Hair cap",Vector3(0,1.55,-0.095),Vector3(0.79,0.51,0.72),hair,false,true)
	shape(body,"Back hair",Vector3(0,1.37,-0.23),Vector3(0.73,0.63,0.42),hair)
	for side in [-1,1]:
		shape(body,"Ear",Vector3(side*0.365,1.37,0),Vector3(0.16,0.22,0.17),skin)
		shape(body,"Eye",Vector3(side*0.135,1.43,0.306),Vector3(0.070,0.115,0.043),Color("3a3030"))
		shape(body,"Eye highlight",Vector3(side*0.135-0.012,1.456,0.329),Vector3(0.024,0.026,0.012),Color("fff5e4"))
		shape(body,"Cheek",Vector3(side*0.218,1.32,0.283),Vector3(0.117,0.052,0.024),skin.lerp(Color("db8d83"),0.50))
	shape(body,"Nose",Vector3(0,1.35,0.335),Vector3(0.105,0.086,0.105),skin.lightened(0.10))
	shape(body,"Smile",Vector3(0,1.26,0.311),Vector3(0.090,0.025,0.019),Color("995e52"))
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
		shape(body,"Scarf tail",Vector3(0.12,0.91,0.20),Vector3(0.14,0.25,0.055),Color("e5bb77"),true)

func pose(direction: Vector2, delta: float) -> void:
	var moving := direction.length_squared()>0.01
	if moving:
		rotation.y = lerp_angle(rotation.y,atan2(direction.x,direction.y),minf(delta*13.0,1.0))
		walk_time += delta*10.5
	var swing := sin(walk_time)*0.55 if moving else 0.0
	for i in legs.size():
		var side := 1.0 if i==0 else -1.0
		legs[i].rotation.x = lerpf(legs[i].rotation.x,swing*side,minf(delta*16.0,1.0))
		arms[i].rotation.x = lerpf(arms[i].rotation.x,-swing*side*0.72,minf(delta*16.0,1.0))
	body.position.y = ground_offset + (absf(sin(walk_time))*0.035 if moving else 0.0)
