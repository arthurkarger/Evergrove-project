extends Node3D

var world
var state
var cabin := Node3D.new()
var props := Node3D.new()
var grid := MeshInstance3D.new()
var shader_mat := ShaderMaterial.new()
var ghost_mat := StandardMaterial3D.new()
var ghost: Node3D
var active := false
var blend := 0.0
var pan := Vector3.ZERO
var cell := Vector2i.ZERO
var index := -1
var kind := ""
var turns := 0
var valid := false
var failure_reason := ""
var footprint_mesh := MeshInstance3D.new()
var footprint_material := StandardMaterial3D.new()
const Grid = preload("res://world_grid.gd")

func setup(game) -> void:
	world=game
	state=game.life.house
	add_child(cabin)
	cabin.position=game.town.origin(6)
	add_child(props)
	room_geometry()
	refresh()
	var shader := Shader.new()
	shader.code="""shader_type spatial;
render_mode unshaded,cull_disabled,shadows_disabled,depth_draw_never;
uniform vec2 squares;
uniform float fade;
void fragment(){
	vec2 uv=UV*squares;
	vec2 edge=min(fract(uv),1.0-fract(uv));
	vec2 aa=smoothstep(vec2(0.0),max(fwidth(uv)*1.5,vec2(0.02)),edge);
	float line=1.0-min(aa.x,aa.y);
	ALBEDO=mix(vec3(0.04,0.16,0.29),vec3(0.74,0.97,1.0),line);
	ALPHA=(0.54+0.43*line)*fade;
}"""
	shader_mat.shader=shader
	grid.material_override=shader_mat
	grid.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(grid)
	grid.hide()
	footprint_material.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA
	footprint_material.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
	footprint_mesh.mesh=PlaneMesh.new()
	footprint_mesh.material_override=footprint_material
	footprint_mesh.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(footprint_mesh)
	footprint_mesh.hide()
	ghost_mat.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA
	ghost_mat.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED

func clear(root: Node3D) -> void:
	for child in root.get_children():
		root.remove_child(child)
		child.queue_free()

func room_geometry() -> void:
	clear(cabin)
	var extra := 4.0 if state.expanded else 0.0
	var t=world.town
	t.furnish(cabin,Vector3(extra/2,-0.16,0),Vector3(8.3+extra,0.32,6.5),"bb9571",true)
	t.furnish(cabin,Vector3(extra/2,1.2,-3.18),Vector3(8.3+extra,2.4,0.2),"e7cea6",true)
	for x in [-4.03,4.03+extra]:
		t.furnish(cabin,Vector3(x,0.5,0),Vector3(0.16,1,6.5),"97785c",true)
	t.furnish(cabin,Vector3(0,1.55,-3.02),Vector3(1.55,1.1,0.12),"93b9b7")
	t.furnish(cabin,Vector3(0,0.03,2.4),Vector3(1.55,0.05,1.12),"91a079")
	t.furnish(cabin,Vector3(-2.85,0.34,-1.35),Vector3(1.55,0.68,2.4),"815f45",true)
	t.furnish(cabin,Vector3(-2.85,0.73,-1.2),Vector3(1.52,0.22,1.97),"709397")
	t.furnish(cabin,Vector3(-2.85,0.77,-2.13),Vector3(1.25,0.23,0.47),"efdfbd")

func base(room: int) -> Vector3:
	return cabin.position if room==6 else Vector3.ZERO

func model(id: String,preview: bool) -> Node3D:
	var node := Node3D.new()
	var t=world.town
	match id:
		"path": t.furnish(node,Vector3.UP*0.045,Vector3(0.96,0.08,0.96),"bbad91")
		"chest":
			t.furnish(node,Vector3.UP*0.34,Vector3(0.88,0.68,0.76),"92704e",not preview)
			t.furnish(node,Vector3.UP*0.72,Vector3(0.94,0.16,0.8),"bc9568")
			t.furnish(node,Vector3(0,0.57,0.395),Vector3(0.14,0.18,0.06),"e6c482")
		"table","bench":
			var w := 1.82 if id=="bench" else 0.92
			for x in [-w*0.36,w*0.36]: t.furnish(node,Vector3(x,0.25,0),Vector3(0.2,0.5,0.65),"94704c")
			t.furnish(node,Vector3.UP*0.54,Vector3(w,0.15,0.8),"c19768",not preview)
			if id=="bench": t.furnish(node,Vector3(0,0.83,-0.31),Vector3(w,0.37,0.13),"a88052")
		"fence":
			for x in [-0.84,0.84]: t.furnish(node,Vector3(x,0.5,0),Vector3(0.2,1,0.2),"93704d")
			for y in [0.35,0.72]: t.furnish(node,Vector3(0,y,0),Vector3(1.88,0.16,0.14),"b79469",not preview)
		"flower","shrub","lamp","fountain":
			garden_model(node,id,preview)
		"arch":
			for x in [-0.78,0.78]:
				for z in [-0.78,0.78]: t.furnish(node,Vector3(x,0.95,z),Vector3(0.17,1.9,0.17),"957553",not preview)
				t.furnish(node,Vector3(x,1.95,0),Vector3(0.18,0.16,1.96),"92724f")
			for z in [-0.83,-0.28,0.28,0.83]: t.furnish(node,Vector3(0,2.07,z),Vector3(1.97,0.12,0.2),"aaad80")
	if preview:
		for m in node.get_children():
			if m is MeshInstance3D:
				m.material_override=ghost_mat
				m.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return node

