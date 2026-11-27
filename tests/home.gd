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
	w.home_ui.open()
	w.home_ui.build("chest")
	for i in 30: w.site.camera_step(0.02)
	verify(w.site.blend==1 and w.camera.rotation.x < -1.2,"blueprint camera")
	w.site.pick(Vector2i(-12,2))
	verify(not w.site.confirm(),"invalid land")
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
	print("Home integration failures: ",errors)
	quit(1 if errors else 0)
