extends Node3D

const Social = preload("res://social.gd")
const CozyCharacter = preload("res://cozy_character.gd")
const DOORS := [Vector2(-12,-3.8),Vector2(0,-8.8),Vector2(10,-5.8),Vector2(-24,-8.8),Vector2(13,15.2),Vector2(-3,12.3)]
const POINTS := [Vector2(-12,3),Vector2(0,2),Vector2(9,-1),Vector2(-22,1),Vector2(16,15.2),Vector2(16,9),Vector2(15,1),Vector2(-22,12),Vector2(-12,16),Vector2(3,15),Vector2(-3,14.7)]
const MORNING := [7,6,13,9,15]
const AFTERNOON := [12,15,9,12,7]
const HAIR := ["694832","68483b","4d3635","cbc7b2","533a45"]
const COATS := ["ab6365","60848a","8c985b","947150","897193"]
const SKIN := ["ddab85","ae7857","dfae8a","c99170","9f6a51"]
var frontier := false
var graph := AStar2D.new()
var actors: Array[CozyCharacter] = []
var current: Array[int] = []
var next: Array[int] = []
var home: Array[bool] = []
var rooms: Array[Node3D] = []
var materials := {}
var box := BoxMesh.new()

func _ready() -> void:
	if frontier: return
	for i in DOORS.size(): graph.add_point(i,DOORS[i])
	for i in POINTS.size(): graph.add_point(i+6,POINTS[i])
	for edge in [[0,6],[1,7],[2,8],[3,9],[4,10],[5,16],[6,7],[6,9],[7,8],[8,12],[12,11],[11,10],[9,13],[13,14],[14,16],[16,15],[11,15]]:
		graph.connect_points(edge[0],edge[1])
	for i in 6:
		build_room(i)
		if i == 5: continue
		var person := CozyCharacter.new()
		person.position = outdoor(DOORS[i])+Vector3.UP*0.93
		add_child(person)
		person.configure(Color(HAIR[i]),Color(COATS[i]),Color(SKIN[i]),i%3,(i+1)%3,-0.93)
		actors.append(person)
		current.append(i)
		next.append(i)
		home.append(true)

func portrait(i: int) -> ImageTexture:
	var img := Image.create(16,24,false,Image.FORMAT_RGBA8)
	img.fill(Color.TRANSPARENT)
	var hair := Color(HAIR[i])
	var shirt := Color(COATS[i])
	var skin := Color(SKIN[i])
	img.fill_rect(Rect2i(4,2,8,9),hair)
	img.fill_rect(Rect2i(5,5,7,6),skin)
	img.fill_rect(Rect2i(4,3,9,3),hair)
	img.fill_rect(Rect2i(4,11,8,8),shirt)
	img.fill_rect(Rect2i(2,12,2,5),skin)
	img.fill_rect(Rect2i(12,12,2,5),skin)
	for x in [5,9]:
		img.set_pixel(x+1,7,Color("383137"))
		img.fill_rect(Rect2i(x,19,3,4),Color("465052"))
		img.fill_rect(Rect2i(x-1,22,4,2),Color("574337"))
	match i:
		0:
			img.fill_rect(Rect2i(2,6,3,7),hair)
			img.fill_rect(Rect2i(3,4,3,3),Color("f6cf97"))
		1:
			img.fill_rect(Rect2i(3,2,10,3),Color("5e6955"))
			img.fill_rect(Rect2i(6,12,5,7),Color("8c6a4f"))
		2:
			img.fill_rect(Rect2i(5,0,6,4),Color("f2dfbf"))
			img.fill_rect(Rect2i(5,15,6,4),Color("ebd5b8"))
		3:
			img.fill_rect(Rect2i(2,3,12,2),Color("a68452"))
			img.fill_rect(Rect2i(6,9,5,2),hair)
		4:
			img.fill_rect(Rect2i(3,0,5,4),hair)
			img.fill_rect(Rect2i(5,11,7,2),Color("cf9d68"))
	return ImageTexture.create_from_image(img)

