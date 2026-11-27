extends SceneTree

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	set_meta("evergrove_map","vale")
	var w=preload("res://main.tscn").instantiate()
	root.add_child(w)
	w.set_physics_process(false)
	await process_frame
	var shore=w.village.shoreline
	w.life.room=-1
	w.apply_graphics(2)
	w.camera.size=13
	var out:=OS.get_environment("EVERGROVE_PREVIEWS")
	DirAccess.make_dir_recursive_absolute(out)
	for kind: String in ["sun","rain","wind","storm"]:
		w.life.weather.kind=kind
		w.life.weather.levels=w.life.weather.LEVELS[kind]
		for location: String in ["lake","beach"]:
			var target: Vector2=shore.lake if location=="lake" else Vector2(-9,31)
			var actor:=target+Vector2(0,6 if location=="lake" else -2)
			w.player.position=Vector3(actor.x,0.52,actor.y)
			var center:=Vector3(target.x,0,target.y)
			w.camera.position=center+Vector3(0,10,10)
			w.camera.look_at(center)
			w.update_solar_lighting(0.20)
			print("Capturing ",location," ",kind)
			await create_timer(0.35).timeout
			await RenderingServer.frame_post_draw
			var frame:=root.get_texture().get_image()
			if frame==null or frame.is_empty():
				printerr("No frame: ",location," ",kind)
				quit(1)
				return
			if frame.save_png(out.path_join(location+"-"+kind+".png"))!=OK:
				quit(1)
				return
			print("Saved ",location,"-",kind)
	quit()
