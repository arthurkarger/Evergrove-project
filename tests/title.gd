extends SceneTree
var failures := 0
func check(ok: bool, msg: String) -> void:
	if not ok:
		printerr("FAIL: ",msg)
		failures+=1

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var title = preload("res://title.tscn").instantiate()
	root.add_child(title)
	current_scene=title
	await process_frame
	check(title.menu.visible and not title.options.visible,"Main menu at startup")
	check(not FileAccess.file_exists(preload("res://homestead.gd").SAVE),"Menu does not write gameplay save")
	title.options_button.pressed.emit()
	check(title.options.visible and not title.menu.visible,"Options opens")
	title.choose_quality(0)
	title.set_master(0.65)
	title.set_music(0.35)
	var cfg := ConfigFile.new()
	check(cfg.load("user://graphics.cfg")==OK and int(cfg.get_value("graphics","quality",-1))==0,"Graphics setting persisted")
	check(cfg.load("user://audio.cfg")==OK and is_equal_approx(float(cfg.get_value("audio","master",-1)),0.65),"Audio setting persisted")
	title.show_menu()
	check(title.menu.visible and not title.options.visible,"Back to menu")
	title.play_button.pressed.emit()
	await create_timer(0.8).timeout
	check(is_instance_valid(current_scene) and current_scene.scene_file_path=="res://main.tscn","Jogar loads gameplay")
	if is_instance_valid(current_scene) and current_scene.scene_file_path=="res://main.tscn":
		check(current_scene.quality_level==0,"Menu graphics quality used in gameplay")
		current_scene.graphics.open()
		current_scene.graphics.return_to_title()
		await process_frame
		await process_frame
		check(is_instance_valid(current_scene) and current_scene.scene_file_path=="res://title.tscn","Pause returns to main menu")
	print("Title menu integration failures: ",failures)
	quit(1 if failures else 0)
