extends RefCounted

const Bag = preload("res://backpack.gd")
const Grid = preload("res://world_grid.gd")
const Starter = preload("res://starter_layout.gd")
var world_grid = Starter.new_grid()
const DOOR := Vector2(-7,21.65)
const NAMES := {"workbench":"Bancada","house":"Terreno residencial","shop":"Terreno comercial","tree":"Árvore","path":"Caminho","fence":"Cerca","bench":"Banco","table":"Mesa","chest":"Baú","arch":"Caramanchão","flower":"Canteiro","shrub":"Arbusto","lamp":"Poste","fountain":"Fonte"}
const RECIPES := {"axe": {"twig": 2, "stone": 2}, "pick": {"twig": 3, "fiber": 2}, "hoe": {"twig": 2, "stone": 1}, "can": {"clay": 2, "fiber": 1}, "shovel": {"twig": 2, "stone": 2}, "rod": {"twig": 3, "fiber": 2}, "iron_axe": {"axe": 1, "iron": 3, "wood": 2}, "iron_pick": {"pick": 1, "iron": 3, "wood": 2}, "iron_hoe": {"hoe": 1, "iron": 3, "wood": 2}, "iron_can": {"can": 1, "iron": 3, "wood": 2}, "iron_shovel": {"shovel": 1, "iron": 3, "wood": 2}, "iron_rod": {"rod": 1, "iron": 3, "wood": 2}, "workbench": {"wood": 4, "stone": 2},"house":{"twig":2},"shop":{"twig":3},"tree":{"fruit":1,"twig":2},"path":{"stone":1},"fence":{"wood":1,"twig":1},"bench":{"wood":2},"table":{"wood":2,"twig":1},"chest":{"wood":3,"stone":1},"arch":{"wood":3,"twig":2},"flower":{"flower":2},"shrub":{"twig":3,"flower":1},"lamp":{"wood":2,"stone":2},"fountain":{"stone":6,"wood":1}}
var stock := {"bench":1,"chest":1,"path":3}
var objects: Array = []
var made:=0
var expanded := false
var look := [0,0,0,0]

func pack() -> Dictionary:
	return {"made":made,"stock":stock,"objects":objects,"expanded":expanded,"look":look,"grid_schema":2}

func restore(d: Dictionary) -> void:
	made=int(d.get("made",0))
	stock=d.get("stock",stock)
	objects=d.get("objects",[])
	expanded=d.get("expanded",false)
	look=d.get("look",look)

func area(room: int) -> Rect2i:
	if room==6: return Rect2i(-1,-2,9 if expanded else 5,4)
	if room==-1: return world_grid.bounds
	return Rect2i()

func size_of(id: String,r: int) -> Vector2i:
	return Grid.footprint(id,r)

func rect(obj: Dictionary) -> Rect2i:
	return Rect2i(Vector2i(int(obj.x),int(obj.z)),size_of(obj.id,int(obj.r)))

func at(room: int,cell: Vector2i) -> int:
	for i in objects.size():
		if objects[i].room==room and rect(objects[i]).has_point(cell): return i
	return -1

func placement_reason(room: int,id: String,cell: Vector2i,r: int,skip: int,player: Vector2) -> String:
	if not NAMES.has(id): return "Objeto desconhecido"
	var box := Rect2i(cell,size_of(id,r))
	if not area(room).encloses(box): return "Fora da área"
	if room!=-1 and id in ["flower","shrub","lamp","fountain","house","shop","tree"]: return "Somente ao ar livre"
	if room==-1:
		var obstacle: String=world_grid.reason(box)
		if obstacle!="": return obstacle
	if id!="path" and Rect2(Vector2(cell)-Vector2.ONE*0.78,Vector2(box.size)+Vector2.ONE*0.56).has_point(player): return "Jogador na área"
	for i in objects.size():
		if i!=skip and objects[i].room==room and rect(objects[i]).intersects(box): return "Espaço ocupado"
	return ""

func valid(room: int,id: String,cell: Vector2i,r: int,skip: int,player: Vector2) -> bool:
	return placement_reason(room,id,cell,r,skip,player)==""

func place(room: int,id: String,cell: Vector2i,r: int,index: int,player: Vector2) -> bool:
	if index < -1 or index>=objects.size(): return false
	if not valid(room,id,cell,r,index,player): return false
	var obj: Dictionary
	if index<0:
		if int(stock.get(id,0))<=0: return false
		stock[id]-=1
		obj={"id":id,"room":room}
		if id=="chest":
			var slots := []
			slots.resize(36)
			obj.slots=slots
		objects.append(obj)
	else:
		obj=objects[index]
		if obj.id!=id or obj.room!=room: return false
	obj.x=cell.x
	obj.z=cell.y
	obj.r=r
	return true

func remove_object(i: int) -> bool:
	var obj: Dictionary=objects[i]
	if obj.get("who","")!="" or obj.has("due") or obj.get("complete",false): return false
	if obj.id=="chest" and obj.slots.any(func(item): return item!=null): return false
	stock[obj.id]=int(stock.get(obj.id,0))+1
	objects.remove_at(i)
	return true

# Simulate on a copy so preview and purchase agree even when ingredients
# release the last inventory slots needed for a batch of tools.
func prepare_craft(id: String,bag,count: int,bench: bool) -> Dictionary:
	if count<1 or not RECIPES.has(id): return {"reason":"Receita inválida."}
	if id.begins_with("iron_") and (made<5 or not bench):
		return {"reason":"Use uma bancada após fabricar 5 itens (%d/5)." % mini(5,made)}
	var result:=Bag.new()
	result.slots=bag.slots.duplicate(true)
	for k in RECIPES[id]:
		if not result.remove_items(k,RECIPES[id][k]*count): return {"reason":"Materiais insuficientes."}
	if id in Bag.TOOLS and not result.add(id,count): return {"reason":"Mochila cheia."}
	return {"reason":"","slots":result.slots}

func craft(id: String,bag,count:=1,bench:=false) -> bool:
	var result:=prepare_craft(id,bag,count,bench)
	if result.reason!="": return false
	bag.slots=result.slots
	if id not in Bag.TOOLS: stock[id]=int(stock.get(id,0))+count
	made+=count
	return true

func transfer(index: int,bag,slot: int,deposit: bool) -> bool:
	var vault := Bag.new()
	vault.slots=objects[index].slots
	var source = bag if deposit else vault
	var dest = vault if deposit else bag
	var item = source.slots[slot]
	if item!=null and item.id in Bag.TOOLS:
		var empty:int=dest.slots.find(null)
		if empty<0: return false
		dest.slots[empty]=item
		source.slots[slot]=null
		return true
	if item==null or not dest.add(item.id,int(item.n)): return false
	source.slots[slot]=null
	return true

func expand(wallet) -> bool:
	if expanded or wallet.coins<70: return false
	wallet.coins-=70
	expanded=true
	return true
