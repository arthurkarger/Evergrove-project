extends SceneTree

var failures := 0

func check(ok: bool, message: String) -> void:
	if not ok:
		printerr("FAIL: ",message)
		failures += 1

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var scene := preload("res://main.tscn")
	var w = scene.instantiate()
	root.add_child(w)
	await physics_frame
	w.graphics.open()
	check(w.graphics.shade.visible and not w.hud.visible and not w.pad.visible,"pause blocks normal controls")
	var clock: float = w.life.clock
	for i in 3:
		await physics_frame
	check(is_equal_approx(w.life.clock,clock),"paused world clock")
	w.graphics.show_settings()
	check(w.graphics.settings_page.visible and not w.graphics.pause_page.visible,"settings page")
	var last_count := -1
	for level in range(4):
		w.graphics.choose(level)
		check(w.quality_level==level and w.village.quality_level==level,"quality propagation")
		check(w.sun.shadow_enabled==(level>0),"shadow setting")
		check(w.grade_overlay.visible==(level>0),"post effect setting")
		var count := 0
		for batch in w.village.grass_batches:
			count += batch.multimesh.visible_instance_count
		check(count>last_count,"increasing grass density")
		last_count = count
	var cfg := ConfigFile.new()
	check(cfg.load(w.graphics.SAVE_PATH)==OK and int(cfg.get_value("graphics","quality",-1))==3,"saved quality")
	w.graphics.back()
	check(w.graphics.pause_page.visible,"back to pause")
	w.graphics.back()
	check(not w.graphics.shade.visible and w.hud.visible and w.pad.visible,"resume controls")
	print("Graphics integration failures: ",failures)
	quit(1 if failures else 0)
