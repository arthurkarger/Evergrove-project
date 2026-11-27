extends Node3D
const Village = preload("res://village.gd")
const GraphicsMenu = preload("res://graphics_menu.gd")
const AUDIO_PATH := "user://audio.cfg"
const GAME_PATH := "res://main.tscn"
const CREAM := Color("fff1d4")
const DARK := Color("263e32")
var village := Village.new()
var camera := Camera3D.new()
var sun := DirectionalLight3D.new()
var env := Environment.new()
var menu := VBoxContainer.new()
var options := VBoxContainer.new()
var fade := ColorRect.new()
var play_button: Button
var options_button: Button
var quality_buttons: Array[Button] = []
var quality := 2
var master_volume := 0.8
var music_volume := 0.45
var music := AudioStreamPlayer.new()
var t := 0.0
var leaving := false
var intro: Tween

func _ready() -> void:
	load_settings()
	build_landscape()
	build_interface()
	add_child(music)
	if DisplayServer.get_name()!="headless":
		build_music()
	apply_settings()
	play_button.grab_focus()
	fade.color = Color("243b2f")
	intro=create_tween()
	intro.tween_property(fade,"modulate:a",0.0,0.65)

func load_settings() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(GraphicsMenu.SAVE_PATH)==OK:
		quality = clampi(int(cfg.get_value("graphics","quality",2)),0,3)
	if cfg.load(AUDIO_PATH)==OK:
		master_volume=clampf(float(cfg.get_value("audio","master",0.8)),0,1)
		music_volume=clampf(float(cfg.get_value("audio","music",0.45)),0,1)

func build_landscape() -> void:
	var world := WorldEnvironment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("abcbd6")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("f8edce")
	env.ambient_light_energy = 0.68
	world.environment = env
	add_child(world)
	sun.rotation_degrees = Vector3(-48,-38,0)
	sun.light_color = Color("fff0ca")
	sun.light_energy = 0.95
	sun.directional_shadow_max_distance = 40
	add_child(sun)
	add_child(village)
	village.update_lamps(1.0)
	village.update_contact_light(1.0)
	village.update_water_light(Color("abcbd6"),1.0,0.19)
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 23.0
	add_child(camera)
	camera.current = true
	move_camera()

func move_camera() -> void:
	var target := Vector3(4.0+sin(t*0.12)*1.6,0.4,1.0)
	camera.position = target+Vector3(11.0+sin(t*0.10)*1.8,15.0,19.0)
	camera.look_at(target)

func _process(delta: float) -> void:
	t += delta
	move_camera()

