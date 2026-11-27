extends Node3D
var player: CharacterBody3D
var camera: Camera3D
const CozyCharacter = preload("res://cozy_character.gd")
var character: CozyCharacter
var touch := Vector2.ZERO
var elapsed := 0.0
const Village = preload("res://village.gd")
const GraphicsMenu = preload("res://graphics_menu.gd")
var graphics := GraphicsMenu.new()
var village := Village.new()
var grade_overlay: ColorRect
var grade_material: ShaderMaterial
var quality_level := 2

var life := preload("res://homestead.gd").new()
var hud := preload("res://roots_ui.gd").new()
var pad := preload("res://pad.gd").new()
var sun := DirectionalLight3D.new()
var sky := Environment.new()
var autosave := 0.0
var ui_elapsed := 0.0
var town := preload("res://neighbors.gd").new()
var village_menu := preload("res://village_menu.gd").new()
var site := preload("res://home_site.gd").new()
var home_ui := preload("res://home_ui.gd").new()
var focus_kind := ""
var focus_index := -1
var initialized := false

func update_look() -> void:
	var look: Array = life.house.look
	var hair := Color(["674637","ad804d","393236","ad624c"][int(look[1])])
	var fabric := Color(["517b91","6e8964","91596b","b29554"][int(look[3])])
	character.configure(hair,fabric,Color("f2c39b"),int(look[0]),int(look[2]),-0.51)

func door(i: int) -> Vector2:
	return life.house.DOOR if i==6 else town.DOORS[i]
func _ready():
	var env := WorldEnvironment.new()
	var e := sky
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color("b8d6dc")
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color("e5dfd0")
	e.ambient_light_energy = 0.48
	e.glow_enabled = false
	env.environment = e
	add_child(env)
	sun.rotation_degrees = Vector3(-55,-35,0)
	sun.shadow_enabled = true
	sun.light_energy = 0.65
	sun.light_specular = 0.15
	sun.directional_shadow_max_distance = 32.0
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
	add_child(sun)
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
	character = CozyCharacter.new()
	player.add_child(character)
	update_look()
	camera = Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 15
	add_child(camera)
	camera.position = player.position + Vector3(0,10,10)
	camera.look_at(player.position)
	camera.current = true
	setup_world_shader()
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
	add_child(town)
	add_child(site)
	site.setup(self)
	add_child(home_ui)
	home_ui.setup(self)
	hud.home_requested.connect(home_ui.open)
	add_child(village_menu)
	village_menu.build(self)
	village_menu.closed.connect(close_social)
	village_menu.changed.connect(social_changed)
	if life.room>=0:
		player.position = town.origin(life.room)+Vector3(life.room_pos.x,0.51,life.room_pos.y)
		camera.position = player.position+Vector3(0,10,10)
	town.step(0,game_hour(),life.room)
	add_child(graphics)
	graphics.build(self)
	graphics.quality_changed.connect(apply_graphics)
	apply_graphics(graphics.level)
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

func game_hour() -> int:
	return posmod(6+floori(life.clock/life.DAY_SECONDS*24),24)

func social_changed() -> void:
	hud.refresh()
	save_game()
	update_world_ui()

func close_social() -> void:
	hud.visible = true
	toggle_bag(false)

func interact_focus() -> void:
	match focus_kind:
		"chest": home_ui.open_chest(focus_index)
		"bed":
			life.advance(life.DAY_SECONDS-life.clock)
			life.clock=0
			town.step(0,game_hour(),life.room)
			save_game()
			update_world_ui()
			hud.show_note("Bom dia · dia %d" % life.day)
		"person","shop":
			toggle_bag(true)
			hud.visible = false
			if focus_kind=="shop": village_menu.open_shop()
			else: village_menu.open_person(focus_index,game_hour())
		"door","exit":
			if life.room<0:
				life.room = focus_index
				player.position = town.origin(life.room)+Vector3(0,0.52,2.25)
			else:
				player.position = town.outdoor(door(life.room))+Vector3(0,0.52,0.55)
				life.room = -1
			player.velocity = Vector3.ZERO
			camera.position = player.position+Vector3(0,10,10)
			town.step(0,game_hour(),life.room)
			update_world_ui()
			save_game()

