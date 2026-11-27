extends SceneTree

var failures := 0

func check(ok: bool,label_text: String) -> void:
	if not ok:
		printerr("FAIL: ",label_text)
		failures += 1

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var scene := preload("res://main.tscn")
	var w = scene.instantiate()
	root.add_child(w)
	await physics_frame
	var life = w.life
	var bag = life.bag
	var s = life.social
	check(w.town.actors.size()==5 and w.town.rooms.size()==6,"village population")
	for tick in 120: w.town.step(0.5,10,-1)
	for i in 5: check(w.town.current[i]==w.town.MORNING[i],"morning route")
	for tick in 120: w.town.step(0.5,15,-1)
	for i in 5: check(w.town.current[i]==w.town.AFTERNOON[i],"afternoon route")
	for tick in 120: w.town.step(0.5,22,-1)
	for i in 5: check(w.town.home[i] and not w.town.actors[i].visible,"night return")
	life.clock=life.DAY_SECONDS*16/24.0
	for i in 6:
		w.player.position=w.town.outdoor(w.town.DOORS[i])+Vector3.UP*0.51
		w.use_item()
		check(life.room==i,"enter building")
		if i==0:
			w.player.position=w.town.origin(i)+Vector3(0.8,0.51,0)
			w.use_item()
			check(w.village_menu.shade.visible,"conversation inside")
			w.village_menu.close()
		w.player.position=w.town.origin(i)+Vector3(0,0.51,2.4)
		w.use_item()
		check(life.room==-1,"leave building")
	bag.add("flower",3)
	for i in 24:
		if bag.slots[i]!=null and bag.slots[i].id=="flower":
			bag.move_slot(i,5)
			break
	bag.selected=5
	s.gift(0,bag,1)
	s.gift(0,bag,1)
	check(bag.quantity("flower")==2 and s.record(0).bond==10,"daily talk and gift")
	s.quest(0,bag,1)
	s.quest(0,bag,1)
	s.quest(0,bag,1)
	check(s.coins==51 and bag.quantity("flower")==0,"single quest payment")
	w.player.position=w.town.outdoor(w.town.DOORS[5])+Vector3.UP*0.51
	w.use_item()
	w.player.position=w.town.origin(5)+Vector3(0,0.51,0)
	w.use_item()
	check(w.village_menu.shade.visible and w.village_menu.resident==-1,"shop counter")
	w.village_menu.trade("seed")
	w.village_menu.switch_trade()
	w.village_menu.trade("seed")
	w.village_menu.close()
	check(s.coins==49 and bag.quantity("seed")==8,"buy and sell")
	w.save_game()
	var second = scene.instantiate()
	root.add_child(second)
	check(second.life.room==5 and second.player.position.distance_to(w.player.position)<0.05,"resume inside")
	check(second.life.social.coins==49 and second.life.social.record(0).done==1 and second.life.social.record(0).bond==16,"social save")
	# Load a save in the 0.3 format from an isolated test profile.
	var old: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(life.SAVE))
	for key in ["coins","friends","local","room"]: old.erase(key)
	var file := FileAccess.open(life.SAVE,FileAccess.WRITE)
	file.store_string(JSON.stringify(old))
	file.close()
	var previous = scene.instantiate()
	root.add_child(previous)
	check(previous.life.room==-1 and previous.life.social.coins==35 and previous.life.bag.quantity("seed")==8,"0.3 migration")
	print("Village Life integration failures: ",failures)
	quit(1 if failures else 0)