func rounded(fill: Color, edge: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color=fill
	style.border_color=edge
	style.set_border_width_all(1)
	style.set_corner_radius_all(14)
	style.content_margin_left=16
	style.content_margin_right=16
	style.content_margin_top=6
	style.content_margin_bottom=6
	return style

func button(parent: Control, caption: String, fn: Callable, primary := false) -> Button:
	var b := Button.new()
	b.text=caption
	b.custom_minimum_size.y=45
	b.add_theme_font_size_override("font_size",23 if primary else 19)
	b.add_theme_color_override("font_color",DARK if primary else CREAM)
	b.add_theme_color_override("font_hover_color",DARK)
	b.add_theme_color_override("font_pressed_color",DARK)
	b.add_theme_color_override("font_focus_color",DARK if primary else CREAM)
	b.add_theme_stylebox_override("normal",rounded(CREAM if primary else Color("314b3de8"),Color("e8d6ae") if primary else Color("b5c4a5")))
	b.add_theme_stylebox_override("hover",rounded(Color("f8e4b8"),Color("fff1d4")))
	b.add_theme_stylebox_override("pressed",rounded(Color("e5c994"),Color("fff1d4")))
	var focus := rounded(Color(0,0,0,0),Color("fff5d9"))
	focus.set_border_width_all(2)
	b.add_theme_stylebox_override("focus",focus)
	b.pressed.connect(fn)
	parent.add_child(b)
	return b

func text_label(parent: Control, caption: String, size: int, tint: Color=CREAM) -> Label:
	var l := Label.new()
	l.text=caption
	l.add_theme_font_size_override("font_size",size)
	l.add_theme_color_override("font_color",tint)
	parent.add_child(l)
	return l

func build_interface() -> void:
	var layer := CanvasLayer.new()
	layer.layer=20
	add_child(layer)
	var root := Control.new()
	layer.add_child(root)
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var wash := TextureRect.new()
	wash.mouse_filter=Control.MOUSE_FILTER_IGNORE
	var gradient := Gradient.new()
	gradient.offsets=PackedFloat32Array([0.0,0.37,0.72,1.0])
	gradient.colors=PackedColorArray([Color("142d23ed"),Color("203b2fae"),Color("243b2f16"),Color("243b2f00")])
	var tex := GradientTexture2D.new()
	tex.gradient=gradient
	tex.fill_from=Vector2(0,0)
	tex.fill_to=Vector2(1,0)
	tex.width=512
	tex.height=8
	wash.texture=tex
	wash.expand_mode=TextureRect.EXPAND_IGNORE_SIZE
	root.add_child(wash)
	wash.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var anchor := CenterContainer.new()
	root.add_child(anchor)
	anchor.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	anchor.anchor_right=0.52
	anchor.offset_left=24
	anchor.offset_right=0
	var pages := VBoxContainer.new()
	pages.custom_minimum_size.x=320
	anchor.add_child(pages)
	pages.add_child(menu)
	menu.add_theme_constant_override("separation",12)
	text_label(menu,"UM LUGAR PARA CHAMAR DE LAR",13,Color("d4dfbd"))
	var logo := text_label(menu,"Evergrove",64)
	var font := SystemFont.new()
	font.font_names=PackedStringArray(["Georgia","Noto Serif","Droid Serif","serif"])
	font.font_weight=700
	logo.add_theme_font_override("font",font)
	logo.add_theme_color_override("font_shadow_color",Color("173025"))
	logo.add_theme_constant_override("shadow_offset_y",3)
	var line := HSeparator.new()
	line.add_theme_stylebox_override("separator",rounded(Color("d7d6aa"),Color("d7d6aa")))
	menu.add_child(line)
	text_label(menu,"Viva no seu próprio ritmo.",18,Color("e5e9d5"))
	var spacer := Control.new()
	spacer.custom_minimum_size.y=14
	menu.add_child(spacer)
	play_button=button(menu,"Jogar",start_game,true)
	options_button=button(menu,"Opções",show_options)
	pages.add_child(options)
	options.add_theme_constant_override("separation",7)
	text_label(options,"Opções",32)
	text_label(options,"Qualidade gráfica",17,Color("d4dfbd"))
	var grid := GridContainer.new()
	grid.columns=2
	grid.add_theme_constant_override("h_separation",8)
	grid.add_theme_constant_override("v_separation",6)
	options.add_child(grid)
	for i in 4:
		var b := button(grid,GraphicsMenu.NAMES[i],choose_quality.bind(i))
		b.size_flags_horizontal=Control.SIZE_EXPAND_FILL
		quality_buttons.append(b)
	add_volume(options,"Volume geral",master_volume,set_master)
	add_volume(options,"Música do menu",music_volume,set_music)
	var controls := text_label(options,"Controles: WASD / setas · E interagir · I mochila\nCelular: joystick e botões na tela.",14,Color("e5e9d5"))
	controls.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	button(options,"Voltar",show_menu)
	options.hide()
	var version := text_label(root,"v"+str(ProjectSettings.get_setting("application/config/version")),15,CREAM)
	version.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	version.offset_left=-100
	version.offset_right=-16
	version.offset_top=-36
	version.offset_bottom=-12
	version.horizontal_alignment=HORIZONTAL_ALIGNMENT_RIGHT
	fade.mouse_filter=Control.MOUSE_FILTER_IGNORE
	root.add_child(fade)
	fade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

func add_volume(parent: Control, caption: String, value: float, fn: Callable) -> void:
	var row := HBoxContainer.new()
	parent.add_child(row)
	var label := text_label(row,caption,15)
	label.custom_minimum_size.x=145
	var slider := HSlider.new()
	slider.min_value=0
	slider.max_value=1
	slider.step=0.05
	slider.value=value
	slider.custom_minimum_size=Vector2(125,32)
	slider.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	slider.value_changed.connect(fn)
	row.add_child(slider)

func show_options() -> void:
	if leaving: return
	menu.hide()
	options.show()
	quality_buttons[quality].grab_focus()

func show_menu() -> void:
	if leaving: return
	options.hide()
	menu.show()
	options_button.grab_focus()

func choose_quality(level: int) -> void:
	quality=clampi(level,0,3)
	var cfg := ConfigFile.new()
	cfg.load(GraphicsMenu.SAVE_PATH)
	cfg.set_value("graphics","quality",quality)
	cfg.save(GraphicsMenu.SAVE_PATH)
	apply_settings()

func set_master(value: float) -> void:
	master_volume=value
	save_audio()

func set_music(value: float) -> void:
	music_volume=value
	save_audio()

func save_audio() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("audio","master",master_volume)
	cfg.set_value("audio","music",music_volume)
	cfg.save(AUDIO_PATH)
	apply_audio()

func apply_audio() -> void:
	AudioServer.set_bus_mute(0,master_volume<=0.001)
	AudioServer.set_bus_volume_db(0,linear_to_db(maxf(0.001,master_volume)))
	music.volume_db=linear_to_db(maxf(0.001,music_volume*0.32))

func apply_settings() -> void:
	sun.shadow_enabled=quality>0
	village.set_quality(quality)
	if DisplayServer.get_name()!="headless":
		var vp := get_viewport()
		if RenderingServer.get_current_rendering_method()!="gl_compatibility":
			vp.scaling_3d_scale=[0.60,0.80,1.0,1.15][quality]
		vp.msaa_3d=Viewport.MSAA_4X if quality==3 else (Viewport.MSAA_2X if quality==2 else Viewport.MSAA_DISABLED)
	for i in quality_buttons.size():
		quality_buttons[i].text=("✓ " if i==quality else "")+GraphicsMenu.NAMES[i]
	apply_audio()

func build_music() -> void:
	# Original soft plucked melody, generated locally, with a seamless loop.
	var rate := 22050
	var beat := 0.64
	var length := roundi(rate*beat*16)
	var mix := PackedFloat32Array()
	mix.resize(length)
	var melody := [72,76,79,76,74,77,81,77,72,76,79,84,81,77,74,67]
	for i in melody.size():
		add_note(mix,rate,roundi(i*beat*rate),melody[i],0.72,0.12)
	for i in 4:
		var chord: Array = [[48,55,64],[50,57,65],[45,52,60],[43,55,62]][i]
		for j in chord.size():
			add_note(mix,rate,roundi((i*4+j*0.28)*beat*rate),chord[j],2.25,0.075)
	var data := PackedByteArray()
	data.resize(length*2)
	for i in length:
		data.encode_s16(i*2,roundi(clampf(mix[i],-1.0,1.0)*32760))
	var stream := AudioStreamWAV.new()
	stream.format=AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate=rate
	stream.data=data
	stream.loop_mode=AudioStreamWAV.LOOP_FORWARD
	stream.loop_begin=0
	stream.loop_end=length
	music.stream=stream
	music.play()

func add_note(buffer: PackedFloat32Array, rate: int, start: int, note: int, duration: float, amp: float) -> void:
	var freq := 440.0*pow(2.0,(note-69)/12.0)
	for i in roundi(rate*duration):
		var seconds := float(i)/rate
		var envelope := minf(seconds/0.025,1.0)*exp(-seconds*3.5)*minf((duration-seconds)/0.12,1.0)
		var sample := (sin(TAU*freq*seconds)+0.22*sin(TAU*freq*2.0*seconds))*envelope*amp
		var idx := posmod(start+i,buffer.size())
		buffer[idx]+=sample

func start_game() -> void:
	if leaving: return
	leaving=true
	if intro != null and intro.is_running(): intro.kill()
	play_button.disabled=true
	options_button.disabled=true
	fade.mouse_filter=Control.MOUSE_FILTER_STOP
	var transition := create_tween()
	transition.set_parallel(true)
	transition.tween_property(fade,"modulate:a",1.0,0.4)
	if music.playing: transition.tween_property(music,"volume_db",-60.0,0.4)
	await transition.finished
	get_tree().change_scene_to_file(GAME_PATH)

func _unhandled_key_input(event: InputEvent) -> void:
	if leaving or not event is InputEventKey or not event.pressed or event.echo: return
	if event.keycode==KEY_ESCAPE and options.visible:
		show_menu()
		get_viewport().set_input_as_handled()