func use_item() -> void:
	if graphics.shade.visible: return
	if hud.shade.visible or village_menu.shade.visible: return
	update_world_ui()
	if focus_kind!="":
		interact_focus()
		return
	if life.room>=0: return
	life.find_target(player.position)
	if life.target < 0: return
	var message := life.interact()
	hud.show_note(message)
	hud.refresh()
	save_game()
	update_world_ui()

func _input(event: InputEvent) -> void:
	if not initialized or not event is InputEventKey or not event.pressed or event.echo: return
	if graphics.shade.visible:
		if event.keycode==KEY_ESCAPE:
			graphics.back()
			get_viewport().set_input_as_handled()
		return
	if home_ui.menu.visible or site.active:
		if event.keycode==KEY_ESCAPE: home_ui.close()
		elif site.active and event.keycode==KEY_R: home_ui.rotate_item()
		else: return
		get_viewport().set_input_as_handled()
		return
	if village_menu.shade.visible:
		if event.keycode in [KEY_ESCAPE,KEY_E,KEY_I]:
			village_menu.close()
			get_viewport().set_input_as_handled()
		return
	match event.keycode:
		KEY_B:
			if not hud.shade.visible: home_ui.open()
		KEY_I, KEY_TAB: hud.toggle()
		KEY_ESCAPE:
			if hud.shade.visible: hud.toggle()
			else: graphics.open()
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
	focus_kind = ""
	focus_index = -1
	var best := 1.85
	if life.room>=0:
		hud.action.text = "Interagir"
		hud.action.disabled = true
		life.marker.hide()
		var local := player.position-town.origin(life.room)
		if Vector2(local.x,local.z-2.8).length()<1.45:
			focus_kind = "exit"
			hud.action.text = "Sair"
			best = Vector2(local.x,local.z-2.8).length()
		if life.room==5 and absf(local.x)<2.6 and local.z<0.65:
			focus_kind = "shop"
			hud.action.text = "Abrir armazém"
	else:
		if life.target>=0:
			best = Vector2(player.position.x-life.marker.position.x,player.position.z-life.marker.position.z).length()
		for i in 7:
			var distance := Vector2(player.position.x,player.position.z).distance_to(door(i))
			if distance<best:
				best = distance
				focus_index = i
				focus_kind = "door"
				hud.action.text = "Minha casa" if i==6 else ("Armazém" if i==5 else "Casa de "+str(life.social.PEOPLE[i][0]))
	for i in town.actors.size():
		var actor := town.actors[i]
		if not actor.visible: continue
		var distance := Vector2(actor.position.x-player.position.x,actor.position.z-player.position.z).length()
		if distance<best:
			best = distance
			focus_kind = "person"
			focus_index = i
			hud.action.text = "Falar · "+str(life.social.PEOPLE[i][0])
	if life.room==6 and (player.position-site.cabin.position-Vector3(-2.85,0.51,-1.35)).length()<1.9:
		focus_kind="bed"
		hud.action.text="Dormir até amanhã"
		best=1.1
	if life.room in [-1,6]:
		var local:=site.player_flat()
		for i in life.house.objects.size():
			var obj: Dictionary=life.house.objects[i]
			if obj.room!=life.room or obj.id!="chest": continue
			var d:=local.distance_to(Vector2(obj.x,obj.z))
			if d<best:
				best=d
				focus_index=i
				focus_kind="chest"
				hud.action.text="Abrir baú"
	if focus_kind!="":
		hud.action.disabled = false
		life.marker.hide()
	var phase := life.clock / life.DAY_SECONDS
	var hours := posmod(6+floori(phase*24),24)
	var minutes := floori(fmod(phase*24,1.0)*6)*10
	hud.clock_label.text = "Dia %d  ·  %02d:%02d  ·  %d F  ·  v%s" % [life.day,hours,minutes,life.social.coins,ProjectSettings.get_setting("application/config/version")]
	update_solar_lighting(phase)

