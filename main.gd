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
var sky_fill := DirectionalLight3D.new()
var sky_dome := Sky.new()
var sky_paint := ProceduralSkyMaterial.new()
var physical_sky := PhysicalSkyMaterial.new()
var sky_period := -1
var sky := Environment.new()
var autosave := 0.0
var ui_elapsed := 0.0
var town := preload("res://neighbors.gd").new()
var village_menu := preload("res://village_menu.gd").new()
var site := preload("res://home_site.gd").new()
var home_ui := preload("res://home_ui.gd").new()
var focus_kind := ""
var lot_rooms := {}
var focus_lot := -1
var focus_resident := ""
var focus_index := -1
var initialized := false

func update_look() -> void:
	var look: Array = life.house.look
	var hair := Color(["674637","ad804d","393236","ad624c"][int(look[1])])
	var fabric := Color(["517b91","6e8964","91596b","b29554","49778c","b46454"][int(look[3])])
	character.configure(hair,fabric,Color("f2c39b"),int(look[0]),int(look[2]),-0.51)

func door(i: int) -> Vector2:
	if i==life.room and life.lot_exit.size()>=3: return Vector2(life.lot_exit[0],life.lot_exit[1])
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
	e.glow_bloom = 0.0
	e.glow_hdr_threshold = 0.95
	e.glow_hdr_scale = 0.45
	e.glow_intensity = 0.24
	e.glow_blend_mode = Environment.GLOW_BLEND_MODE_ADDITIVE
	sky_dome.sky_material = sky_paint
	sky_dome.radiance_size = Sky.RADIANCE_SIZE_128
	sky_paint.sun_angle_max = 6.0
	sky_paint.sun_curve = 0.25
	physical_sky.rayleigh_coefficient = 2.4
	physical_sky.mie_coefficient = 0.004
	physical_sky.turbidity = 3.5
	physical_sky.sun_disk_scale = 1.2
	physical_sky.energy_multiplier = 0.72
	physical_sky.ground_color = Color("647d50")
	e.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	e.sky = sky_dome
	env.environment = e
	add_child(env)
	sun.rotation_degrees = Vector3(-55,-35,0)
	sun.shadow_enabled = true
	sun.light_energy = 0.65
	sun.light_specular = 0.15
	sun.directional_shadow_max_distance = 32.0
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
	add_child(sun)
	sky_fill.shadow_enabled = false
	sky_fill.light_specular = 0.0
	sky_fill.sky_mode = DirectionalLight3D.SKY_MODE_LIGHT_ONLY
	add_child(sky_fill)
	add_child(life)
	if preload("res://natural_maps.gd").MAPS.has(life.map_id):
		village.landscape=preload("res://natural_maps.gd").new(life.map_id,life.map_seed)
		town.frontier=true
	add_child(village)
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
	configure_world_grid()
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
		prepare_lot_room(life.room)
		player.position = town.origin(life.room)+Vector3(life.room_pos.x,0.51,life.room_pos.y)
		camera.position = player.position+Vector3(0,10,10)
	town.step(0,game_hour(),life.room)
	add_child(graphics)
	graphics.build(self)
	graphics.quality_changed.connect(apply_graphics)
	apply_graphics(graphics.level)
	initialized = true
	life.settlement.advance(life)
	site.refresh()
	update_world_ui()
	if not FileAccess.file_exists(life.save_path):
		save_game()
		hud.show_note("Horta a leste · equipe a enxada")

func prepare_lot_room(room: int) -> void:
	if room in [7,8] and not lot_rooms.has(room):
		town.build_room(room,0 if room==7 else 5)
		lot_rooms[room]=true

