extends RefCounted

const NAMES := {"axe":"Machado","pick":"Picareta","hoe":"Enxada","can":"Regador","seed":"Sementes","wood":"Madeira","stone":"Pedra","twig":"Graveto","fruit":"Fruta","flower":"Flor","turnip":"Nabo","fiber": "Fibra", "clay": "Argila", "iron": "Minério de ferro", "shovel": "Pá", "rod": "Vara de pesca", "carrot": "Cenoura", "carrot_seed": "Sementes de cenoura", "potato": "Batata", "potato_seed": "Sementes de batata", "wheat": "Trigo", "wheat_seed": "Sementes de trigo", "tomato": "Tomate", "tomato_seed": "Sementes de tomate", "berry": "Morango", "berry_seed": "Sementes de morango", "iron_axe": "Machado de ferro", "iron_pick": "Picareta de ferro", "iron_hoe": "Enxada de ferro", "iron_can": "Regador de ferro", "iron_shovel": "Pá de ferro", "iron_rod": "Vara de ferro"}
const TOOLS := ["axe", "pick", "hoe", "can", "shovel", "rod", "iron_axe", "iron_pick", "iron_hoe", "iron_can", "iron_shovel", "iron_rod"]
const SIZE := 24
const QUICK := 6
const STACK := 99
var slots: Array = []
var selected := 0

func _init() -> void:
	slots.resize(SIZE)
	for tool in ["axe","pick","hoe","can"]:
		add(tool,1)
	add("seed",8)

func add(id: String, count: int) -> bool:
	var limit := 1 if id in TOOLS else STACK
	var capacity := 0
	for item in slots:
		if item == null:
			capacity += limit
		elif item.id == id:
			capacity += limit-int(item.n)
	if count > capacity:
		return false
	for empty in [false,true]:
		for i in slots.size():
			var item = slots[i]
			if empty:
				if item != null: continue
				item = {"id":id,"n":0}
			elif item == null or item.id != id:
				continue
			var take := mini(count,limit-int(item.n))
			item.n += take
			slots[i] = item
			count -= take
			if count == 0: return true
	return true

func held() -> String:
	return "" if slots[selected] == null else str(slots[selected].id)

func tool() -> String:
	return held().trim_prefix("iron_")

func wear() -> void:
	var item=slots[selected]
	if item==null or item.id not in TOOLS: return
	item.hp=int(item.get("hp",90 if held().begins_with("iron_") else 30))-1
	if item.hp<=0: slots[selected]=null

func use_one() -> void:
	slots[selected].n -= 1
	if slots[selected].n == 0:
		slots[selected] = null

func move_slot(a: int,b: int) -> void:
	if a == b or slots[a] == null: return
	if slots[b] != null and slots[b].id == slots[a].id and slots[a].id not in TOOLS:
		var count := mini(int(slots[a].n),STACK-int(slots[b].n))
		slots[b].n += count
		slots[a].n -= count
		if slots[a].n == 0: slots[a] = null
	else:
		var old = slots[b]
		slots[b] = slots[a]
		slots[a] = old

func quantity(id: String) -> int:
	var total := 0
	for item in slots:
		if item != null and item.id == id: total += int(item.n)
	return total

func remove_items(id: String, amount: int) -> bool:
	if quantity(id) < amount: return false
	for i in range(SIZE-1,-1,-1):
		if slots[i] == null or slots[i].id != id: continue
		var take := mini(amount,int(slots[i].n))
		slots[i].n -= take
		amount -= take
		if slots[i].n == 0: slots[i] = null
		if amount == 0: break
	return true
