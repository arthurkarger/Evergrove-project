extends SceneTree

var failures:=0

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool, detail: String) -> void:
	if not ok:
		printerr("FAIL: ",detail)
		failures+=1

func run() -> void:
	print("Visual test: creating world")
	set_meta("evergrove_map","vale")
	var w=preload("res://main.tscn").instantiate()
	root.add_child(w)
	w.set_physics_process(false)
	await physics_frame
	await physics_frame
	var coast=w.village.shoreline
	var grid=w.village.world_grid
	check(grid.terrain_at(Vector2i(-8,10))=="grass","Inland terrain classification")
	check(grid.reason(Rect2i(Vector2i(coast.lake),Vector2i.ONE))!="","Lake blocks building")
	# Sweep the player capsule across an unoccupied stretch of the southern beach.
	w.player.position=Vector3(-9,0.51,27)
	var hit:=false
	for i in 40:
		if w.player.move_and_collide(Vector3(0,0,0.3)):
			hit=true
			break
	var bank_position:=Vector2(w.player.position.x,w.player.position.z)
	check(hit and absf(coast.coast(bank_position))<0.75,"Capsule stops at visible shoreline")
	check(grid.reason(Rect2i(Vector2i(bank_position.round()),Vector2i.ONE))!="","Wet shore blocks construction")
	var out:=OS.get_environment("EVERGROVE_PREVIEWS")
	if not out.is_empty(): DirAccess.make_dir_recursive_absolute(out)
	for level in 4:
		print("Visual test: starting preset ",level)
		w.life.weather.kind=["sun","rain","wind","storm"][level]
		w.life.weather.levels=w.life.weather.LEVELS[w.life.weather.kind]
		w.apply_graphics(level)
		var target:=Vector3(18,0.52,-10) if level%2 else Vector3(-9,0.52,31)
		w.player.position=target
		w.camera.position=target+Vector3(0,10,10)
		w.update_solar_lighting([0.23,0.14,0.08,0.43][level])
		await create_timer(0.6).timeout
		print("Visual test: waiting for rendered frame ",level)
		await RenderingServer.frame_post_draw
		print("Visual test: reading frame ",level)
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
	w.atmosphere.set_outdoors(false)
	w.queue_free()
	await create_timer(.3).timeout
	print("Rendered preset failures: ",failures)
	quit(1 if failures else 0)