func configure_world_grid() -> void:
	var grid=village.world_grid
	if village.landscape:
		# Move forage clear of shoreline and trunks before reserving its cell.
		grid.reserve_box(Vector2(0,6),Vector2(2,2),"Chegada")
		grid.reserve_box(Vector2(0,1),Vector2(8,4),"Acampamento dos visitantes")
	# Resources, entrances and NPC travel graph share the same occupancy contract.
	for bed in life.beds:
		grid.reserve_box(Vector2(bed.position.x,bed.position.z),Vector2(1.15,1.15),"Horta")
	for resource in life.resources:
		var p: Vector3=resource.node.position
		if village.landscape:
			var cell:=Vector2i(roundi(p.x),roundi(p.z))
			while grid.reserved.has(cell) or village.landscape.original_water_cells.has(cell) or life.house.at(-1,cell)>=0:
				cell.x=wrapi(cell.x+1,-29,30)
			resource.node.position=Vector3(cell.x,p.y,cell.y)
			p=resource.node.position
		grid.reserve_box(Vector2(p.x,p.z),Vector2(0.9,0.9),"Recurso")
	for i in 7:
		if town.frontier and i!=6: continue
		var p: Vector2=life.house.DOOR if i==6 else town.DOORS[i]
		grid.reserve_box(p+Vector2(0,0.35),Vector2(1.9,1.8),"Entrada")
	for id in town.graph.get_point_ids():
		if town.frontier: break
		for neighbor in town.graph.get_point_connections(id):
			if neighbor>id:
				grid.reserve_line(town.graph.get_point_position(id),town.graph.get_point_position(neighbor),1.2,"Rota de moradores")
	life.house.world_grid=grid

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
		"settler": home_ui.meet(focus_resident)
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
				if focus_lot>=0:
					var lot: Dictionary=life.house.objects[focus_lot]
					var entry:=site.entrance(lot)
					life.lot_exit=[entry.x,entry.y,lot.get("who",""),int(lot.r)]
					prepare_lot_room(focus_index)
				life.room = focus_index
				player.position = town.origin(life.room)+Vector3(0,0.52,2.25)
			else:
				var offset:=Vector2(0,0.4)
				if life.lot_exit.size()==4: offset=offset.rotated(-float(life.lot_exit[3])*PI/2)
				player.position = town.outdoor(door(life.room)+offset)+Vector3.UP*0.52
				life.room = -1
				life.lot_exit=[]
			player.velocity = Vector3.ZERO
			camera.position = player.position+Vector3(0,10,10)
			town.step(0,game_hour(),life.room)
			update_world_ui()
			save_game()

func use_item() -> void:
	if graphics.shade.visible or home_ui.menu.visible or site.active: return
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
		if event.keycode in [KEY_ESCAPE,KEY_I]:
			village_menu.close()
			get_viewport().set_input_as_handled()
		elif event.keycode in [KEY_E,KEY_SPACE] and village_menu.resident>=0:
			village_menu.advance_dialogue()
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
	focus_lot = -1
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
		if (life.room==5 or (life.room==8 and life.lot_exit.size()>=3 and life.lot_exit[2]=="merchant")) and absf(local.x)<2.6 and local.z<0.65:
			focus_kind = "shop"
			hud.action.text = "Abrir armazém"
	else:
		if life.target>=0:
			best = Vector2(player.position.x-life.marker.position.x,player.position.z-life.marker.position.z).length()
		for i in 7:
			if town.frontier and i!=6: continue
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
	if life.room==-1:
		for j in life.house.objects.size():
			var obj: Dictionary=life.house.objects[j]
			if not obj.get("complete",false): continue
			var d:=Vector2(player.position.x,player.position.z).distance_to(site.entrance(obj))
			if d<best:
				best=d
				focus_kind="door"
				focus_lot=j
				focus_index=8 if obj.id=="shop" else 7
				hud.action.text="Entrar na loja" if obj.id=="shop" else "Entrar na casa"
		for actor in site.settlers.get_children():
			var d:=Vector2(player.position.x-actor.position.x,player.position.z-actor.position.z).length()
			if d<best:
				best=d
				focus_kind="settler"
				focus_resident=actor.name
				hud.action.text="Falar · "+str(life.settlement.PEOPLE[focus_resident][0])
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
	hud.clock_label.text = "Dia %d   %02d:%02d   ·   %d folhas" % [life.day,hours,minutes,life.social.coins]
	update_solar_lighting(phase)

