extends RefCounted

const Grid = preload("res://world_grid.gd")
const MAPS := {
	"vale":["Vale das Flores",731,"9fbc70",0],
	"pinhal":["Rio dos Pinheiros",419,"789c69",1],
	"pomar":["Lago do Pomar",853,"abc578",2],
	"brejo":["Margens de Junco",263,"8eaf83",0]}
const AREA := Rect2i(-30,-23,61,47)
var id: String
var seed_value: int
var water := {}
var trees := []
var blossoms := []

func _init(key: String, world_seed: int) -> void:
	id=key
	seed_value=world_seed
	var variant := MAPS.keys().find(key)
	var side := 1 if variant%2==0 else -1
	var lake := Vector2(side*(18+variant),-10+variant*3)
	var radius := Vector2(5+variant,7-variant)
	for z in range(-23,24):
		var river := side*(21+4*sin(z*0.14+variant)+2*cos(z*0.23))
		for x in range(-30,31):
			if ((Vector2(x,z)-lake)/radius).length()<1 or (absf(x-river)<1.4+0.4*variant and absi(z-14+variant)>1):
				water[Vector2i(x,z)]=true
	var rng := RandomNumberGenerator.new()
	rng.seed=seed_value
	for i in 160:
		var p := Vector2i(rng.randi_range(-29,29),rng.randi_range(-22,22))
		if p.y>-2 and abs(p.x)<13 or water.has(p): continue
		if trees.any(func(q): return Vector2(q).distance_to(Vector2(p))<3): continue
		if trees.size()<34: trees.append(p)
		elif blossoms.size()<22: blossoms.append(p)

func thumbnail() -> Texture2D:
	var img := Image.create(61,47,false,Image.FORMAT_RGB8)
	img.fill(Color(MAPS[id][2]))
	for p: Vector2i in water: img.set_pixelv(p-AREA.position,Color("72b5c5"))
	for p: Vector2i in trees: img.fill_rect(Rect2i(p-AREA.position,Vector2i(2,2)),Color("44764c"))
	img.fill_rect(Rect2i(21,40,5,4),Color("875f47"))
	img.resize(122,94,Image.INTERPOLATE_NEAREST)
	return ImageTexture.create_from_image(img)

func render(v) -> void:
	v.world_grid=Grid.new(AREA,id,seed_value)
	v.piece("ground",Vector3(0,-0.32,0),Vector3(120,0.64,102),MAPS[id][2])
	v.wall(Vector3(0,-0.3,0),Vector3(70,0.6,56))
	v.meshes["water"]=BoxMesh.new()
	for z in range(-23,24):
		var start := -31
		for x in range(-30,32):
			if water.has(Vector2i(x,z)):
				if start==-31: start=x
			elif start!=-31:
				var mid := (start+x-1)*0.5
				v.piece("path_box",Vector3(mid,0.01,z),Vector3(x-start+0.75,0.02,1.5),"cdba90")
				v.piece("water",Vector3(mid,0.045,z),Vector3(x-start,0.05,1.01),"79bec0")
				v.wall(Vector3(mid,0.45,z),Vector3(x-start,0.9,1))
				start=-31
	v.cottage(-7,19.45,"628693","f3d1a0")
	for p: Vector2i in trees: v.tree(p.x,p.y,0.78+0.07*posmod(p.x,5),MAPS[id][3])
	for p: Vector2i in blossoms: v.flowers(p.x,p.y,["eda879","efc879","e9b0c3"][posmod(p.x,3)])
	v.plant_grass()
