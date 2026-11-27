extends Node3D

const Bag = preload("res://backpack.gd")
const DAY_SECONDS := 180.0
const SAVE := "user://homestead-v1.json"
const FIELD := Vector2(3.1,4.6)
const LABELS := {"wood":"Cortar tronco","stone":"Quebrar rocha","twig":"Pegar graveto","fruit":"Pegar fruta","flower":"Colher flor"}
const REQUIRED := {"wood":"axe","stone":"pick"}
var bag := Bag.new()
var day := 1
var clock := 0.0 # Starts at 06:00.
var plots: Array = []
var resources: Array = []
var dormant := {}
var beds: Array[Node3D] = []
var marker := MeshInstance3D.new()
var shapes := {}
var materials := {}
var target := -1 # Plots first, then forage sites.
var saved_position := Vector3(0,0.5,6)
var social := preload("res://social.gd").new()
var room := -1
var room_pos := Vector2(0,2.2)
var save_failed := false

func _ready() -> void:
	var sphere := SphereMesh.new()
	sphere.radius = 0.5
	sphere.height = 1
	sphere.radial_segments = 8
	sphere.rings = 3
	shapes = {"box":BoxMesh.new(),"round":sphere}
	for i in 12:
		plots.append({"soil":false,"growth":-1,"water":false})
		var bed := Node3D.new()
		add_child(bed)
		bed.position = Vector3(FIELD.x+(i%4)*1.25,0.055,FIELD.y+floori(i/4.0)*1.25)
		beds.append(bed)
	var locations := {
		"wood":[Vector2(-6,6),Vector2(-17,6),Vector2(-24,-6),Vector2(10,14)],
		"stone":[Vector2(1,8),Vector2(17,-14),Vector2(24,4),Vector2(-18,16)],
		"fruit":[Vector2(-19,5),Vector2(-24,9),Vector2(-19,15),Vector2(-5,4)],
		"twig":[Vector2(-1,6),Vector2(-10,10),Vector2(10,5),Vector2(20,11)],
		"flower":[Vector2(2,2),Vector2(-14,-3),Vector2(12,-5),Vector2(15,4)]}
	for id in locations:
		for p: Vector2 in locations[id]:
			spawn_resource(id,p)
	var ring := TorusMesh.new()
	ring.inner_radius = 0.42
	ring.outer_radius = 0.49
	ring.rings = 20
	ring.ring_segments = 4
	marker.mesh = ring
	marker.material_override = material("ffe4a2")
	marker.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(marker)
	marker.hide()
	load_progress()
	for i in beds.size(): draw_bed(i)
	refresh_resources()

func material(color: String) -> StandardMaterial3D:
	if not materials.has(color):
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color(color)
		materials[color] = mat
	return materials[color]

func part(parent: Node3D, shape: String, offset: Vector3, size: Vector3, color: String) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.mesh = shapes[shape]
	node.material_override = material(color)
	node.position = offset
	node.scale = size
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(node)
	return node

func spawn_resource(id: String, p: Vector2) -> void:
	var node := Node3D.new()
	add_child(node)
	node.position = Vector3(p.x,0.09,p.y)
	resources.append({"id":id,"node":node})
	match id:
		"wood":
			part(node,"round",Vector3(0,0.23,0),Vector3(1.15,0.55,0.55),"835a40")
			part(node,"round",Vector3(0.5,0.23,0),Vector3(0.17,0.38,0.38),"d8aa76")
		"stone":
			part(node,"round",Vector3(0,0.26,0),Vector3(0.94,0.8,0.88),"839398")
			part(node,"round",Vector3(0.32,0.15,0.2),Vector3(0.5,0.38,0.48),"a8b3ae")
		"twig":
			part(node,"box",Vector3(0,0.09,0),Vector3(0.76,0.13,0.12),"866040").rotation.y = 0.36
			part(node,"box",Vector3(0.12,0.1,0.09),Vector3(0.34,0.11,0.1),"927051").rotation.y = -0.7
		"fruit":
			part(node,"round",Vector3(0,0.23,0),Vector3.ONE*0.52,"d8774f")
			part(node,"round",Vector3(0.1,0.5,0),Vector3(0.28,0.09,0.14),"54723e")
		"flower":
			for j in 3:
				var v := Vector3(cos(j*2.1)*0.2,0,sin(j*2.1)*0.2)
				part(node,"box",v+Vector3.UP*0.2,Vector3(0.07,0.4,0.07),"598451")
				part(node,"round",v+Vector3.UP*0.43,Vector3(0.35,0.23,0.35),"e99fb0")

func draw_bed(i: int) -> void:
	var bed := beds[i]
	for child in bed.get_children():
		bed.remove_child(child)
		child.queue_free()
	var crop: Dictionary = plots[i]
	var color := "b3ae77"
	if crop.soil: color = "75543d" if crop.water else "a57c50"
	part(bed,"box",Vector3.ZERO,Vector3(1.14,0.07,1.14),color)
	if crop.soil:
		for dx in [-0.32,0.0,0.32]:
			part(bed,"box",Vector3(dx,0.045,0),Vector3(0.08,0.03,0.87),"624b38" if crop.water else "846140")
	if crop.growth >= 0:
		var k := 0.48+int(crop.growth)*0.27
		for dx in [-0.17,0.17]:
			part(bed,"round",Vector3(dx*k,0.22*k,0),Vector3(0.31,0.46,0.21)*k,"608a51").rotation.z = -signf(dx)*0.64
		if crop.growth >= 2:
			part(bed,"round",Vector3(0,0.18,0.13),Vector3(0.52,0.36,0.48),"f0dcac")

