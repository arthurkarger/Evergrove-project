extends Node3D

const Bag = preload("res://backpack.gd")
const DAY_SECONDS := 180.0
const Saves = preload("res://world_saves.gd")
const SAVE := "user://slot-1.json"
var profile := {"name":"Morador","skin":0,"eye_shape":0,"eye_color":0}
var world_name := "Evergrove"
var played := 0.0
var save_path := Saves.active()
var lot_exit: Array = []
const CROPS := {"turnip": ["seed", 2, "f2dab9"], "carrot": ["carrot_seed", 3, "ea873c"], "potato": ["potato_seed", 4, "bc9263"], "wheat": ["wheat_seed", 3, "dfbb60"], "tomato": ["tomato_seed", 5, "dc5143"], "berry": ["berry_seed", 4, "cb4564"]}
var cell_index := {}
var aimed := Vector2i.ZERO
const FIELD := Vector2(3.1,4.6)
const LABELS := {"fiber":"Colher fibras","clay":"Escavar argila","iron":"Minerar ferro","wood":"Cortar tronco","stone":"Quebrar rocha","twig":"Pegar graveto","fruit":"Pegar fruta","flower":"Colher flor"}
const REQUIRED := {"clay":"shovel","iron":"pick","wood":"axe","stone":"pick"}
var bag := Bag.new()
var weather:=preload("res://weather.gd").new()
var growth_seconds:=0.0
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
var house := preload("res://home_state.gd").new()
var social := preload("res://social.gd").new()
var settlement := preload("res://settlement.gd").new()
var terrain_options: Dictionary={}
var map_id := "starter_village"
var map_seed := 0
var room := -1
var room_pos := Vector2(0,2.2)
var protect_existing := false
var save_failed := false

func _ready() -> void:
	var sphere := SphereMesh.new()
	sphere.radius = 0.5
	sphere.height = 1
	sphere.radial_segments = 8
	sphere.rings = 3
	shapes = {"box":BoxMesh.new(),"round":sphere}
	var locations := {
		"wood":[Vector2(-6,6),Vector2(-17,6),Vector2(-24,-6),Vector2(10,14)],
		"stone":[Vector2(1,8),Vector2(17,-14),Vector2(24,4),Vector2(-18,16)],
		"fruit":[Vector2(-19,5),Vector2(-24,9),Vector2(-19,15),Vector2(-5,4)],
		"twig":[Vector2(-1,6),Vector2(-10,10),Vector2(10,5),Vector2(20,11)],
		"flower":[Vector2(2,2),Vector2(-14,-3),Vector2(12,-5),Vector2(15,4)]}
	locations["fiber"]=[Vector2(-3,7),Vector2(7,11)]
	locations["clay"]=[Vector2(12,3),Vector2(-18,7)]
	locations["iron"]=[Vector2(14,-12),Vector2(-9,8)]
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
	if get_tree().has_meta("evergrove_map"):
		map_id=get_tree().get_meta("evergrove_map")
		get_tree().remove_meta("evergrove_map")
		map_seed=preload("res://natural_maps.gd").MAPS[map_id][1]
	if get_tree().has_meta("new_resident"):
		var draft: Dictionary=get_tree().get_meta("new_resident")
		get_tree().remove_meta("new_resident")
		profile=draft.profile
		house.look=draft.look
		world_name=draft.world_name
	load_progress()
	for i in plots.size(): attach_bed(i)
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
	var model_id: String={"stone":"river_stones","flower":"wildflowers"}.get(id,"")
	if model_id!="" and preload("res://blender_models.gd").mount(node,model_id): return
	match id:
		"iron","clay","fiber":
			for j in 3:
				var blade:=id=="fiber"
				part(node,"round",Vector3(j*0.16,0.15,j%2*0.1),Vector3(0.12,0.56,0.13) if blade else Vector3(0.45,0.34,0.42),{"fiber":"80aa60","iron":"646c78","clay":"ad7454"}[id])
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

func attach_bed(i: int) -> void:
	var p: Dictionary=plots[i]
	var tile:=Vector2i(int(p.x),int(p.z))
	var bed:=Node3D.new()
	add_child(bed)
	bed.position=Vector3(tile.x,house.world_grid.height_at(Vector2(tile))+.055,tile.y)
	beds.append(bed)
	cell_index[tile]=i
	draw_bed(i)

