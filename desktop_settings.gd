extends RefCounted
# Desktop-only preferences, separate from world saves and Android settings.
const PATH := "user://desktop.cfg"
const RESOLUTIONS := [Vector2i(960,540),Vector2i(1280,720),Vector2i(1600,900),Vector2i(1920,1080),Vector2i(2560,1440)]
const FPS_LIMITS := [30,60,120,144,0]

static func active() -> bool:
	return OS.has_feature("pc") and DisplayServer.get_name()!="headless"

static func config() -> ConfigFile:
	var cfg := ConfigFile.new()
	cfg.load(PATH)
	return cfg

static func set_pref(key: String,value: Variant) -> void:
	var cfg := config()
	cfg.set_value("desktop",key,value)
	cfg.save(PATH)

static func resolution_index(cfg: ConfigFile) -> int:
	return clampi(int(cfg.get_value("desktop","resolution",1)),0,RESOLUTIONS.size()-1)

static func fps_index(cfg: ConfigFile) -> int:
	return clampi(int(cfg.get_value("desktop","fps",1)),0,FPS_LIMITS.size()-1)

static func resize_window(index: int) -> void:
	if not active() or DisplayServer.window_get_mode()!=DisplayServer.WINDOW_MODE_WINDOWED: return
	var usable := DisplayServer.screen_get_usable_rect()
	var requested: Vector2i=RESOLUTIONS[clampi(index,0,RESOLUTIONS.size()-1)]
	var scale := minf(1.0,minf(float(usable.size.x)/requested.x,float(maxi(1,usable.size.y-48))/requested.y))
	var size := Vector2i(Vector2(requested)*scale)
	DisplayServer.window_set_size(size)
	DisplayServer.window_set_position(usable.position+(usable.size-size)/2)

static func set_fullscreen(enabled: bool) -> void:
	if not active(): return
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN if enabled else DisplayServer.WINDOW_MODE_WINDOWED)
	set_pref("fullscreen",enabled)
	if not enabled: resize_window(resolution_index(config()))

static func toggle_fullscreen() -> void:
	if active(): set_fullscreen(DisplayServer.window_get_mode()!=DisplayServer.WINDOW_MODE_FULLSCREEN)

static func choose_resolution(index: int) -> void:
	set_pref("resolution",index)
	resize_window(index)

static func choose_fps(index: int) -> void:
	set_pref("fps",index)
	if active(): Engine.max_fps=FPS_LIMITS[clampi(index,0,FPS_LIMITS.size()-1)]

static func choose_vsync(enabled: bool) -> void:
	set_pref("vsync",enabled)
	if active():
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED if enabled else DisplayServer.VSYNC_DISABLED)

static func apply_saved() -> void:
	if not active(): return
	var cfg := config()
	Engine.max_fps=FPS_LIMITS[fps_index(cfg)]
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED if bool(cfg.get_value("desktop","vsync",true)) else DisplayServer.VSYNC_DISABLED)
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN if bool(cfg.get_value("desktop","fullscreen",false)) else DisplayServer.WINDOW_MODE_WINDOWED)
	resize_window(resolution_index(cfg))

static func add_controls(parent: Control) -> void:
	if not active(): return
	var cfg := config()
	var heading := Label.new()
	heading.text="Vídeo · PC"
	parent.add_child(heading)
	var row := HBoxContainer.new()
	parent.add_child(row)
	var res := OptionButton.new()
	res.tooltip_text="Resolução em modo janela"
	res.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	for size in RESOLUTIONS: res.add_item("%d × %d" % [size.x,size.y])
	res.select(resolution_index(cfg))
	res.item_selected.connect(choose_resolution)
	row.add_child(res)
	var fps := OptionButton.new()
	fps.tooltip_text="Limite de quadros por segundo"
	for limit in FPS_LIMITS: fps.add_item("Sem limite" if limit==0 else "%d FPS" % limit)
	fps.select(fps_index(cfg))
	fps.item_selected.connect(choose_fps)
	row.add_child(fps)
	var toggles := HBoxContainer.new()
	parent.add_child(toggles)
	var full := Button.new()
	full.text="Tela cheia (F11)"
	full.tooltip_text="Alternar janela e tela cheia"
	full.pressed.connect(toggle_fullscreen)
	toggles.add_child(full)
	var vsync := CheckButton.new()
	vsync.text="VSync"
	vsync.button_pressed=bool(cfg.get_value("desktop","vsync",true))
	vsync.toggled.connect(choose_vsync)
	toggles.add_child(vsync)
