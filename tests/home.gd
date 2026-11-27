extends SceneTree

var errors := 0
func verify(ok: bool,label_text: String) -> void:
	if not ok:
		printerr("FAIL: ",label_text)
		errors+=1

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var scene := preload("res://main.tscn")
	var w=scene.instantiate()
	root.add_child(w)
	await physics_frame
	var h=w.life.house
	var original_day: int=w.life.day
	var grid = preload("res://world_grid.gd").new(Rect2i(-4,-4,9,9),"test_seed",42)
	verify(grid.map_id=="test_seed" and grid.seed_value==42,"independent map descriptor")
	verify(grid.world_to_cell(Vector2(-1.6,0.6))==Vector2i(-2,1),"negative coordinate snap")
	grid.reserve_rect(Rect2i(-1,-1,2,2),"water")
	verify(grid.reason(Rect2i(0,0,2,1))=="water","full footprint blocked")
	verify(grid.reason(Rect2i(4,4,2,1))!="","map edge")
	verify(grid.footprint("bench",1)==Vector2i(1,2),"rotated footprint")
	verify(h.valid(-1,"bench",Vector2i(4,20),0,-1,Vector2(0,6)),"global outdoor placement outside old plot")
	w.hud.run_button.set_pressed_no_signal(true)
	verify(is_equal_approx(w.movement_speed(),6.6),"run speed")
	w.hud.home_requested.emit()
	verify(w.site.active and w.home_ui.board.visible and not w.home_ui.menu.visible,"direct outdoor construction")
	verify(not w.hud.run_button.button_pressed,"run clears on construction")
	w.home_ui.build("chest")
	for i in 30: w.site.camera_step(0.02)
	verify(w.site.blend==1 and w.camera.rotation.x < -1.2,"blueprint camera")
	w.site.pick(Vector2i(-12,2))
	verify(not w.site.confirm(),"invalid land")
	w.site.pick(Vector2i(22,-7))
	verify(not w.site.confirm(),"lake reserved")
	w.site.pick(Vector2i(-7,20))
	verify(not w.site.confirm(),"house reserved")
	w.site.pick(Vector2i(0,18))
	verify(w.site.confirm() and h.objects.size()==1,"outdoor construction")
	w.home_ui.close()
	for i in 30: w.site.camera_step(0.02)
	verify(w.site.blend==0 and is_equal_approx(w.camera.rotation.x,-PI/4),"restore camera")
	w.player.position=Vector3(0,0.51,18.8)
	w.use_item()
	verify(w.home_ui.page=="chest" and w.home_ui.menu.visible,"open outdoor chest")
	h.objects[0].slots[35]={"id":"stone","n":1}
	verify(h.transfer(0,w.life.bag,35,false),"withdraw last chest slot")
	verify(h.transfer(0,w.life.bag,4,true) and not h.remove_object(0),"protect filled chest")
	w.home_ui.close()
	w.home_ui.open()
	w.home_ui.build("")
	w.site.pick(Vector2i(0,18))
	w.site.pick(Vector2i(1,19))
	verify(w.site.confirm() and h.objects[0].slots[0].id=="seed","move loaded chest")
	w.home_ui.close()
	w.player.position=w.town.outdoor(w.door(6))+Vector3.UP*0.51
	w.use_item()
	verify(w.life.room==6,"enter player house")
	w.hud.home_requested.emit()
	verify(w.site.active and w.home_ui.board.visible,"direct indoor construction")
	w.home_ui.close()
	w.player.position=w.site.cabin.position+Vector3(-2.85,0.51,0)
	w.use_item()
	verify(w.life.day==original_day+1 and w.life.clock==0,"sleep")
	w.home_ui.open()
	verify(not h.expand(w.life.social),"price check")
	w.life.social.coins=75
	w.home_ui.expand_room()
	verify(h.expanded and w.life.social.coins==5,"paid expansion")
	verify(not h.craft("table",w.life.bag),"materials check")
	w.life.bag.add("wood",2)
	w.life.bag.add("twig",1)
	verify(h.craft("table",w.life.bag) and w.life.bag.quantity("wood")==0,"craft")
	w.home_ui.change_look(0,3)
	w.home_ui.change_look(2,3)
	w.home_ui.build("bench")
	w.site.pick(Vector2i(7,0))
	verify(not w.site.valid,"footprint edge")
	w.home_ui.rotate_item()
	verify(w.site.confirm(),"rotate into expanded room")
	w.site.reset_selection("table")
	w.site.pick(Vector2i(7,1))
	verify(not w.site.confirm(),"block overlap")
	w.site.pick(Vector2i(5,0))
	verify(w.site.confirm(),"indoor furniture")
	w.site.pick(Vector2i(5,0))
	w.home_ui.remove_item()
	verify(h.stock.table==1 and h.objects.size()==2,"remove to catalog")
	w.home_ui.close()
	w.player.position=w.site.cabin.position+Vector3(6,0.51,0)
	w.save_game()
	var copy=scene.instantiate()
	root.add_child(copy)
	verify(copy.life.room==6 and copy.player.position.distance_to(w.player.position)<0.05 and copy.life.house.expanded,"reload expanded room")
	verify(copy.life.house.objects[0].slots[0].id=="seed" and copy.life.house.objects[1].r==1 and copy.life.house.look[0]==1 and copy.life.house.look[2]==1,"reload storage layout and outfit")
	check_farming(copy)
	print("Home integration failures: ",errors)
	quit(1 if errors else 0)

func check_farming(w) -> void:
	var life=w.life
	life.room=-1
	var bag=life.bag
	var cell:=Vector2i(4,20)
	var pos:=Vector3(cell.x,.51,cell.y)
	bag.selected=2
	life.find_target(pos)
	verify(life.interact()=="Terra preparada","Hoe prepares free cell")
	verify(not life.house.valid(-1,"path",cell,0,-1,Vector2.ZERO),"Crop reserves footprint")
	bag.add("tomato_seed",1)
	for i in bag.slots.size():
		if bag.slots[i]!=null and bag.slots[i].id=="tomato_seed": bag.selected=i
	life.find_target(pos)
	life.interact()
	var plot: Dictionary=life.plots.back()
	verify(plot.crop=="tomato","Seed species stored")
	bag.selected=3
	for day in 5:
		life.find_target(pos)
		life.interact()
		life.advance(life.DAY_SECONDS)
	life.interact()
	verify(bag.quantity("tomato")==1 and plot.growth==3,"Watered tomato harvest and regrowth")
	life.save_progress(pos)
	var resumed=preload("res://main.tscn").instantiate()
	root.add_child(resumed)
	verify(resumed.life.plots.back().crop=="tomato" and resumed.life.plots.back().growth==3,"Persist individual plot")
	resumed.free()
	bag.add("twig",10)
	bag.add("stone",8)
	verify(life.house.craft("shovel",bag,2) and bag.quantity("shovel")==2,"Batch tools")
	for i in bag.slots.size():
		if bag.slots[i]!=null and bag.slots[i].id=="shovel": bag.selected=i
	life.find_target(pos)
	life.interact()
	verify(not life.cell_index.has(cell) and bag.slots[bag.selected].hp==29,"Restore grass and wear shovel")
