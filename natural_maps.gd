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
var protected: Array[Rect2i] = []
var bridge: Rect2 = Rect2()

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
		protected.append(Rect2i(Vector2i(int(plot.x),int(plot.z)),Vector2i.ONE))
	for obj in objects:
		if int(obj.room)==-1: protected.append(house.rect(obj))
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
	if not shoreline.legacy_channel:
		build_districts(v)
	v.plant_grass()

func free_land(v,p: Vector2,margin: float) -> bool:
	if shoreline.distance_at(p)<margin: return false
	var box:=Rect2i(Vector2i(p.round())-Vector2i.ONE,Vector2i(3,3))
	for saved in protected:
		if saved.intersects(box): return false
	return v.world_grid.reason(box)==""

func build_districts(v) -> void:
	var rng:=RandomNumberGenerator.new()
	rng.seed=seed_value+1703
	var s: float=shoreline.side
	# Woodland clusters on the opposite side of the river, open central village.
	for center in [Vector2(-s*24,-15),Vector2(-s*23,13),Vector2(s*8,-23)]:
		for i in 25:
			var p: Vector2=center+Vector2.from_angle(rng.randf()*TAU)*rng.randf_range(1.5,7.5)
			if free_land(v,p,2.6):
				v.tree(p.x,p.y,rng.randf_range(.8,1.22),MAPS[id][3] if i%4 else 0)
	# Flower clearings and small rocky viewpoints, outside the village lots.
	for center in [Vector2(-s*13,-9),Vector2(s*11,16)]:
		for i in 12:
			var p: Vector2=center+Vector2.from_angle(i*2.39996)*sqrt(float(i))*.8
			if free_land(v,p,2.0): v.flowers(p.x,p.y,["eda879","efc879","e9b0c3"][i%3])
	for center in [Vector2(-s*30,-19),Vector2(s*28,18)]:
		for i in 5:
			var p: Vector2=center+Vector2(i*.85,sin(i)*1.1)
			if not free_land(v,p,2.5): continue
			var height:=rng.randf_range(.8,2.2)
			v.piece("stone",Vector3(p.x,height*.35,p.y),Vector3(2.0,height,1.8),"96968a",rng.randf()*TAU)
			v.wall(Vector3(p.x,height*.25,p.y),Vector3(1.35,height*.65,1.2))
	# Keep the center open for player-built homes; a small plaza marks arrival.
	var plaza:=Vector2(0,-5)
	if free_land(v,plaza,3.0):
		v.piece("path_disc",Vector3(plaza.x,.025,plaza.y),Vector3(3.2,.025,3.2),"d2b58e")
	# A real traversable low boardwalk across the northern river.
	var z: float=shoreline.lake.y-10.0
	var x: float=shoreline.river_center(z)
	var left:=x
	var right:=x
	while shoreline.inland(Vector2(left,z))<.8 and x-left<8: left-=.25
	while shoreline.inland(Vector2(right,z))<.8 and right-x<8: right+=.25
	var span:=Rect2(left,z-.85,right-left,1.7)
	if shoreline.coast(Vector2(left,z))<2 or shoreline.coast(Vector2(right,z))<2: return
	for saved in protected:
		if Rect2(saved).grow(.5).intersects(span): return
	shoreline.bridge=span
	bridge=span
	v.world_grid.reserve_box(span.get_center(),span.size,"Ponte")
	for i in range(ceili(span.size.x/.27)):
		var px:=left+.135+i*.27
		v.piece("wood",Vector3(px,.085,z),Vector3(.25,.10,1.7),"b58a5d" if i%2 else "c29a6c")
	for edge in [-1,1]:
		v.piece("wood",Vector3(span.get_center().x,.48,z+edge*.81),Vector3(span.size.x,.12,.12),"8d6746")
		v.wall(Vector3(span.get_center().x,.35,z+edge*.88),Vector3(span.size.x,.7,.12))
		for i in range(ceili(span.size.x/1.3)+1):
			var px:=minf(right,left+i*1.3)
			v.piece("wood",Vector3(px,.29,z+edge*.81),Vector3(.15,.62,.15),"8d6746")

