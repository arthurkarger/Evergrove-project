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
	check(title.maps.visible,"New game offers map selection")
	title.select_world("pinhal")
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
	var snapshot: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(life.SAVE))
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
	var original:=FileAccess.get_file_as_string(saves.PRIMARY)
	for key in ["brejo","vale","pomar"]:
		check(saves.select(key),"Select another map")
		set_meta("evergrove_map",key)
		var other=preload("res://main.tscn").instantiate()
		root.add_child(other)
		check(other.life.map_id==key and other.life.house.objects.is_empty() and other.village.house_centers.size()==1,"Independent new world")
		other.free()
	check(saves.select("pinhal") and FileAccess.get_file_as_string(saves.PRIMARY)==original,"Original save preserved across map selection")
