extends SceneTree

var failures:=0

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool,message: String) -> void:
	if not ok:
		failures+=1
		printerr("FAIL: ",message)

func run() -> void:
	var args:=OS.get_cmdline_user_args()
	RenderingServer.render_loop_enabled=false
	if args.size()!=1 or not preload("res://natural_maps.gd").MAPS.has(args[0]) or preload("res://world_saves.gd").occupied(1):
		printerr("Use an empty test profile and pass a map ID.")
		quit(1)
		return
	set_meta("evergrove_map",args[0])
	var w=preload("res://main.tscn").instantiate()
	root.add_child(w)
	w.set_physics_process(false)
	await physics_frame
	await physics_frame
	var map=w.village.landscape
	var shore=map.shoreline
	var grid=w.village.world_grid
	var bridge: Rect2=map.bridge
	check(bridge.has_area(),"Bridge present")
	for sign_x in [1,-1]:
		var x: float=bridge.position.x-1.5 if sign_x==1 else bridge.end.x+1.5
		w.player.position=Vector3(x,.51,bridge.get_center().y)
		var distance:=bridge.size.x+3
		var stood_on_deck:=false
		for step in ceili((distance+1)*Engine.physics_ticks_per_second/4.):
			await physics_frame
			w.player.velocity=Vector3(4.*sign_x,-2,0)
			w.player.move_and_slide()
			if absf(w.player.position.x-bridge.get_center().x)<.4 and w.player.position.y>.6:
				stood_on_deck=true
			if absf(w.player.position.x-x)>=distance: break
		check(stood_on_deck and absf(w.player.position.x-x)>=distance,"Both bridge landings pass the player capsule")
	w.player.position=Vector3(bridge.get_center().x,.65,bridge.get_center().y)
	check(w.player.move_and_collide(Vector3.BACK*1.5)!=null,"Bridge rail stops the player")
	for cell: Vector2i in grid.reserved:
		if grid.reserved[cell]=="Árvore":
			check(shore.distance_at(Vector2(cell))>.5,"Dry tree footprint at "+str(cell))
	var meadow: Rect2i=map.DISTRICTS[map.id][2]
	var lot:=false
	for x in range(meadow.position.x,meadow.end.x-4):
		for z in range(meadow.position.y,meadow.end.y-3):
			if grid.reason(Rect2i(x,z,5,4))=="": lot=true
	check(lot,"The meadow fits a residential footprint")
	# Flood walkable tiles from arrival, including paths and bridge deck.
	var from:=Vector2i(0,6)
	var reached:={from:true}
	var queue: Array[Vector2i]=[from]
	var i:=0
	while i<queue.size():
		var cell:=queue[i]
		i+=1
		for offset: Vector2i in [Vector2i.LEFT,Vector2i.RIGHT,Vector2i.UP,Vector2i.DOWN]:
			var n:=cell+offset
			if reached.has(n) or not grid.bounds.has_point(n): continue
			if shore.distance_at(Vector2(n))<.3 and not bridge.has_point(Vector2(n)): continue
			if grid.reserved.get(n,"") in ["Árvore","Edifício","Construção ou obstáculo"]: continue
			reached[n]=true
			queue.append(n)
	for cell: Vector2i in grid.reserved:
		if grid.reserved[cell]=="Recurso": check(reached.has(cell),"Reachable resource "+str(cell))
	for x in range(grid.bounds.position.x,grid.bounds.end.x):
		for z in range(grid.bounds.position.y,grid.bounds.end.y):
			if grid.reason(Rect2i(x,z,3,3))=="":
				check(reached.has(Vector2i(x+1,z+1)),"Reachable clearing")
	# An old field inside the newly carved cove keeps its established dry bank.
	var old_map=preload("res://natural_maps.gd").new(map.id,map.seed_value)
	var cove: Vector3=shore.COVES[shore.variant][0]
	var field:=Vector2(cove.x,cove.y).move_toward(Vector2.ZERO,cove.z*.7).round()
	check(old_map.shoreline.coast(field)<1.35,"Migration fixture intersects new inlet")
	old_map.protect_existing_layout([{"x":field.x,"z":field.y}],[],w.life.house)
	check(old_map.shoreline.classic_coast and old_map.shoreline.coast(field)>0,"Existing field remains on dry land")
	var out:=OS.get_environment("EVERGROVE_MAP_PREVIEWS")
	if not out.is_empty():
		RenderingServer.render_loop_enabled=true
		w.hud.hide()
		w.graphics.hide()
		w.pad.hide()
		w.apply_graphics(1)
		w.update_solar_lighting(.23)
		w.camera.size=83
		w.camera.position=Vector3(0,76,20)
		w.camera.look_at(Vector3.ZERO)
		await process_frame
		await RenderingServer.frame_post_draw
		var frame:=root.get_texture().get_image()
		check(frame!=null and frame.save_png(out.path_join(args[0]+".png"))==OK,"Save map overview")
	w.atmosphere.set_outdoors(false)
	w.queue_free()
	await process_frame
	await process_frame
	if not out.is_empty(): await create_timer(.3).timeout
	print(args[0]," · world polish failures: ",failures)
	quit(1 if failures else 0)