func update_solar_lighting(phase: float) -> void:
	# Sun crosses the sky, with lower intensity and long shadows near the horizon.
	var elevation := sin(phase*TAU)
	var daylight := smoothstep(-0.13,0.24,elevation)
	var twilight := (1.0-smoothstep(0.02,0.58,absf(elevation)))*smoothstep(-0.25,0.015,elevation)
	var dusk := phase>0.25 and phase<0.70
	var horizon := Color("f6bca1") if not dusk else Color("ef977a")
	var direct := Color("fff7e8").lerp(Color("ffb064"),twilight*0.85)
	var strength := lerpf(0.0,1.02,smoothstep(-0.06,0.48,elevation))
	sun.rotation_degrees = Vector3(-72.0*elevation,-105.0+phase*360.0,0)
	sun.light_color = direct
	sun.light_energy = strength
	sun.light_specular = 0.45 if quality_level>=2 else 0.10
	sky.ambient_light_energy = lerpf(0.36,0.58,daylight)
	sky.ambient_light_color = Color("899ed8").lerp(Color("f2f4e8"),daylight).lerp(Color("f5c39d"),twilight*0.30)
	sky.background_color = Color("23354f").lerp(Color("a6cbdc"),daylight).lerp(horizon,twilight)
	sky_fill.visible = quality_level>=2
	sky_fill.rotation_degrees = Vector3(-48,sun.rotation_degrees.y+155,0)
	sky_fill.light_color = Color("93b1eb").lerp(Color("bcd9ed"),daylight)
	sky_fill.light_energy = lerpf(0.24,0.09,daylight)
	sky.background_mode = Environment.BG_SKY if quality_level>=2 and life.room<0 else Environment.BG_COLOR
	var period := floori(phase*48.0)
	if period!=sky_period:
		sky_period=period
		sky_paint.sky_top_color = Color("172741").lerp(Color("6598cd"),daylight).lerp(Color("927caa"),twilight*0.75)
		sky_paint.sky_horizon_color = sky.background_color
		sky_paint.ground_horizon_color = sky.background_color
		sky_paint.ground_bottom_color = Color("41534d").lerp(Color("829484"),daylight)
	sky.glow_enabled = quality_level==3 and life.room<0 and daylight<0.22 and DisplayServer.get_name()!="headless"
	village.update_lamps(daylight)
	village.update_water_light(sky.background_color,daylight,phase)
	if grade_material != null:
		grade_material.set_shader_parameter("dusk",twilight if life.room<0 else 0.0)
		grade_material.set_shader_parameter("daylight",daylight if life.room<0 else 1.0)
	village.update_contact_light(daylight)
	sky.fog_enabled = quality_level>=2 and life.room<0
	sky.fog_light_color = sky.background_color
	sky.fog_density = (0.0018 if quality_level==3 else 0.0009)*(1.0+twilight*2.5)
	sky.fog_sun_scatter = 0.22+0.38*twilight
	sky.fog_light_energy = lerpf(0.38,0.9,daylight)
	if life.room>=0:
		sun.rotation_degrees = Vector3(-55,-35,0)
		sun.light_color = Color("ffe9cb")
		sun.light_energy = 0.36
		sky_fill.visible = false
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
uniform float saturation : hint_range(0.0, 1.5) = 1.0;
uniform int quality = 2;
uniform float dusk = 0.0;
uniform float daylight = 1.0;
void fragment() {
	vec3 src = texture(world_screen, SCREEN_UV).rgb;
	float lum = dot(src, vec3(0.2126, 0.7152, 0.0722));
	// Boost muted colors more than already saturated colors, keeping skin and whites natural.
	float chroma = max(src.r,max(src.g,src.b))-min(src.r,min(src.g,src.b));
	float vibrance = (saturation-1.0)*(1.0-0.65*chroma)*mix(0.55,1.0,daylight);
	vec3 c = mix(vec3(lum),src,1.0+vibrance);
	c = mix(c,c*c*(3.0-2.0*c),0.11);
	float peak = max(c.r,max(c.g,c.b));
	float shoulder = smoothstep(0.76,1.0,peak);
	c *= 1.0-highlight_strength*shoulder;
	c *= mix(vec3(0.99,1.0,1.035),vec3(1.035,1.015,0.99),smoothstep(0.15,0.75,lum));
	if (quality >= 2) {
		float vignette = smoothstep(0.26, 0.72, length((SCREEN_UV - 0.5) * vec2(1.0, 0.83)));
		c *= 1.0 - vignette * (0.018 + 0.022 * dusk);
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
	if DisplayServer.get_name() != "headless":
		if renderer != "gl_compatibility":
			viewport.scaling_3d_scale = [0.60,0.80,1.0,1.15][quality_level]
		viewport.msaa_3d = Viewport.MSAA_4X if quality_level==3 else (Viewport.MSAA_2X if quality_level==2 else Viewport.MSAA_DISABLED)
	sun.shadow_enabled = quality_level>0
	sun.directional_shadow_max_distance = [12.0,18.0,28.0,42.0][quality_level]
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS if quality_level==3 else DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
	sun.directional_shadow_blend_splits = quality_level>=2
	sun.shadow_blur = [1.0,0.9,1.15,1.45][quality_level]
	sky.ambient_light_sky_contribution = [0.0,0.0,0.2,0.35][quality_level]
	if DisplayServer.get_name() != "headless":
		RenderingServer.directional_shadow_atlas_set_size([512,1024,2048,4096][quality_level],quality_level<3)
		RenderingServer.directional_soft_shadow_filter_set_quality(RenderingServer.SHADOW_QUALITY_SOFT_HIGH if quality_level==3 else (RenderingServer.SHADOW_QUALITY_SOFT_LOW if quality_level==2 else RenderingServer.SHADOW_QUALITY_HARD))
	sky_dome.sky_material = physical_sky if quality_level==3 else sky_paint
	sky.tonemap_mode = Environment.TONE_MAPPER_FILMIC if quality_level>=2 else Environment.TONE_MAPPER_LINEAR
	sky.tonemap_white = 1.6
	sky.tonemap_exposure = 1.02
	village.set_quality(quality_level)
	CozyCharacter.set_quality(quality_level)
	if grade_overlay != null:
		grade_overlay.visible = quality_level>0
		grade_material.set_shader_parameter("quality",quality_level)
		grade_material.set_shader_parameter("highlight_strength",0.08)
		grade_material.set_shader_parameter("saturation",[1.0,1.17,1.27,1.32][quality_level])
	update_solar_lighting(life.clock/life.DAY_SECONDS)

func save_game() -> void:
	if initialized:
		if life.settlement.advance(life): site.refresh()
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
		player.position.x = clampf(player.position.x,village.world_grid.bounds.position.x,village.world_grid.bounds.end.x-1)
		player.position.z = clampf(player.position.z,village.world_grid.bounds.position.y,village.world_grid.bounds.end.y-1)
	else:
		var center := town.origin(life.room)
		player.position.x = clampf(player.position.x,center.x-3.6,center.x+(7.6 if life.room==6 and life.house.expanded else 3.6))
		player.position.z = clampf(player.position.z,-2.7,2.7)
	elapsed += delta
	character.pose(d,delta)
	if site.blend==0: camera.position = camera.position.lerp(player.position+Vector3(0,10,10),1-exp(-delta*8))
