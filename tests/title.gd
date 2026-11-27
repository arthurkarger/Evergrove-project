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
	var wizard=title.wizard
	check(wizard.visible and wizard.stage=="slots","Jogar opens slots")
	wizard.create(1)
	wizard.profile.name="Sol"
	var touch:=InputEventScreenTouch.new()
	touch.index=2
	touch.pressed=true
	wizard.turn_preview(touch)
	var drag:=InputEventScreenDrag.new()
	drag.index=3
	drag.relative=Vector2(20,0)
	wizard.turn_preview(drag)
	check(wizard.rotation_angle==0,"Second finger leaves preview stationary")
	drag.index=2
	wizard.turn_preview(drag)
	check(wizard.rotation_angle>0,"Preview follows its own finger")
	wizard.cycle("skin",6)
	wizard.look[1]=2
	wizard.cycle("eye_color",5)
	wizard.next_from_character()
	check(wizard.stage=="world" and wizard.thumbnails.size()==4,"Four initial maps")
	wizard.selected_map="pinhal"
	wizard.world_name="Ilha Azul"
	wizard.finish()
	await create_timer(0.8).timeout
	check(is_instance_valid(current_scene) and current_scene.scene_file_path=="res://main.tscn","Jogar loads gameplay")
	if is_instance_valid(current_scene) and current_scene.scene_file_path=="res://main.tscn":
		check(current_scene.quality_level==0,"Menu graphics quality used in gameplay")
		check_frontier(current_scene)
		current_scene.graphics.open()
		current_scene.graphics.return_to_title()
		await process_frame
		await process_frame
		check(is_instance_valid(current_scene) and current_scene.scene_file_path=="res://title.tscn","Pause returns to main menu")
	if is_instance_valid(current_scene) and current_scene.scene_file_path=="res://title.tscn":
		var again=current_scene.wizard
		current_scene.choose_world()
		again.confirm_delete(3)
		again.back()
		check(preload("res://world_saves.gd").occupied(3),"Cancel deletion retains world")
		again.confirm_delete(3)
		again.remove_slot(3)
		check(not preload("res://world_saves.gd").occupied(3),"Confirm deletion clears world")
	print("Title menu integration failures: ",failures)
	quit(1 if failures else 0)

func check_frontier(w) -> void:
	var maps=preload("res://natural_maps.gd")
	var layouts: Array=[]
	for key in maps.MAPS:
		var layout=maps.new(key,maps.MAPS[key][1])
		check(not layout.trees.is_empty() and layout.shoreline.terrain_at(layout.shoreline.lake)=="freshwater","Natural terrain "+key)
		check(not layouts.has(layout.shoreline.lake),"Distinct waterways")
		layouts.append(layout.shoreline.lake)
		var shore=layout.shoreline
		# Sample the entire channel at quarter-unit intervals, including the lake
		# junction, all the way from ocean to the rounded upstream head.
		for i in range(-160,roundi(shore.river_end()*4)+1):
			var z:=float(i)*.25
			check(shore.inland(Vector2(shore.river_center(z),z))<0,"Continuous channel "+key+" at "+str(z))
		check(shore.coast(Vector2(shore.river_center(-40),-40))<0,"Channel reaches sea "+key)
		check(shore.inland(Vector2(shore.river_center(18),18))>1.35,"Dry southern crossing "+key)
		check(shore.inland(shore.lake)<0,"Lake connected "+key)
	var life=w.life
	var s=life.settlement
	check(w.village.house_centers.size()==1 and w.town.actors.is_empty(),"Single starter cottage")
	check(life.map_id=="pinhal" and w.village.world_grid.seed_value==419,"Map choice")
	check(s.metrics(life).stars==1 and s.stages.is_empty(),"Initial reputation")
	life.social.coins=500
	var h=life.house
	h.stock.shop=1
	var cell:=Vector2i(-8,8)
	check(h.place(-1,"shop",cell,1,-1,Vector2.ZERO),"Free commercial plot")
	w.save_game()
	check(s.stages.get("merchant")=="visitor","Merchant arrives")
	w.home_ui.meet("merchant")
	w.home_ui.invite()
	var obj: Dictionary=h.objects.back()
	w.home_ui.assign_plot(obj)
	check(s.stages.get("merchant")=="materials" and not s.fund(obj,life),"Material requirement")
	life.bag.add("wood",8)
	life.bag.add("stone",5)
	w.home_ui.fund(obj)
	check(life.social.coins==465 and not s.fund(obj,life),"Payment exactly once")
	var snapshot: Dictionary=life.Saves.read_save(life.save_path)
	check(snapshot.house.objects.back().due==life.day+1 and snapshot.world.id=="pinhal","Pending work persisted")
	life.advance(life.DAY_SECONDS)
	w.save_game()
	check(s.stages.get("merchant")=="installed" and obj.complete,"Next-day move-in")
	check(w.site.settlers.has_node("merchant"),"Resident present")
	w.home_ui.meet("merchant")
	w.home_ui.shop()
	check(w.village_menu.shop_panel.visible,"Shop benefit")
	w.village_menu.close()
	s.stats.species=20
	s.stats.harvest=30
	s.advance(life)
	check(not s.stages.has("fisher") and not s.stages.has("cook"),"Unavailable systems stay locked")
	var outside: Vector2=w.site.entrance(obj)
	w.player.position=w.town.outdoor(outside)+Vector3.UP*0.51
	w.use_item()
	check(life.room==8,"Enter rotated shop")
	var copy=preload("res://main.tscn").instantiate()
	root.add_child(copy)
	check(copy.life.map_id=="pinhal" and copy.life.settlement.stages.get("merchant")=="installed" and copy.site.settlers.has_node("merchant"),"Resume settlement")
	check(copy.life.room==8 and copy.door(8).distance_to(outside)<0.01,"Restore building entrance")
	copy.player.position=copy.town.origin(8)+Vector3(0,0.51,2.4)
	copy.use_item()
	check(copy.life.room==-1 and copy.player.position.distance_to(copy.town.outdoor(outside))<1,"Exit at own plot")
	copy.free()
	var saves=preload("res://world_saves.gd")
	var original:=FileAccess.get_file_as_string(life.save_path)
	for n in [2,3]:
		saves.current=n
		set_meta("evergrove_map","pinhal")
		var other=preload("res://main.tscn").instantiate()
		root.add_child(other)
		check(other.life.house.objects.is_empty() and other.life.world_name!="Ilha Azul","Same map, independent slot")
		other.free()
	check(saves.erase(2) and not saves.occupied(2) and saves.occupied(3),"Only selected slot erased")
	check(FileAccess.get_file_as_string(life.save_path)==original,"First slot untouched")
	var data: Dictionary=saves.read_save(life.save_path)
	check(data.world_name=="Ilha Azul" and data.profile.name=="Sol" and data.profile.skin==1 and data.profile.eye_color==1 and data.house.look[1]==2,"Identity persisted")
	var legacy:=FileAccess.open(saves.PRIMARY,FileAccess.WRITE)
	legacy.store_string(JSON.stringify(data))
	legacy.close()
	saves.migrate()
	check(saves.read_save(saves.slot(2))==data and not FileAccess.file_exists(saves.PRIMARY),"Migrate complete world to available slot")
	check(saves.write_save(saves.slot(2),data),"Backup rotation")
	var broken:=FileAccess.open(saves.slot(2),FileAccess.WRITE)
	broken.store_string("{")
	broken.close()
	check(saves.read_save(saves.slot(2))==data,"Recover damaged slot")
	saves.current=1
