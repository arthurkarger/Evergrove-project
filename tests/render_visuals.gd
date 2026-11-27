extends SceneTree

var failures:=0

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool, detail: String) -> void:
	if not ok:
		printerr("FAIL: ",detail)
		failures+=1

func run() -> void:
	set_meta("evergrove_map","vale")
	var w=preload("res://main.tscn").instantiate()
	root.add_child(w)
	w.set_physics_process(false)
	var out:=OS.get_environment("EVERGROVE_PREVIEWS")
	if not out.is_empty(): DirAccess.make_dir_recursive_absolute(out)
	for level in 4:
		w.apply_graphics(level)
		var target:=Vector3(17,0.52,-8) if level%2 else Vector3(-7,0.52,17)
		w.player.position=target
		w.camera.position=target+Vector3(0,10,10)
		w.update_solar_lighting([0.23,0.14,0.08,0.43][level])
		await process_frame
		await RenderingServer.frame_post_draw
		var frame:=root.get_texture().get_image()
		check(frame!=null and not frame.is_empty(),"Rendered image at preset %d" % level)
		if frame==null or frame.is_empty(): continue
		check(w.village.lake_material==(w.village.water_clear if level>=2 else w.village.water_simple),"Water pass selection")
		var colors: Dictionary={}
		for x in range(frame.get_width()/4,frame.get_width()*3/4,16):
			for y in range(frame.get_height()/4,frame.get_height()*3/4,16):
				colors[frame.get_pixel(x,y).to_html(false)]=true
		check(colors.size()>32,"Scene color variation")
		if not out.is_empty(): check(frame.save_png(out.path_join("preset-%d.png" % level))==OK,"Write preview")
	print("Rendered preset failures: ",failures)
	quit(1 if failures else 0)