func rounded(parent: Node3D,p: Vector3,s: Vector3,tint: String,cylinder := false) -> void:
	var m := MeshInstance3D.new()
	if cylinder:
		var shape := CylinderMesh.new()
		shape.radial_segments=24
		shape.height=1.0
		m.mesh=shape
	else:
		var shape := SphereMesh.new()
		shape.radial_segments=12
		shape.rings=6
		m.mesh=shape
	var mat := StandardMaterial3D.new()
	mat.albedo_color=Color(tint)
	mat.roughness=0.9
	m.material_override=mat
	m.position=p
	m.scale=s
	parent.add_child(m)

func prop_collision(node: Node3D,p: Vector3,size: Vector3) -> void:
	var body := StaticBody3D.new()
	body.position=p
	var collider := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size=size
	collider.shape=shape
	body.add_child(collider)
	node.add_child(body)

func garden_model(node: Node3D,id: String,preview: bool) -> void:
	var t=world.town
	match id:
		"flower":
			rounded(node,Vector3(0,0.12,0),Vector3(0.83,0.24,0.83),"a88963",true)
			for i in 5:
				var a := i*TAU/5
				var p := Vector3(cos(a)*0.25,0.32,sin(a)*0.25)
				rounded(node,p,Vector3(0.25,0.38,0.25),"69984f")
				rounded(node,p+Vector3.UP*0.15,Vector3(0.23,0.16,0.23),["f6cf75","eaa3a0","f9e6bb"][i%3])
		"shrub":
			for p in [Vector3(-0.19,0.34,0),Vector3(0.19,0.35,0),Vector3(0,0.51,0)]:
				rounded(node,p,Vector3(0.63,0.68,0.62),"67964c" if p.y<0.5 else "91b95c")
			if not preview: prop_collision(node,Vector3(0,0.24,0),Vector3(0.62,0.48,0.62))
		"lamp":
			rounded(node,Vector3.UP*0.1,Vector3(0.38,0.2,0.38),"454d44",true)
			t.furnish(node,Vector3.UP*0.85,Vector3(0.13,1.65,0.13),"454d44",not preview)
			t.furnish(node,Vector3.UP*1.77,Vector3(0.35,0.34,0.35),"ffe0a1")
			rounded(node,Vector3.UP*2,Vector3(0.47,0.17,0.47),"454d44",true)
		"fountain":
			rounded(node,Vector3.UP*0.19,Vector3(2.8,0.38,2.8),"bcb39d",true)
			rounded(node,Vector3.UP*0.40,Vector3(2.43,0.08,2.43),"6eb5c4",true)
			rounded(node,Vector3.UP*0.70,Vector3(0.42,0.69,0.42),"e6d8bd",true)
			rounded(node,Vector3.UP*1.03,Vector3(1.15,0.19,1.15),"e6d8bd",true)
			rounded(node,Vector3.UP*1.16,Vector3(0.96,0.08,0.96),"8acdd4",true)
			for i in 8:
				var a := i*TAU/8
				rounded(node,Vector3(cos(a)*0.8,0.62,sin(a)*0.8),Vector3(0.08,0.35,0.08),"bde9ec")
			if not preview: prop_collision(node,Vector3.UP*0.22,Vector3(2.5,0.44,2.5))

func locate(node: Node3D,room: int,tile: Vector2i,id: String,r: int) -> void:
	var center := Grid.cell_center(tile,state.size_of(id,r))
	node.position=base(room)+Vector3(center.x,0.06,center.y)
	node.rotation.y=r*PI/2

