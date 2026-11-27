extends Node3D
var player: CharacterBody3D
var camera: Camera3D
var sprite: Sprite3D
var touch := Vector2.ZERO
var elapsed := 0.0
var textures: Array[ImageTexture] = []
const Village = preload("res://village.gd")

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
	var village := Village.new()
	add_child(village)
	player = CharacterBody3D.new()
	add_child(player)
	player.position = Vector3(0,0.5,6)
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
	camera.size = 15
	add_child(camera)
	camera.position = player.position + Vector3(0,10,10)
	camera.look_at(player.position)
	camera.current = true
	var ui := CanvasLayer.new()
	add_child(ui)
	var label := Label.new()
	label.text = "Evergrove   ·   %s" % ProjectSettings.get_setting("application/config/version")
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
	player.position.x = clampf(player.position.x,-Village.LIMIT_X,Village.LIMIT_X)
	player.position.z = clampf(player.position.z,-Village.LIMIT_Z,Village.LIMIT_Z)
	elapsed += delta
	sprite.texture = textures[int(elapsed*9)%2] if d.length()>0.1 else textures[0]
	if abs(d.x)>0.1: sprite.flip_h = d.x<0
	camera.position = camera.position.lerp(player.position+Vector3(0,10,10),1-exp(-delta*8))
