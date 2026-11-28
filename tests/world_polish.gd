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
			if absf(grid.height_at(Vector2(n))-grid.height_at(Vector2(cell)))>.88: continue
			if shore.distance_at(Vector2(n))<.3 and not bridge.has_point(Vector2(n)): continue
			if grid.reserved.get(n,"") in ["Árvore","Edifício","Construção ou obstáculo"]: continue
			reached[n]=true
			queue.append(n)
	for cell: Vector2i in grid.reserved:
		if grid.reserved[cell]=="Recurso": check(reached.has(cell),"Reachable resource "+str(cell))
	for x in range(grid.bounds.position.x,grid.bounds.end.x):
		for z in range(grid.bounds.position.y,grid.bounds.end.y):
			if grid.reason(Rect2i(x,z,3,3))=="":
				check(reached.has(Vector2i(x+1,z+1)),"Reachable clearing "+str(Vector2i(x+1,z+1)))
	# An old field inside the newly carved cove keeps its established dry bank.
	var old_map=preload("res://natural_maps.gd").new(map.id,map.seed_value)
	var cove: Vector3=shore.COVES[shore.variant][0]
	var field:=Vector2(cove.x,cove.y).move_toward(Vector2.ZERO,cove.z*.7).round()
	check(old_map.shoreline.coast(field)<1.35,"Migration fixture intersects new inlet")
	old_map.protect_existing_layout([{"x":field.x,"z":field.y}],[],w.life.house)
	check(old_map.shoreline.classic_coast and old_map.shoreline.coast(field)>0,"Existing field remains on dry land")
	var relief=shore.relief
	check(relief.falls.size()==2 and relief.land_mesh.get_surface_count()==1,"Two cascades and a physical terrain surface")
	check(absf(grid.height_at(relief.source)-7.2)<.1 and absf(grid.height_at(relief.middle)-3.6)<.1,"Lakes on upper terraces")
	for layer in 2:
		var start: Vector2=relief.ramp_point(layer,-5.9 if layer==0 else -4.5)
		var end: Vector2=relief.ramp_point(layer,5.9 if layer==0 else 4.5)
		var direction:=start.direction_to(end)
		w.player.position=Vector3(start.x,relief.height(start)+.53,start.y)
		var before: float=w.player.position.y
		for step in ceili((start.distance_to(end)+2.3)*Engine.physics_ticks_per_second/4.):
			await physics_frame
			w.walk(direction,4.,1./Engine.physics_ticks_per_second)
			if (Vector2(w.player.position.x,w.player.position.z)-start).dot(direction)>=start.distance_to(end): break
		check(w.player.position.y-before>2.8,"Player climbs ramp "+str(layer)+" on "+args[0])
	var highest_gain:=0.
	var lowest: float=relief.height(relief.source)
	for k in range(1,101):
		var h: float=relief.height(relief.stream(k/100.))
		highest_gain=maxf(highest_gain,h-lowest)
		lowest=minf(lowest,h)
	check(highest_gain<.18,"River flows downhill throughout ("+str(highest_gain)+")")
	var plot_cell:=Vector2i.ZERO
	for z in range(-26,26):
		for x in range(-32,32):
			var cell:=Vector2i(x,z)
			if grid.height_at(Vector2(cell))>7.15 and grid.reason(Rect2i(cell,Vector2i(3,2)))=="": plot_cell=cell
	check(plot_cell!=Vector2i.ZERO,"Buildable highland clearing")
	if plot_cell!=Vector2i.ZERO:
		var pos:=Vector3(plot_cell.x,grid.height_at(plot_cell)+.51,plot_cell.y)
		w.life.bag.selected=2
		w.life.find_target(pos)
		check(w.life.interact()=="Terra preparada" and absf(w.life.beds.back().position.y-7.255)<.08,"Cultivate highland soil")
		var tile:=plot_cell+Vector2i.RIGHT
		check(w.life.house.place(-1,"bench",tile,0,-1,Vector2(-80,-80)),"Place furniture on upper shelf")
		w.site.refresh()
		check(absf(w.site.props.get_child(0).position.y-7.26)<.08,"Furniture rests on terrain")
		w.life.save_progress(pos)
		var stored: Dictionary=w.life.Saves.read_save(w.life.save_path)
		check(stored.world.terrain.has("pads") and stored.plots.size()==1 and stored.house.objects.size()==1,"Save highland plot and object")
	var out:=OS.get_environment("EVERGROVE_MAP_PREVIEWS")
	if args[0]=="vale" and out.is_empty():
		var loaded=preload("res://main.tscn").instantiate()
		root.add_child(loaded)
		check(loaded.life.plots.size()==1 and loaded.life.house.objects.size()==1 and absf(loaded.life.beds[0].position.y-7.255)<.08,"Reload highland farm and furniture")
		loaded.free()
		var original: Dictionary=w.life.Saves.read_save(w.life.save_path)
		original.world.erase("terrain")
		var saved_field: Vector2i=Vector2i(relief.source)
		original.plots[0].x=saved_field.x
		original.plots[0].z=saved_field.y
		w.life.Saves.write_save(w.life.save_path,original)
		original=w.life.Saves.read_save(w.life.save_path)
		var upgraded=preload("res://main.tscn").instantiate()
		root.add_child(upgraded)
		check(upgraded.village.shoreline.inland(Vector2(saved_field))>1.3 and absf(upgraded.life.beds[0].position.y-.055)<.01,"Migration protects a cultivated cell beneath the new spring")
		check(upgraded.life.Saves.read_save(upgraded.life.save_path+".pre070")==original,"Original world retained during migration")
		upgraded.free()
	if not out.is_empty():
		RenderingServer.render_loop_enabled=true
		w.hud.hide()
		w.graphics.hide()
		w.pad.hide()
		w.apply_graphics(1)
		w.update_solar_lighting(.23)
		w.camera.size=83
		w.camera.position=Vector3(8,66,48)
		w.camera.look_at(Vector3(0,2,0))
		await process_frame
		await RenderingServer.frame_post_draw
		var frame:=root.get_texture().get_image()
		check(frame!=null and frame.save_png(out.path_join(args[0]+".png"))==OK,"Save map overview")
		if not relief.falls.is_empty():
			var foot: Vector3=relief.falls[0]
			var view:=foot+Vector3(0,2.2,0)
			w.camera.size=18
			w.camera.position=view+Vector3(shore.side*11,7.5,9)
			w.camera.look_at(view)
			await RenderingServer.frame_post_draw
			check(root.get_texture().get_image().save_png(out.path_join(args[0]+"-falls.png"))==OK,"Save waterfall capture")
	w.atmosphere.set_outdoors(false)
	if not out.is_empty(): await create_timer(.35).timeout
	w.queue_free()
	await process_frame
	await process_frame
	if not out.is_empty(): await create_timer(.3).timeout
	print(args[0]," · world polish failures: ",failures)
	quit(1 if failures else 0)
