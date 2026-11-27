extends SceneTree

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	Engine.max_fps = 0
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	set_meta("evergrove_map","vale")
	var w = preload("res://main.tscn").instantiate()
	root.add_child(w)
	w.set_physics_process(false)
	await physics_frame
	await physics_frame
	print("BENCH adapter=", RenderingServer.get_video_adapter_name(), " renderer=", RenderingServer.get_current_rendering_method())
	for level in range(4):
		w.apply_graphics(level)
		w.update_solar_lighting(0.14)
		w.player.position=Vector3(-9,0.52,27)
		w.camera.position=w.player.position+Vector3(0,10,10)
		for warm in range(24):
			await RenderingServer.frame_post_draw
		var samples: Array[float] = []
		var start := Time.get_ticks_usec()
		var previous := start
		while Time.get_ticks_usec()-start<6000000 or samples.size()<12:
			var t := float(Time.get_ticks_usec()-start)/1000000.0
			w.player.position=Vector3(-9.0+sin(t*0.65)*3.0,0.52,27.0+cos(t*0.55)*1.5)
			w.camera.position=w.player.position+Vector3(0,10,10)
			await RenderingServer.frame_post_draw
			var current := Time.get_ticks_usec()
			samples.append(float(current-previous)/1000.0)
			previous=current
		samples.sort()
		var elapsed := float(previous-start)/1000000.0
		var mean := float(samples.size())/elapsed
		var p95 := samples[clampi(ceili(samples.size()*0.95)-1,0,samples.size()-1)]
		print("BENCH preset=",level," fps=",snappedf(mean,0.1)," p95_ms=",snappedf(p95,0.1)," frames=",samples.size())
	quit()