func outdoor(p: Vector2) -> Vector3:
	return Vector3(p.x,0,p.y)

func origin(i: int) -> Vector3:
	return Vector3(120+i*32,0,0)

func furnish(room: Node3D,pos: Vector3,size: Vector3,tint: String,solid := false) -> void:
	if not materials.has(tint):
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color(tint)
		mat.roughness = 0.95
		mat.metallic_specular = 0.05
		materials[tint] = mat
	var mesh := MeshInstance3D.new()
	mesh.mesh = box
	mesh.material_override = materials[tint]
	mesh.position = pos
	mesh.scale = size
	room.add_child(mesh)
	if solid:
		var body := StaticBody3D.new()
		body.position = pos
		var collision := CollisionShape3D.new()
		var shape := BoxShape3D.new()
		shape.size = size
		collision.shape = shape
		body.add_child(collision)
		room.add_child(body)

func build_room(i: int, template := -1) -> void:
	var style:=i if template<0 else template
	var room := Node3D.new()
	room.position = origin(i)
	add_child(room)
	rooms.append(room)
	var accent := str(Social.PEOPLE[style][4]) if style<5 else "6d8b68"
	furnish(room,Vector3(0,-0.16,0),Vector3(8.2,0.32,6.4),"bc956e",true)
	furnish(room,Vector3(0,1.25,-3.15),Vector3(8.2,2.5,0.22),"e8ce9f",true)
	furnish(room,Vector3(-4,0.55,0),Vector3(0.2,1.1,6.4),"ad8968",true)
	furnish(room,Vector3(4,0.55,0),Vector3(0.2,1.1,6.4),"ad8968",true)
	furnish(room,Vector3(0,0.035,1),Vector3(2.5,0.06,2),accent)
	furnish(room,Vector3(0,1.55,-2.97),Vector3(1.55,1.06,0.12),"95b9b3")
	furnish(room,Vector3(0,1.55,-2.88),Vector3(0.09,1.06,0.06),"f1dcb8")
	if style<5:
		furnish(room,Vector3(-2.5,0.35,-1.3),Vector3(1.55,0.7,2.7),accent,true)
		furnish(room,Vector3(-2.5,0.77,-2.0),Vector3(1.23,0.17,0.65),"f2dfbe")
		furnish(room,Vector3(2.8,0.47,-1.5),Vector3(1.25,0.94,1.15),"886748",true)
	else:
		furnish(room,Vector3(0,0.49,-1.55),Vector3(4.7,0.98,1.05),"92694b",true)
		for j in 5:
			furnish(room,Vector3(j*0.85-1.7,1.16,-1.55),Vector3(0.56,0.34,0.56),["ce965f","a8a775","ab7761","889e93","cfae6f"][j])

func step(delta: float,hour: int,room: int) -> void:
	for i in actors.size():
		var goal: int = i if hour>=19 or hour<6 else (MORNING[i] if hour<12 else AFTERNOON[i])
		var actor := actors[i]
		var walk_direction := Vector2.ZERO
		if current[i]==next[i] and current[i]!=goal:
			var path := graph.get_id_path(current[i],goal)
			next[i] = int(path[1])
		var indoors := goal==i and current[i]==i and next[i]==i
		if indoors:
			actor.position = origin(i)+Vector3(0.8,0.93,-0.55)
		else:
			if home[i]: actor.position = outdoor(DOORS[i])+Vector3.UP*0.93
			var dest := outdoor(graph.get_point_position(next[i]))+Vector3.UP*0.93
			if next[i]==goal and goal!=i:
				dest.x += (i-2)*0.32
			walk_direction = Vector2(dest.x-actor.position.x,dest.z-actor.position.z)
			actor.position = actor.position.move_toward(dest,delta*1.6)
			if actor.position.is_equal_approx(dest): current[i]=next[i]
		home[i]=indoors
		actor.visible = (room==i if indoors else room<0)
		if actor.visible: actor.pose(walk_direction,delta)
