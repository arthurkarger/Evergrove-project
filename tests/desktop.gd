extends SceneTree
const Desktop = preload("res://desktop_settings.gd")
var failures := 0

func check(ok: bool,message: String) -> void:
	if not ok:
		printerr("FAIL: ",message)
		failures+=1

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	check(not Desktop.active(),"Headless runs do not change display mode")
	Desktop.set_pref("resolution",999)
	Desktop.set_pref("fps",-1)
	var cfg := Desktop.config()
	check(Desktop.resolution_index(cfg)==Desktop.RESOLUTIONS.size()-1,"Resolution preference clamped")
	check(Desktop.fps_index(cfg)==0,"FPS preference clamped")
	var w=preload("res://main.tscn").instantiate()
	root.add_child(w)
	await physics_frame
	var key := InputEventKey.new()
	key.pressed=true
	key.keycode=KEY_3
	w._input(key)
	check(w.life.bag.selected==2,"Keyboard selects hotbar")
	key.keycode=KEY_I
	w._input(key)
	check(w.hud.shade.visible,"Keyboard opens inventory")
	key.keycode=KEY_ESCAPE
	w._input(key)
	check(not w.hud.shade.visible,"Escape closes inventory")
	key.keycode=KEY_C
	w._input(key)
	check(w.home_ui.menu.visible and w.home_ui.page=="craft","Keyboard opens crafting")
	key.keycode=KEY_ESCAPE
	w._input(key)
	check(not w.home_ui.menu.visible,"Escape closes crafting")
	print("Desktop integration failures: ",failures)
	quit(1 if failures else 0)