func refresh() -> void:
	clear(props)
	for obj in state.objects:
		var node := model(obj.id,false)
		props.add_child(node)
		locate(node,int(obj.room),Vector2i(int(obj.x),int(obj.z)),obj.id,int(obj.r))

func begin(id: String) -> void:
	active=true
	var area: Rect2i=state.area(world.life.room)
	cell=Grid.world_to_cell(player_flat()) if world.life.room==-1 else area.position+area.size/2
	pan=base(world.life.room)+Vector3(cell.x,0,cell.y)
	var plane := PlaneMesh.new()
	plane.size=Vector2(area.size)
	grid.mesh=plane
	grid.position=base(world.life.room)+Vector3(area.position.x+(area.size.x-1)*0.5,0.18,area.position.y+(area.size.y-1)*0.5)
	shader_mat.set_shader_parameter("squares",Vector2(area.size))
	grid.show()
	reset_selection(id)

func reset_selection(id: String) -> void:
	if index>=0 and index<props.get_child_count(): props.get_child(index).show()
	index=-1
	kind=id
	turns=0
	new_ghost()

func new_ghost() -> void:
	if is_instance_valid(ghost):
		remove_child(ghost)
		ghost.queue_free()
	ghost=null
	if kind!="":
		ghost=model(kind,true)
		add_child(ghost)
	update_preview()

func player_flat() -> Vector2:
	var p: Vector3=world.player.position-base(world.life.room)
	return Vector2(p.x,p.z)

func update_preview() -> void:
	valid=false
	failure_reason=""
	footprint_mesh.hide()
	if ghost==null: return
	failure_reason=state.placement_reason(world.life.room,kind,cell,turns,index,player_flat())
	if failure_reason=="" and index<0 and int(state.stock.get(kind,0))<=0:
		failure_reason="Sem estoque"
	valid=failure_reason==""
	ghost_mat.albedo_color=Color(0.22,0.99,0.43,0.66) if valid else Color(1,0.16,0.18,0.7)
	locate(ghost,world.life.room,cell,kind,turns)
	ghost.position.y+=0.19
	var size: Vector2i=state.size_of(kind,turns)
	var center := Grid.cell_center(cell,size)
	var plane := footprint_mesh.mesh as PlaneMesh
	plane.size=Vector2(size)-Vector2.ONE*0.035
	footprint_mesh.position=base(world.life.room)+Vector3(center.x,0.20,center.y)
	footprint_material.albedo_color=Color(0.27,0.9,0.36,0.62) if valid else Color(0.94,0.16,0.18,0.65)
	footprint_mesh.show()

func pick(tile: Vector2i) -> void:
	cell=tile
	if kind=="":
		index=state.at(world.life.room,cell)
		if index>=0:
			var obj: Dictionary=state.objects[index]
			kind=obj.id
			turns=int(obj.r)
			cell=Vector2i(int(obj.x),int(obj.z))
			props.get_child(index).hide()
			new_ghost()
	else: update_preview()

func confirm() -> bool:
	if not valid or not state.place(world.life.room,kind,cell,turns,index,player_flat()): return false
	reset_selection("")
	refresh()
	world.save_game()
	return true

func stop() -> void:
	active=false
	reset_selection("")

func ray(screen: Vector2) -> Vector3:
	var camera: Camera3D=world.camera
	var start := camera.project_ray_origin(screen)
	var dir := camera.project_ray_normal(screen)
	return start+dir*((grid.position.y-start.y)/dir.y)

func bound_pan() -> void:
	var area: Rect2i=state.area(world.life.room)
	var origin:=base(world.life.room)
	pan.x=clampf(pan.x,origin.x+area.position.x-2,origin.x+area.end.x+1)
	pan.z=clampf(pan.z,origin.z+area.position.y-2,origin.z+area.end.y+1)

func camera_step(delta: float) -> void:
	blend=move_toward(blend,1.0 if active else 0.0,delta*2.8)
	var b := smoothstep(0,1,blend)
	var center: Vector3=world.player.position.lerp(pan,b)
	var offset := Vector3(0,10,10).lerp(Vector3(0,15,3),b)
	world.camera.position=world.camera.position.lerp(center+offset,1-exp(-delta*10))
	world.camera.rotation.x=lerpf(-PI/4,-atan2(15,3),b)
	world.camera.size=lerpf(15,10,b)
	shader_mat.set_shader_parameter("fade",b)
	grid.visible=blend>0