func crop_for(seed_id: String) -> String:
	for id in CROPS:
		if CROPS[id][0]==seed_id: return id
	return ""

func draw_bed(i: int) -> void:
	var bed := beds[i]
	for child in bed.get_children():
		bed.remove_child(child)
		child.queue_free()
	var crop: Dictionary = plots[i]
	var color := "b3ae77"
	if crop.soil: color = "75543d" if crop.water else "a57c50"
	part(bed,"box",Vector3.ZERO,Vector3(0.96,0.07,0.96),color)
	if crop.soil:
		for dx in [-0.32,0.0,0.32]:
			part(bed,"box",Vector3(dx,0.045,0),Vector3(0.08,0.03,0.87),"624b38" if crop.water else "846140")
	if crop.growth >= 0:
		var id: String=crop.crop
		var fraction:=float(crop.growth)/float(CROPS[id][1])
		var k:=0.35+fraction*0.7
		var tall:=id in ["tomato","wheat"]
		var h:=0.65 if tall else 0.29
		for j in (4 if id in ["berry","wheat"] else 2):
			var a:=j*2.4
			var base:=Vector3(cos(a)*0.2,0,sin(a)*0.2)
			part(bed,"box",base+Vector3.UP*h*k/2,Vector3(.045,h*k,.045),"789652")
			part(bed,"round",base+Vector3(.06,h*k*.7,0),Vector3(.2,.11,.12)*k,"85a95a")
			if fraction>=0.55:
				var size:Vector3={"turnip":Vector3(.33,.25,.32),"carrot":Vector3(.17,.29,.17),"potato":Vector3(.27,.15,.2),"wheat":Vector3(.09,.27,.1),"tomato":Vector3(.22,.2,.21),"berry":Vector3(.14,.17,.14)}[id]
				part(bed,"round",base+Vector3.UP*h*k,size*k,CROPS[id][2])

func refresh_resources() -> void:
	for i in resources.size():
		resources[i].node.visible = not dormant.has(str(i)) and not resources[i].get("unplaced",false)

func advance(delta: float) -> bool:
	var new_day:=false
	while delta>0.000001:
		var step:=minf(delta,minf(weather.remaining,DAY_SECONDS-clock))
		clock+=step
		growth_seconds+=step
		delta-=step
		var dawn:=clock>=DAY_SECONDS-0.000001
		weather.elapse(step)
		var change:=weather.remaining<=0.000001
		if dawn or change or growth_seconds>=1.0:
			grow_plots(dawn)
		if dawn:
			clock=0
			day+=1
			new_day=true
			for key in dormant.keys():
				if int(dormant[key])<=day: dormant.erase(key)
			refresh_resources()
		if change:
			weather.next_period(clock/DAY_SECONDS)
			if weather.rainy(): grow_plots(false)
	return new_day

func grow_plots(dawn: bool) -> void:
	var wet:=weather.rainy()
	var gain:=growth_seconds/DAY_SECONDS*(1.5 if wet else 1.0)
	growth_seconds=0
	for i in plots.size():
		var p: Dictionary=plots[i]
		var old_water: bool=p.water
		var old_stage:=floori(float(p.growth)*2)
		if wet: p.water=true
		if p.water and p.growth>=0:
			var limit:=float(CROPS[p.crop][1])
			p.growth=minf(limit,float(p.growth)+gain)
			if dawn: p.growth=minf(limit,float(p.growth)+float(p.get("dawn_credit",0)))
			if limit-float(p.growth)<0.000001: p.growth=limit
		if dawn:
			p.erase("dawn_credit")
			p.water=wet
		if floori(float(p.growth)*2)!=old_stage:
			draw_bed(i)
		elif old_water!=p.water:
			var bed:=beds[i]
			bed.get_child(0).material_override=material("75543d" if p.water else "a57c50")
			for furrow in range(1,4):
				bed.get_child(furrow).material_override=material("624b38" if p.water else "846140")