func update_solar_lighting(phase: float) -> void:
	# Sunrise at 06:00, noon at 12:00, sunset at 18:00.
	var elevation := sin(phase*TAU)
	var daylight := smoothstep(-0.10,0.28,elevation)
	var twilight := (1.0-smoothstep(0.06,0.60,absf(elevation)))*smoothstep(-0.22,0.02,elevation)
	var sunset := Color("ffc18a").lerp(Color("ffac82"),clampf(phase*2.0,0.0,1.0))
	sun.rotation_degrees = Vector3(-lerpf(12.0,68.0,maxf(elevation,0.0)),lerpf(-105.0,105.0,clampf(phase*2.0,0.0,1.0)),0)
	sun.light_color = Color("a7b9ed").lerp(Color("fff1da").lerp(sunset,twilight),daylight)
	sun.light_energy = lerpf(0.08,0.68,daylight)
	sky.ambient_light_energy = lerpf(0.29,0.48,daylight)
	sky.ambient_light_color = Color("9aabd8").lerp(Color("c7d9db"),daylight).lerp(Color("e5ac91"),twilight*0.64)
	sky.background_color = Color("293e63").lerp(Color("b8d6dc"),daylight).lerp(Color("eab08e"),twilight)
	village.update_lamps(daylight)
	if grade_material != null:
		grade_material.set_shader_parameter("dusk",twilight if life.room<0 else 0.0)
	sky.fog_enabled = quality_level>=2 and life.room<0
	sky.fog_light_color = sky.background_color
	sky.fog_density = 0.0035 if quality_level==3 else 0.0018
	if life.room>=0:
		sun.rotation_degrees = Vector3(-55,-35,0)
		sun.light_color = Color("ffe9cb")
		sun.light_energy = 0.36
		sky.ambient_light_energy = 0.62
		sky.ambient_light_color = Color("e9ddca")

# One screen sample, no blur, bloom, depth pass or HUD processing.
func setup_world_shader() -> void:
	var grade := CanvasLayer.new()
	grade.name = "WorldColorGrade"
	grade.layer = 0
	add_child(grade)
	var overlay := ColorRect.new()
	grade_overlay = overlay
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.focus_mode = Control.FOCUS_NONE
	var shader := Shader.new()
	shader.code = """
shader_type canvas_item;
render_mode unshaded, blend_disabled;
uniform sampler2D world_screen : hint_screen_texture, repeat_disable, filter_nearest;
uniform float highlight_strength : hint_range(0.0, 0.6) = 0.16;
uniform float saturation : hint_range(0.0, 1.2) = 1.0;
uniform int quality = 2;
uniform float dusk = 0.0;
void fragment() {
	vec3 src = texture(world_screen, SCREEN_UV).rgb;
	float lum = dot(src, vec3(0.2126, 0.7152, 0.0722));
	vec3 c = mix(vec3(lum), src, saturation);
	float shoulder = smoothstep(0.48, 1.0, max(c.r, max(c.g, c.b)));
	c *= 1.0 - highlight_strength * shoulder;
	// Gentle warm highlights and slightly cool shadows.
	c *= mix(vec3(0.98, 1.0, 1.025), vec3(1.015, 1.0, 0.975), smoothstep(0.15, 0.75, lum));
	if (quality >= 2) {
		float vignette = smoothstep(0.26, 0.72, length((SCREEN_UV - 0.5) * vec2(1.0, 0.83)));
		c *= 1.0 - vignette * (0.055 + 0.035 * dusk);
	}
	if (quality == 3) {
		// Subtle local contrast, without the old white bloom.
		vec3 neighbor = (texture(world_screen, SCREEN_UV + vec2(SCREEN_PIXEL_SIZE.x, 0.0)).rgb +
			texture(world_screen, SCREEN_UV - vec2(SCREEN_PIXEL_SIZE.x, 0.0)).rgb +
			texture(world_screen, SCREEN_UV + vec2(0.0, SCREEN_PIXEL_SIZE.y)).rgb +
			texture(world_screen, SCREEN_UV - vec2(0.0, SCREEN_PIXEL_SIZE.y)).rgb) * 0.25;
		c += clamp(src - neighbor, vec3(-0.15), vec3(0.15)) * 0.12;
	}
	COLOR = vec4(clamp(c, vec3(0.0), vec3(1.0)), 1.0);
}
"""
	grade_material = ShaderMaterial.new()
	grade_material.shader = shader
	overlay.material = grade_material
	grade.add_child(overlay)
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