func refresh_resources() -> void:
	for i in resources.size():
		resources[i].node.visible = not dormant.has(str(i))

func advance(delta: float) -> bool:
	clock += delta
	if clock < DAY_SECONDS: return false
	clock -= DAY_SECONDS
	day += 1
	for i in plots.size():
		var plot: Dictionary = plots[i]
		if plot.water:
			plot.growth = mini(2,int(plot.growth)+1)
			plot.water = false
			draw_bed(i)
	for key in dormant.keys():
		if int(dormant[key]) <= day: dormant.erase(key)
	refresh_resources()
	return true

func find_target(pos: Vector3) -> void:
	target = -1
	var distance := 1.48*1.48
	var best := Vector3.ZERO
	for i in range(beds.size()+resources.size()):
		var node: Node3D = beds[i] if i < beds.size() else resources[i-beds.size()].node
		if not node.visible: continue
		var d := Vector2(pos.x-node.position.x,pos.z-node.position.z).length_squared()
		if d < distance:
			target = i
			distance = d
			best = node.position
	marker.visible = target >= 0
	marker.position = best+Vector3.UP*0.077

func prompt() -> String:
	if target < 0: return "Interagir"
	if target >= beds.size():
		var id: String = resources[target-beds.size()].id
		if REQUIRED.has(id) and bag.held() != REQUIRED[id]:
			return "Equipe "+str(Bag.NAMES[REQUIRED[id]])
		return LABELS[id]
	var p: Dictionary = plots[target]
	if p.growth == 2: return "Colher nabo"
	if not p.soil: return "Preparar terra" if bag.held()=="hoe" else "Equipe Enxada"
	if p.growth < 0: return "Plantar" if bag.held()=="seed" else "Equipe Sementes"
	if p.water: return "Já regado"
	return "Regar" if bag.held()=="can" else "Equipe Regador"

func interact() -> String:
	if target < 0: return ""
	if target >= beds.size():
		var i := target-beds.size()
		var id: String = resources[i].id
		if dormant.has(str(i)): return ""
		if REQUIRED.has(id) and bag.held() != REQUIRED[id]: return prompt()
		if not bag.add(id,1): return "Mochila cheia"
		dormant[str(i)] = day+1
		resources[i].node.hide()
		return "+1 "+str(Bag.NAMES[id])
	var p: Dictionary = plots[target]
	var message := prompt()
	if p.growth == 2:
		var before := bag.slots.duplicate(true)
		if not bag.add("turnip",1) or not bag.add("seed",2):
			bag.slots = before
			return "Abra espaço para nabo e sementes"
		p.growth = -1
		p.water = false
		message = "+1 nabo · +2 sementes"
	elif not p.soil and bag.held()=="hoe": p.soil = true
	elif p.soil and p.growth < 0 and bag.held()=="seed":
		bag.use_one()
		p.growth = 0
	elif p.growth >= 0 and not p.water and bag.held()=="can": p.water = true
	else: return message
	draw_bed(target)
	return message

func save_progress(pos: Vector3) -> void:
	var data := {"version":1,"pos":[pos.x,pos.z],"slots":bag.slots,"quick":bag.selected,"day":day,"clock":clock,"plots":plots,"dormant":dormant,"coins":social.coins,"friends":social.friends,"room":room,"local":[room_pos.x,room_pos.y]}
	var f := FileAccess.open(SAVE+".tmp",FileAccess.WRITE)
	save_failed = true
	if f == null: return
	f.store_string(JSON.stringify(data))
	f.flush()
	var result := f.get_error()
	f.close()
	if result == OK:
		save_failed = DirAccess.rename_absolute(SAVE+".tmp",SAVE) != OK

func load_progress() -> void:
	if not FileAccess.file_exists(SAVE): return
	var data = JSON.parse_string(FileAccess.get_file_as_string(SAVE))
	if not data is Dictionary or data.get("version") != 1: return
	if not data.get("slots") is Array or data.slots.size() != Bag.SIZE: return
	if not data.get("plots") is Array or data.plots.size() != beds.size(): return
	for item in data.slots:
		if item != null and (not item is Dictionary or not Bag.NAMES.has(item.get("id")) or int(item.get("n",0)) < 1): return
		if item != null: item.n = clampi(int(item.n),1,1 if item.id in Bag.TOOLS else Bag.STACK)
	for p in data.plots:
		if not p is Dictionary or not p.has_all(["soil","water","growth"]): return
		p.growth = clampi(int(p.growth),-1,2)
	if not data.get("pos") is Array or data.pos.size()!=2: return
	social.coins = maxi(0,int(data.get("coins",35)))
	social.friends = data.get("friends",{})
	room = clampi(int(data.get("room",-1)),-1,5)
	var local: Array = data.get("local",[0,2.2])
	room_pos = Vector2(clampf(local[0],-3.6,3.6),clampf(local[1],-2.7,2.7))
	bag.slots = data.slots
	bag.selected = clampi(int(data.get("quick",0)),0,Bag.QUICK-1)
	day = maxi(1,int(data.get("day",1)))
	clock = clampf(float(data.get("clock",0)),0,DAY_SECONDS)
	plots = data.plots
	dormant = data.get("dormant",{})
	for key in dormant: dormant[key] = int(dormant[key])
	saved_position = Vector3(clampf(data.pos[0],-30,30),0.51,clampf(data.pos[1],-23,23))