func find_target(pos: Vector3) -> void:
	target = -1
	var distance := 1.48*1.48
	var best := Vector3.ZERO
	aimed=Vector2i(roundi(pos.x),roundi(pos.z))
	for i in range(beds.size(),beds.size()+resources.size()):
		var node: Node3D = beds[i] if i < beds.size() else resources[i-beds.size()].node
		if not node.visible or absf(node.position.y-pos.y)>1.45: continue
		var d := Vector2(pos.x-node.position.x,pos.z-node.position.z).length_squared()
		if d < distance:
			target = i
			distance = d
			best = node.position
	if cell_index.has(aimed):
		target=int(cell_index[aimed])
		best=beds[target].position
	elif bag.tool()=="hoe" and room==-1 and house.world_grid.terrain_at(aimed)=="grass" and house.world_grid.reason(Rect2i(aimed,Vector2i.ONE))=="" and house.at(-1,aimed)<0:
		target=beds.size()+resources.size()
		best=Vector3(aimed.x,house.world_grid.height_at(Vector2(aimed))+.06,aimed.y)
	marker.visible = target >= 0
	marker.position = best+Vector3.UP*0.077

func prompt() -> String:
	if target < 0: return "Interagir"
	if target==beds.size()+resources.size(): return "Preparar terra"
	if target >= beds.size():
		var id: String = resources[target-beds.size()].id
		if REQUIRED.has(id) and bag.tool() != REQUIRED[id]:
			return "Equipe "+str(Bag.NAMES[REQUIRED[id]])
		return LABELS[id]
	var p: Dictionary = plots[target]
	if bag.tool()=="shovel": return "Restaurar grama"
	if p.growth>=0 and p.growth==CROPS[p.crop][1]: return "Colher "+str(Bag.NAMES[p.crop])
	if not p.soil: return "Preparar terra" if bag.held()=="hoe" else "Equipe Enxada"
	if p.growth < 0: return "Plantar" if crop_for(bag.held())!="" else "Equipe Sementes"
	if p.water: return "Já regado"
	return "Regar" if bag.tool()=="can" else "Equipe Regador"

func interact() -> String:
	grow_plots(false)
	if target < 0: return ""
	if target==beds.size()+resources.size():
		plots.append({"soil":true,"x":aimed.x,"z":aimed.y,"water":weather.rainy(),"crop":"turnip","growth":-1})
		attach_bed(plots.size()-1)
		bag.wear()
		return "Terra preparada"
	if target >= beds.size():
		var i := target-beds.size()
		var id: String = resources[i].id
		if dormant.has(str(i)): return ""
		if REQUIRED.has(id) and bag.tool() != REQUIRED[id]: return prompt()
		if not bag.add(id,1): return "Mochila cheia"
		if REQUIRED.has(id): bag.wear()
		settlement.count(id)
		dormant[str(i)] = day+1
		resources[i].node.hide()
		return "+1 "+str(Bag.NAMES[id])
	var p: Dictionary = plots[target]
	var message := prompt()
	if bag.tool()=="shovel":
		beds[target].queue_free()
		beds.remove_at(target)
		plots.remove_at(target)
		cell_index.erase(aimed)
		for j in range(target,plots.size()): cell_index[Vector2i(int(plots[j].x),int(plots[j].z))]=j
		bag.wear()
		return "Grama restaurada"
	if int(p.growth)==int(CROPS[p.crop][1]):
		var before := bag.slots.duplicate(true)
		if not bag.add(p.crop,1) or not bag.add(CROPS[p.crop][0],2):
			bag.slots = before
			return "Abra espaço para a colheita e as sementes"
		settlement.count("harvest")
		p.growth = int(CROPS[p.crop][1])-2 if p.crop in ["tomato","berry"] else -1
		p.water = weather.rainy()
		p.erase("dawn_credit")
		message = "+1 "+str(Bag.NAMES[p.crop])+" · +2 sementes"
	elif not p.soil and bag.held()=="hoe": p.soil = true
	elif p.soil and p.growth < 0 and crop_for(bag.held())!="":
		p.crop=crop_for(bag.held())
		bag.use_one()
		p.growth = 0
	elif p.growth >= 0 and not p.water and bag.tool()=="can":
		p.water=true
		p.dawn_credit=clock/DAY_SECONDS
		bag.wear()
	else: return message
	draw_bed(target)
	return message

