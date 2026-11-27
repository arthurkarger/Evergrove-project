extends CanvasLayer
signal quality_changed(level: int)
const SAVE_PATH := "user://graphics.cfg"
const NAMES := ["Leve", "Médio", "Alto", "Ultra"]
const DESCRIPTIONS := [
	"Menos vegetação, sombras desligadas e efeitos mínimos.",
	"Grama moderada, sombras e água simplificada.",
	"Vegetação cheia, sombras detalhadas e água animada.",
	"Máxima vegetação, sombras nítidas, água rica e luzes noturnas."
]
var level := 2
var shade := ColorRect.new()
var menu_button := Button.new()
var pause_page := VBoxContainer.new()
var settings_page := VBoxContainer.new()
var choices: Array[Button] = []
var detail := Label.new()
var fps := Label.new()
var world
var last_refresh := 0.0

func load_quality() -> int:
	var cfg := ConfigFile.new()
	if cfg.load(SAVE_PATH)==OK:
		level = clampi(int(cfg.get_value("graphics","quality",2)),0,3)
	return level

func save_quality() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("graphics","quality",level)
	cfg.save(SAVE_PATH)

func style(fill: String, border: String) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = Color(fill)
	s.border_color = Color(border)
	s.set_border_width_all(1)
	s.set_corner_radius_all(12)
	s.content_margin_left = 14
	s.content_margin_right = 14
	s.content_margin_top = 8
	s.content_margin_bottom = 8
	return s

func button(parent: Control, caption: String, fn: Callable) -> Button:
	var b := Button.new()
	b.text = caption
	b.custom_minimum_size.y = 48
	b.add_theme_font_size_override("font_size",20)
	b.add_theme_stylebox_override("normal",style("35473c","83917b"))
	b.add_theme_stylebox_override("hover",style("526449","e7d3a2"))
	b.add_theme_stylebox_override("pressed",style("6a7852","ead5a2"))
	b.add_theme_stylebox_override("focus",style("526449","f3d9a1"))
	b.pressed.connect(fn)
	parent.add_child(b)
	return b

func build(game) -> void:
	world = game
	layer = 10
	load_quality()
	add_child(menu_button)
	preload("res://ui_style.gd").center_icon(menu_button,preload("res://assets/art/icons/menu.svg"),28)
	menu_button.focus_mode=Control.FOCUS_NONE
	menu_button.add_theme_stylebox_override("normal",style("35473ce8","83917b"))
	menu_button.add_theme_stylebox_override("pressed",style("526449","e7d3a2"))
	menu_button.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	menu_button.offset_left = -64
	menu_button.offset_right = -12
	menu_button.offset_top = 10
	menu_button.offset_bottom = 58
	menu_button.pressed.connect(open)
	add_child(shade)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.color = Color("17261ed9")
	shade.mouse_filter = Control.MOUSE_FILTER_STOP
	var center := CenterContainer.new()
	shade.add_child(center)
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var panel := PanelContainer.new()
	panel.custom_minimum_size.x = 350
	panel.add_theme_stylebox_override("panel",style("293a30","b8c3a2"))
	center.add_child(panel)
	var margin := MarginContainer.new()
	for side in ["left","top","right","bottom"]:
		margin.add_theme_constant_override("margin_"+side,14)
	panel.add_child(margin)
	var pages := VBoxContainer.new()
	margin.add_child(pages)
	pages.add_child(pause_page)
	pause_page.add_theme_constant_override("separation",12)
	var title := Label.new()
	title.text = "EVERGROVE"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size",30)
	pause_page.add_child(title)
	button(pause_page,"Voltar ao jogo",close)
	button(pause_page,"Oficina e serviços da vila",open_services)
	button(pause_page,"Configurações",show_settings)
	button(pause_page,"Menu principal",return_to_title)
	pages.add_child(settings_page)
	settings_page.add_theme_constant_override("separation",8)
	var head := Label.new()
	head.text = "Qualidade gráfica"
	head.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	head.add_theme_font_size_override("font_size",24)
	settings_page.add_child(head)
	var row := GridContainer.new()
	row.columns = 2
	row.add_theme_constant_override("h_separation",8)
	row.add_theme_constant_override("v_separation",8)
	settings_page.add_child(row)
	for i in range(4):
		var b := button(row,NAMES[i],choose.bind(i))
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		choices.append(b)
	detail.custom_minimum_size = Vector2(290,64)
	detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	detail.add_theme_font_size_override("font_size",16)
	settings_page.add_child(detail)
	fps.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	settings_page.add_child(fps)
	button(settings_page,"Voltar",show_pause)
	shade.hide()
	settings_page.hide()
	update_choices()

func open() -> void:
	if shade.visible: return
	if world.site.active or world.home_ui.menu.visible or world.hud.shade.visible or world.village_menu.shade.visible: return
	world.hud.run_button.set_pressed_no_signal(false)
	world.touch = Vector2.ZERO
	world.pad.finger = -1
	world.pad.offset = Vector2.ZERO
	world.pad.set_process_input(false)
	world.pad.hide()
	world.player.velocity = Vector3.ZERO
	world.save_game()
	world.hud.hide()
	menu_button.hide()
	shade.show()
	show_pause()

func close() -> void:
	shade.hide()
	world.hud.show()
	world.pad.set_process_input(true)
	world.pad.show()
	world.pad.queue_redraw()
	menu_button.show()

func open_services() -> void:
	close()
	world.home_ui.open()

func return_to_title() -> void:
	world.save_game()
	if world.life.save_failed:
		close()
		world.hud.show_note("Falha ao salvar. Tente novamente antes de sair.")
		return
	get_tree().change_scene_to_file("res://title.tscn")

func show_pause() -> void:
	pause_page.show()
	settings_page.hide()

func show_settings() -> void:
	pause_page.hide()
	settings_page.show()
	update_choices()

func back() -> void:
	if settings_page.visible: show_pause()
	else: close()

func choose(i: int) -> void:
	level = clampi(i,0,3)
	save_quality()
	quality_changed.emit(level)
	update_choices()

func update_choices() -> void:
	for i in choices.size():
		choices[i].text = ("✓ " if i==level else "")+NAMES[i]
		choices[i].add_theme_stylebox_override("normal",style("65794d" if i==level else "35473c","f2d398" if i==level else "83917b"))
	detail.text = DESCRIPTIONS[level]
	fps.text = "FPS atual: %d" % Engine.get_frames_per_second()

func _process(delta: float) -> void:
	if not is_instance_valid(world): return
	if not shade.visible:
		menu_button.visible = world.hud.visible and not world.hud.shade.visible and not world.site.active and not world.home_ui.menu.visible and not world.village_menu.shade.visible
	elif settings_page.visible:
		last_refresh += delta
		if last_refresh>0.4:
			last_refresh = 0
			fps.text = "FPS atual: %d" % Engine.get_frames_per_second()