func apply_graphics(level: int) -> void:
	quality_level = clampi(level,0,3)
	var viewport := get_viewport()
	var renderer := RenderingServer.get_current_rendering_method()
	# Mobile supports a separate 3D resolution scale; keep HUD resolution unchanged.
	if renderer != "gl_compatibility":
		viewport.scaling_3d_scale = [0.60,0.80,1.0,1.15][quality_level]
	viewport.msaa_3d = Viewport.MSAA_4X if quality_level==3 else (Viewport.MSAA_2X if quality_level==2 else Viewport.MSAA_DISABLED)
	sun.shadow_enabled = quality_level>0
	sun.directional_shadow_max_distance = [12.0,18.0,28.0,42.0][quality_level]
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS if quality_level==3 else DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
	sun.directional_shadow_blend_splits = quality_level>=2
	RenderingServer.directional_shadow_atlas_set_size([512,1024,2048,4096][quality_level],quality_level<3)
	RenderingServer.directional_soft_shadow_filter_set_quality(RenderingServer.SHADOW_QUALITY_SOFT_HIGH if quality_level==3 else (RenderingServer.SHADOW_QUALITY_SOFT_LOW if quality_level==2 else RenderingServer.SHADOW_QUALITY_HARD))
	village.set_quality(quality_level)
	CozyCharacter.set_quality(quality_level)
	if grade_overlay != null:
		grade_overlay.visible = quality_level>0
		grade_material.set_shader_parameter("quality",quality_level)
		grade_material.set_shader_parameter("highlight_strength",0.16)
	update_solar_lighting(life.clock/life.DAY_SECONDS)

func save_game() -> void:
	if initialized:
		if life.room<0: life.save_progress(player.position)
		else:
			var local := player.position-town.origin(life.room)
			life.room_pos = Vector2(local.x,local.z)
			life.save_progress(town.outdoor(door(life.room)))
		if life.save_failed: hud.show_note("Falha ao salvar o progresso")

func _notification(what: int) -> void:
	if what in [NOTIFICATION_APPLICATION_PAUSED,NOTIFICATION_APPLICATION_FOCUS_OUT,NOTIFICATION_WM_CLOSE_REQUEST]:
		save_game()

func _exit_tree() -> void:
	save_game()

func _physics_process(delta):
	if graphics.shade.visible: return
	if site.active or site.blend>0:
		site.camera_step(delta)
		if site.active: return
	if home_ui.menu.visible: return
	if hud.shade.visible or village_menu.shade.visible: return
	var new_day := life.advance(delta)
	town.step(delta,game_hour(),life.room)
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
	if life.room<0:
		player.position.x = clampf(player.position.x,-Village.LIMIT_X,Village.LIMIT_X)
		player.position.z = clampf(player.position.z,-Village.LIMIT_Z,Village.LIMIT_Z)
	else:
		var center := town.origin(life.room)
		player.position.x = clampf(player.position.x,center.x-3.6,center.x+(7.6 if life.room==6 and life.house.expanded else 3.6))
		player.position.z = clampf(player.position.z,-2.7,2.7)
	elapsed += delta
	character.pose(d,delta)
	if site.blend==0: camera.position = camera.position.lerp(player.position+Vector3(0,10,10),1-exp(-delta*8))
