extends RefCounted

const Grid = preload("res://world_grid.gd")
const MAPS := {
	"vale":["Vale das Flores",731,"9fbc70",0],
	"pinhal":["Rio dos Pinheiros",419,"789c69",1],
	"pomar":["Lago do Pomar",853,"abc578",2],
	"brejo":["Margens de Junco",263,"8eaf83",0]}
var id: String
var seed_value: int
var shoreline: RefCounted
# Preserve 0.6.0 vegetation and forage locations across terrain upgrades.
var original_water_cells := {}
var trees := []
var blossoms := []

func _init(key: String, world_seed: int) -> void:
	id=key
	seed_value=world_seed
	var variant := MAPS.keys().find(key)
	shoreline=preload("res://shoreline.gd").new(variant,world_seed)
	var side := 1 if variant%2==0 else -1
	var lake := Vector2(side*(18+variant),-10+variant*3)
	var radius := Vector2(5+variant,7-variant)
	for z in range(-23,24):
		var river := side*(21+4*sin(z*0.14+variant)+2*cos(z*0.23))
		for x in range(-30,31):
			if ((Vector2(x,z)-lake)/radius).length()<1 or (absf(x-river)<1.4+0.4*variant and absi(z-14+variant)>1):
				original_water_cells[Vector2i(x,z)]=true
	var rng := RandomNumberGenerator.new()
	rng.seed=seed_value
	for i in 160:
		var p := Vector2i(rng.randi_range(-29,29),rng.randi_range(-22,22))
		if p.y>-2 and abs(p.x)<13 or original_water_cells.has(p): continue
		if trees.any(func(q): return Vector2(q).distance_to(Vector2(p))<3): continue
		if trees.size()<34: trees.append(p)
		elif blossoms.size()<22: blossoms.append(p)

# Avoid overwriting existing fields/buildings when upgrading an older save.
# Only maps with a conflict retain their original water contour.
func protect_existing_layout(plots: Array, objects: Array, house) -> void:
	for plot in plots:
		if shoreline.inland(Vector2(plot.x,plot.z))<1.35:
			shoreline.legacy_channel=true
			return
	for obj in objects:
		if int(obj.room)!=-1: continue
		var footprint: Rect2i=house.rect(obj)
		for x in range(footprint.position.x,footprint.end.x):
			for z in range(footprint.position.y,footprint.end.y):
				if shoreline.inland(Vector2(x,z))<1.35:
					shoreline.legacy_channel=true
					return

func thumbnail() -> Texture2D:
	var img:=Image.create(132,108,false,Image.FORMAT_RGB8)
	var palette: Dictionary={"ocean":"519db0","freshwater":"7ebeb1","wet_bank":"c7ab80","sand":"efd7a1","grass":MAPS[id][2]}
	for y in 108:
		for x in 132:
			var point:=(Vector2(x,y)+Vector2.ONE*0.5)/1.5-Vector2(44,36)
			img.set_pixel(x,y,Color(palette[shoreline.terrain_at(point)]))
	for p: Vector2i in trees:
		if shoreline.distance_at(Vector2(p))>2.0:
			img.fill_rect(Rect2i(Vector2i((Vector2(p)+Vector2(44,36))*1.5),Vector2i(2,2)),Color("44764c"))
	img.fill_rect(Rect2i(52,80,6,5),Color("875f47"))
	return ImageTexture.create_from_image(img)

func render(v) -> void:
	v.world_grid=Grid.new(shoreline.AREA,id,seed_value)
	v.piece("ground",Vector3(0,-0.32,0),Vector3(144,0.64,128),MAPS[id][2])
	v.cottage(-7,19.45,"628693","f3d1a0")
	# Keep established vegetation coordinates for save compatibility, but
	# avoid placing trunks and flowers in the new water or on narrow banks.
	for p: Vector2i in trees:
		if shoreline.distance_at(Vector2(p))>2.0:
			v.tree(p.x,p.y,0.78+0.07*posmod(p.x,5),MAPS[id][3])
	for p: Vector2i in blossoms:
		if shoreline.distance_at(Vector2(p))>1.6:
			v.flowers(p.x,p.y,["eda879","efc879","e9b0c3"][posmod(p.x,3)])
	v.plant_grass()
