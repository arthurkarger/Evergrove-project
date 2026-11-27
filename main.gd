extends Node3D
var player: CharacterBody3D
var camera: Camera3D
var sprite: Sprite3D
var touch := Vector2.ZERO
var elapsed := 0.0
var textures: Array[ImageTexture] = []
const Village = preload("res://village.gd")

var life := preload("res://homestead.gd").new()
var hud := preload("res://roots_ui.gd").new()
var pad := preload("res://pad.gd").new()
var sun := DirectionalLight3D.new()
var sky := Environment.new()
var autosave := 0.0
var ui_elapsed := 0.0
var initialized := false

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
	var e := sky
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color("b8d6dc")
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color("fff1db")
	e.ambient_light_energy = 0.7
	env.environment = e
	add_child(env)
	sun.rotation_degrees = Vector3(-55,-35,0)
	sun.shadow_enabled = true
	add_child(sun)
	var village := Village.new()
	add_child(village)
	add_child(life)
	player = CharacterBody3D.new()
	add_child(player)
	player.position = life.saved_position
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
	pad.world = self
	ui.add_child(pad)
	add_child(hud)
	hud.build(life.bag)
	hud.picked.connect(select_slot)
	hud.use_requested.connect(use_item)
	hud.bag_toggled.connect(toggle_bag)
	hud.moved.connect(move_item)
	initialized = true
	update_world_ui()
	if not FileAccess.file_exists(life.SAVE):
		hud.show_note("Horta a leste · equipe a enxada")

func select_slot(slot: int) -> void:
	life.bag.selected = slot
	hud.refresh()
	var id := life.bag.held()
	hud.show_note("Espaço vazio" if id.is_empty() else life.bag.NAMES[id])
	update_world_ui()

func move_item(a: int,b: int) -> void:
	life.bag.move_slot(a,b)
	save_game()

func toggle_bag(open: bool) -> void:
	touch = Vector2.ZERO
	pad.finger = -1
	pad.offset = Vector2.ZERO
	pad.set_process_input(not open)
	pad.visible = not open
	pad.queue_redraw()
	if not open:
		save_game()
		update_world_ui()

func use_item() -> void:
	if hud.shade.visible: return
	life.find_target(player.position)
	if life.target < 0: return
	var message := life.interact()
	hud.show_note(message)
	hud.refresh()
	save_game()
	update_world_ui()

func _input(event: InputEvent) -> void:
	if not initialized or not event is InputEventKey or not event.pressed or event.echo: return
	match event.keycode:
		KEY_I, KEY_TAB: hud.toggle()
		KEY_ESCAPE:
			if hud.shade.visible: hud.toggle()
			else: return
		KEY_E: use_item()
		_:
			if event.keycode >= KEY_1 and event.keycode <= KEY_6 and not hud.shade.visible:
				select_slot(event.keycode-KEY_1)
			else: return
	get_viewport().set_input_as_handled()

func update_world_ui() -> void:
	life.find_target(player.position)
	hud.action.text = life.prompt()
	hud.action.disabled = life.target < 0
	var phase := life.clock / life.DAY_SECONDS
	var hours := posmod(6+floori(phase*24),24)
	var minutes := floori(fmod(phase*24,1.0)*6)*10
	hud.clock_label.text = "Dia %d  ·  %02d:%02d  ·  v%s" % [life.day,hours,minutes,ProjectSettings.get_setting("application/config/version")]
	var light := smoothstep(-0.36,0.38,sin(phase*TAU))
	sun.light_energy = lerpf(0.12,1.0,light)
	sky.ambient_light_energy = lerpf(0.48,0.7,light)
	sky.ambient_light_color = Color("a4b4d7").lerp(Color("fff1db"),light)
	sky.background_color = Color("465772").lerp(Color("b8d6dc"),light)

func save_game() -> void:
	if initialized:
		life.save_progress(player.position)
		if life.save_failed: hud.show_note("Falha ao salvar o progresso")

func _notification(what: int) -> void:
	if what in [NOTIFICATION_APPLICATION_PAUSED,NOTIFICATION_APPLICATION_FOCUS_OUT,NOTIFICATION_WM_CLOSE_REQUEST]:
		save_game()

func _exit_tree() -> void:
	save_game()

func _physics_process(delta):
	if hud.shade.visible: return
	var new_day := life.advance(delta)
	autosave += delta
	if new_day or autosave >= 5.0:
		save_game()
		autosave = 0
	if new_day: hud.show_note("Amanheceu · dia %d" % life.day)
	ui_elapsed += delta
	if ui_elapsed >= 0.12:
		update_world_ui()
		ui_elapsed = 0
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
