extends RefCounted
# Role name, personality, measurable requirements and an optional missing system.
const PEOPLE := {
	"merchant":["Comerciante","Prático",{"coins":500,"commercial":1},""],
	"gardener":["Jardineiro","Paciente",{"flower":15,"tree":5},""],
	"carpenter":["Carpinteiro","Inventivo",{"wood":50,"furniture":10},""],
	"fisher":["Pescador","Observador",{"species":20},"Enciclopédia de pesca"],
	"cook":["Cozinheiro","Generoso",{"harvest":30},"Culinária"],
	"stylist":["Estilista","Ousada",{"residents":5},""],
	"architect":["Arquiteto","Metódico",{"stars":3},""],
	"artist":["Artista","Sonhadora",{"decor":20},""],
	"lia":["Lia","Curiosa",{"fruit":3},""],
	"davi":["Davi","Sociável",{"wood":8},""],
	"bento":["Bento","Reservado",{"stone":6},""]}
const LABEL := {"coins":"folhas","commercial":"terreno comercial livre","flower":"flores colhidas","tree":"árvores plantadas","wood":"madeiras coletadas","furniture":"móveis fabricados","species":"espécies registradas","harvest":"alimentos cultivados","residents":"moradores","stars":"estrelas","decor":"decorações","fruit":"frutas coletadas","stone":"pedras coletadas"}
const COST := {"house":{"wood":6,"stone":3},"shop":{"wood":8,"stone":5}}
const PRICE := {"house":20,"shop":35}
var stats := {}
var stages := {}

func count(key: String) -> void:
	stats[key]=int(stats.get(key,0))+1

func metrics(life) -> Dictionary:
	var m := stats.duplicate()
	m.merge({"coins":life.social.coins,"commercial":0,"tree":0,"decor":0,"residents":0,"infra":0,"green":0,"trade":0},true)
	for obj in life.house.objects:
		if obj.room!=-1: continue
		match obj.id:
			"house","shop":
				if obj.id=="shop" and obj.get("who","")=="": m.commercial+=1
				if obj.get("complete",false):
					m.infra+=3
					if obj.id=="shop": m.trade+=1
			"path","fence","lamp": m.infra+=1
			"tree": m.tree+=1; m.green+=2
			"flower","shrub": m.green+=1; m.decor+=1
			_: m.decor+=1
	for id in stages:
		if stages[id]=="installed": m.residents+=1
	var score := mini(m.decor,8)+mini(m.green,8)+mini(m.infra,8)+mini(m.trade*4,8)+mini(m.residents*2,8)
	m.stars=1+mini(4,score/8)
	return m

func advance(life) -> bool:
	var changed := false
	for obj in life.house.objects:
		if int(obj.get("due",0))>0 and life.day>=int(obj.due):
			obj.complete=true
			obj.erase("due")
			if obj.get("who","")!="": stages[obj.who]="installed"
			changed=true
	var m := metrics(life)
	for id in PEOPLE:
		var info: Array=PEOPLE[id]
		if stages.has(id) or info[3]!="": continue
		if info[2].keys().all(func(k): return m.get(k,0)>=info[2][k]):
			stages[id]="visitor"
			changed=true
	return changed

func assign(id: String,obj: Dictionary) -> bool:
	if stages.get(id)!="invited" or obj.get("who","")!="" or obj.has("due"): return false
	if obj.id!=("shop" if id=="merchant" else "house"): return false
	obj.who=id
	stages[id]="materials"
	return true

func fund(obj: Dictionary,life) -> bool:
	if not COST.has(obj.id) or obj.has("due"): return false
	var who: String=obj.get("who","")
	if obj.get("complete",false) and (who=="" or stages.get(who)!="materials"): return false
	var costs: Dictionary=COST[obj.id]
	var price: int=PRICE[obj.id]
	if life.social.coins<price: return false
	for k in costs:
		if life.bag.quantity(k)<costs[k]: return false
	for k in costs: life.bag.remove_items(k,costs[k])
	life.social.coins-=price
	obj.due=life.day+1
	if who!="": stages[who]="building"
	return true
