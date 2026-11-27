extends Control
var world: Node3D
var finger := -1
var center := Vector2.ZERO
var offset := Vector2.ZERO
func _ready():
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(queue_redraw)
func _draw():
	if not DisplayServer.is_touchscreen_available():
		return
	var p := Vector2(105,get_viewport_rect().size.y-105) if finger<0 else center
	draw_circle(p,65,Color(0.1,0.15,0.12,0.28))
	draw_arc(p,65,0,TAU,48,Color(1,1,1,0.5),2,true)
	draw_circle(p+offset,25,Color(1,1,1,0.55))
func _input(event):
	if event is InputEventScreenTouch:
		if event.pressed and finger<0 and event.position.x<get_viewport_rect().size.x*0.28 and event.position.y>get_viewport_rect().size.y*0.35:
			finger=event.index
			center=event.position
			queue_redraw()
		elif not event.pressed and event.index==finger:
			finger=-1
			offset=Vector2.ZERO
			world.set("touch",Vector2.ZERO)
			queue_redraw()
	elif event is InputEventScreenDrag and event.index==finger:
		offset=(event.position-center).limit_length(55)
		world.set("touch",offset/55)
		queue_redraw()
