extends Node3D
var player: CharacterBody3D
var camera: Camera3D
var sprite: Sprite3D
var touch := Vector2.ZERO
var elapsed := 0.0
var textures: Array[ImageTexture] = []
var rng := RandomNumberGenerator.new()
func block(pos: Vector3, size: Vector3, color: Color, solid := false):
	var root: Node3D
	if solid:
		root = StaticBody3D.new()
		var c := CollisionShape3D.new()
		var shape := BoxShape3D.new()
		shape.size = size
		c.shape = shape
		root.add_child(c)
	else:
		root = Node3D.new()
	add_child(root)
	root.position = pos
	var mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	mesh.mesh = box
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mesh.material_override = mat
	root.add_child(mesh)
	return root
func tree(x: float,z: float):
	block(Vector3(x,0.8,z),Vector3(0.5,1.6,0.5),Color("79523b"),true)
	for i in range(3):
		var s := 2.1-i*0.48
		block(Vector3(x,1.6+i*0.55,z),Vector3(s,0.75,s),Color(["426b43","54854a","72a358"][i]))
func house(x: float,z: float):
	block(Vector3(x,1.2,z),Vector3(4,2.4,3.4),Color("e6c69a"),true)
	for i in range(6):
		block(Vector3(x,2.45+i*0.20,z),Vector3(4.5-i*0.68,0.25,3.9),Color("a65343"))
	block(Vector3(x,0.65,z+1.72),Vector3(0.75,1.3,0.08),Color("674b3b"))
	for dx in [-1.25,1.25]:
		block(Vector3(x+dx,1.4,z+1.73),Vector3(0.65,0.65,0.08),Color("739ca4"))
func make_sprite(step: int) -> ImageTexture:
	var img := Image.create(16,24,false,Image.FORMAT_RGBA8)
	img.fill(Color.TRANSPARENT)
	img.fill_rect(Rect2i(4,2,8,8),Color("674637"))
	img.fill_rect(Rect2i(5,5,7,6),Color("f2c39b"))
	img.fill_rect(Rect2i(4,3,8,3),Color("80583d"))
	img.set_pixel(6,7,Color("302b31"))
	img.set_pixel(10,7,Color("302b31"))
	img.fill_rect(Rect2i(4,11,8,7),Color("517b91"))
	img.fill_rect(Rect2i(2,12,2,5),Color("f2c39b"))
	img.fill_rect(Rect2i(12,12,2,5),Color("f2c39b"))
	img.fill_rect(Rect2i(5,18,3,4-step),Color("394754"))
	img.fill_rect(Rect2i(9,18,3,3+step),Color("394754"))
	img.fill_rect(Rect2i(4,22-step,4,2),Color("49392e"))
	img.fill_rect(Rect2i(9,21+step,4,2),Color("49392e"))
	return ImageTexture.create_from_image(img)
func _ready():
	rng.seed = 1234
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color("b8d6dc")
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color("fff1db")
	e.ambient_light_energy = 0.7
	env.environment = e
	add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-55,-35,0)
	sun.shadow_enabled = true
	add_child(sun)
	block(Vector3(0,-0.3,0),Vector3(42,0.6,42),Color("83aa65"),true)
	for x in range(-20,21,2):
		for z in range(-20,21,2):
			if abs(x)<=2 or abs(z)<=2:
				block(Vector3(x,0.012,z),Vector3(2,0.024,2),Color("d8bd8b"))
			elif rng.randf()<0.22:
				block(Vector3(x,0.008,z),Vector3(1.8,0.016,1.8),Color("8bb16b"))
	for p in [Vector2(-7,-7),Vector2(7,-7),Vector2(-8,7)]:
		house(p.x,p.y)
	for i in range(-18,19,3):
		tree(i,-19)
		tree(i,19)
		tree(-19,i)
		tree(19,i)
	for p in [Vector2(-5,-13),Vector2(5,10),Vector2(12,5),Vector2(-13,-3),Vector2(13,-12)]:
		tree(p.x,p.y)
	block(Vector3(10,0.5,10),Vector3(6,1,5),Color("609da9"),true)
	for i in range(5):
		block(Vector3(-12+i*0.9,0.35,12),Vector3(0.65,0.7,0.8),Color("92958a"),true)
	player = CharacterBody3D.new()
	add_child(player)
	player.position = Vector3(0,0.5,4)
	var c := CollisionShape3D.new()
	var shape := CapsuleShape3D.new()
	shape.radius = 0.28
	shape.height = 1.0
	c.shape = shape
	player.add_child(c)
	sprite = Sprite3D.new()
	textures = [make_sprite(0),make_sprite(1)]
	sprite.texture = textures[0]
	sprite.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	sprite.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	sprite.pixel_size = 0.075
	sprite.position.y = 0.35
	player.add_child(sprite)
	camera = Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 13
	add_child(camera)
	camera.position = player.position + Vector3(0,10,10)
	camera.look_at(player.position)
	camera.current = true
	var ui := CanvasLayer.new()
	add_child(ui)
	var label := Label.new()
	label.text = "EVERGROVE   •   0.1.0"
	label.position = Vector2(18,14)
	ui.add_child(label)
	var pad := Control.new()
	pad.set_script(preload("res://pad.gd"))
	pad.set("world",self)
	ui.add_child(pad)
func _physics_process(delta):
	var d := Input.get_vector("ui_left","ui_right","ui_up","ui_down")
	if Input.is_physical_key_pressed(KEY_A): d.x -= 1
	if Input.is_physical_key_pressed(KEY_D): d.x += 1
	if Input.is_physical_key_pressed(KEY_W): d.y -= 1
	if Input.is_physical_key_pressed(KEY_S): d.y += 1
	d = (d+touch).limit_length()
	player.velocity = Vector3(d.x*4.0,-2,d.y*4.0)
	player.move_and_slide()
	player.position.x = clampf(player.position.x,-18,18)
	player.position.z = clampf(player.position.z,-18,18)
	elapsed += delta
	sprite.texture = textures[int(elapsed*9)%2] if d.length()>0.1 else textures[0]
	if abs(d.x)>0.1: sprite.flip_h = d.x<0
	camera.position = camera.position.lerp(player.position+Vector3(0,10,10),1-exp(-delta*8))
