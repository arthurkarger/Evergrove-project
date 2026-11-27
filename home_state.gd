extends RefCounted

const Bag = preload("res://backpack.gd")
const DOOR := Vector2(-7,21.65)
const NAMES := {"path":"Caminho","fence":"Cerca","bench":"Banco","table":"Mesa","chest":"Baú","arch":"Caramanchão"}
const RECIPES := {"path":{"stone":1},"fence":{"wood":1,"twig":1},"bench":{"wood":2},"table":{"wood":2,"twig":1},"chest":{"wood":3,"stone":1},"arch":{"wood":3,"twig":2}}
var stock := {"bench":1,"chest":1,"path":3}
var objects: Array = []
var expanded := false
var look := [0,0,0,0]

func pack() -> Dictionary:
	return {"stock":stock,"objects":objects,"expanded":expanded,"look":look}

func restore(d: Dictionary) -> void:
	stock=d.get("stock",stock)
	objects=d.get("objects",[])
	expanded=d.get("expanded",false)
	look=d.get("look",look)

func area(room: int) -> Rect2i:
	if room==6: return Rect2i(-1,-2,9 if expanded else 5,4)
	if room==-1: return Rect2i(-4,17,9,5)
	return Rect2i()

func size_of(id: String,r: int) -> Vector2i:
	if id=="arch": return Vector2i(2,2)
	if id in ["bench","fence"]: return Vector2i(2,1) if r%2==0 else Vector2i(1,2)
	return Vector2i.ONE

func rect(obj: Dictionary) -> Rect2i:
	return Rect2i(Vector2i(int(obj.x),int(obj.z)),size_of(obj.id,int(obj.r)))

func at(room: int,cell: Vector2i) -> int:
	for i in objects.size():
		if objects[i].room==room and rect(objects[i]).has_point(cell): return i
	return -1

func valid(room: int,id: String,cell: Vector2i,r: int,skip: int,player: Vector2) -> bool:
	if not NAMES.has(id): return false
	var box := Rect2i(cell,size_of(id,r))
	if not area(room).encloses(box): return false
	if id!="path" and Rect2(Vector2(cell)-Vector2.ONE*0.78,Vector2(box.size)+Vector2.ONE*0.56).has_point(player): return false
	for i in objects.size():
		if i!=skip and objects[i].room==room and rect(objects[i]).intersects(box): return false
	return true

func place(room: int,id: String,cell: Vector2i,r: int,index: int,player: Vector2) -> bool:
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
	if obj.id=="chest" and obj.slots.any(func(item): return item!=null): return false
	stock[obj.id]=int(stock.get(obj.id,0))+1
	objects.remove_at(i)
	return true

func craft(id: String,bag) -> bool:
	for k in RECIPES[id]:
		if bag.quantity(k)<RECIPES[id][k]: return false
	for k in RECIPES[id]: bag.remove_items(k,RECIPES[id][k])
	stock[id]=int(stock.get(id,0))+1
	return true

func transfer(index: int,bag,slot: int,deposit: bool) -> bool:
	var vault := Bag.new()
	vault.slots=objects[index].slots
	var source = bag if deposit else vault
	var dest = vault if deposit else bag
	var item = source.slots[slot]
	if item==null or not dest.add(item.id,int(item.n)): return false
	source.slots[slot]=null
	return true

func expand(wallet) -> bool:
	if expanded or wallet.coins<70: return false
	wallet.coins-=70
	expanded=true
	return true