func save_progress(pos: Vector3) -> void:
	if protect_existing:
		save_failed=true
		return
	grow_plots(false)
	var data := {"weather":weather.pack(),"version":4,"world_name":world_name,"profile":profile,"played":played,"lot_exit":lot_exit,"settlement":{"stats":settlement.stats,"stages":settlement.stages},"world":{"id":house.world_grid.map_id,"seed":house.world_grid.seed_value,"terrain":terrain_options},"pos":[pos.x,pos.z],"slots":bag.slots,"quick":bag.selected,"day":day,"clock":clock,"plots":plots,"dormant":dormant,"house":house.pack(),"coins":social.coins,"friends":social.friends,"room":room,"local":[room_pos.x,room_pos.y]}
	save_failed=not Saves.write_save(save_path,data)

func load_progress() -> void:
	if not Saves.occupied(Saves.current): return
	protect_existing=true
	var data:=Saves.read_save(save_path)
	if data.is_empty(): return
	if not data.get("slots") is Array or data.slots.size() != Bag.SIZE: return
	if not data.get("plots") is Array: return
	for item in data.slots:
		if item != null and (not item is Dictionary or not Bag.NAMES.has(item.get("id")) or int(item.get("n",0)) < 1): return
		if item != null: item.n = clampi(int(item.n),1,1 if item.id in Bag.TOOLS else Bag.STACK)
	for p in data.plots:
		if not p is Dictionary or not p.has_all(["soil","water","growth"]): return
		p.crop=p.get("crop","turnip")
		if not CROPS.has(p.crop): return
		p.growth=clampf(float(p.growth),-1,float(CROPS[p.crop][1]))
		if p.water and not data.has("weather"): p.dawn_credit=float(data.get("clock",0))/DAY_SECONDS
	if not data.get("pos") is Array or data.pos.size()!=2: return
	var backup:=save_path+".v"+str(int(data.version))
	if int(data.version)<3 and not FileAccess.file_exists(backup):
		if DirAccess.copy_absolute(save_path,backup)!=OK:
			save_failed=true
			return
	weather.restore(data.get("weather",{}))
	profile=data.get("profile",profile)
	world_name=Saves.world_name(data)
	played=maxf(0,float(data.get("played",0)))
	map_id=data.get("world",{}).get("id","starter_village")
	terrain_options=data.get("world",{}).get("terrain",{})
	if Saves.Maps.MAPS.has(map_id) and terrain_options.is_empty() and not FileAccess.file_exists(save_path+".pre070"):
		if not Saves.write_save(save_path+".pre070",Saves.read_save(save_path)):
			save_failed=true
			return
	map_seed=int(data.get("world",{}).get("seed",0))
	var settlement_data: Dictionary=data.get("settlement",{})
	settlement.stats=settlement_data.get("stats",{})
	settlement.stages=settlement_data.get("stages",{})
	social.coins = maxi(0,int(data.get("coins",35)))
	social.friends = data.get("friends",{})
	house.restore(data.get("house",{}))
	room = clampi(int(data.get("room",-1)),-1,8)
	lot_exit=data.get("lot_exit",[])
	var local: Array = data.get("local",[0,2.2])
	room_pos = Vector2(clampf(local[0],-3.6,7.6 if room==6 and house.expanded else 3.6),clampf(local[1],-2.7,2.7))
	bag.slots = data.slots
	bag.selected = clampi(int(data.get("quick",0)),0,Bag.QUICK-1)
	day = maxi(1,int(data.get("day",1)))
	clock = clampf(float(data.get("clock",0)),0,DAY_SECONDS)
	for i in data.plots.size():
		var entry: Dictionary=data.plots[i]
		if not entry.soil: continue
		if not entry.has_all(["x","z"]):
			entry.x=roundi(FIELD.x+i%4*1.25)
			entry.z=roundi(FIELD.y+floori(i/4.0)*1.25)
		plots.append(entry)
	dormant = data.get("dormant",{})
	for key in dormant: dormant[key] = int(dormant[key])
	protect_existing=false
	saved_position = Vector3(clampf(data.pos[0],-44,44),0.51,clampf(data.pos[1],-36,36))
