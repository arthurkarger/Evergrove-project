extends SceneTree

var failures:=0
func check(ok: bool,detail: String) -> void:
	if not ok:
		printerr("FAIL: ",detail)
		failures+=1

func _initialize() -> void:
	call_deferred("run")

func finger(w,index: int,pos: Vector2,pressed: bool) -> void:
	var e:=InputEventScreenTouch.new()
	e.index=index
	e.position=pos
	e.pressed=pressed
	w.route_game_touch(e)

func run() -> void:
	var w=preload("res://main.tscn").instantiate()
	root.add_child(w)
	await process_frame
	await process_frame
	w.hud.run_button.show()
	var start:=Vector2(90,340)
	var run_pos: Vector2=w.hud.run_button.get_global_rect().get_center()
	var slot_pos: Vector2=w.hud.quick[2].get_global_rect().get_center()
	finger(w,0,start,true)
	var drag:=InputEventScreenDrag.new()
	drag.index=0
	drag.position=start+Vector2(45,0)
	w.route_game_touch(drag)
	finger(w,1,run_pos,true)
	finger(w,2,slot_pos,true)
	check(w.pad.finger==0 and w.touch.x>0.7 and w.touch_buttons.size()==2,"Three independent fingers")
	finger(w,1,run_pos,false)
	check(w.hud.run_button.button_pressed and w.touch.x>0.7,"Running while moving")
	finger(w,2,slot_pos,false)
	check(w.life.bag.selected==2 and w.touch.x>0.7,"Tool selection while moving")
	finger(w,0,start,false)
	check(w.touch==Vector2.ZERO and w.pad.finger==-1 and w.touch_buttons.is_empty(),"Independent release")
	w.village.update_weather(Vector3(1,1,1))
	for mat in [w.village.water_simple,w.village.water_clear]:
		check(is_equal_approx(float(mat.get_shader_parameter("water_rain")),1.0),"Rain reaches water shader")
		check(is_equal_approx(float(mat.get_shader_parameter("water_wind")),1.0),"Wind reaches water shader")
	print("Water and multitouch failures: ",failures)
	quit(1 if failures else 0)
