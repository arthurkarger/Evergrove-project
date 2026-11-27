extends RefCounted

const Grid = preload("res://world_grid.gd")
const MAPS := {
	"vale":["Vale das Flores",731,"9fbc70",0],
	"pinhal":["Rio dos Pinheiros",419,"789c69",1],
	"pomar":["Lago do Pomar",853,"abc578",2],
	"brejo":["Margens de Junco",263,"8eaf83",0]}
# Grove centres, flower colours and open building meadows are authored per island.
const DISTRICTS := {
	"vale": [[Vector2(-23,-14),Vector2(-26,12),Vector2(6,-23)], ["e99bb2","ebbe73","f5dfcb"], Rect2i(3,8,9,8)],
	"pinhal": [[Vector2(21,-18),Vector2(25,-6),Vector2(29,15)], ["adb6d0","e6d6bc","b5a4c6"], Rect2i(-9,8,9,8)],
	"pomar": [[Vector2(-21,13),Vector2(-16,-16),Vector2(-28,-2)], ["efbc73","e49b78","f5d7aa"], Rect2i(4,7,10,8)],
	"brejo": [[Vector2(18,-21),Vector2(28,8),Vector2(12,20)], ["c8adce","dedba1","b1caa1"], Rect2i(-11,7,9,8)]}
var id: String
var seed_value: int
var shoreline: RefCounted
# Preserve 0.6.0 vegetation and forage locations across terrain upgrades.
var original_water_cells := {}
var trees := []
var blossoms := []
var protected: Array[Rect2i] = []
var occupied_cells: Dictionary = {}
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
	for box in protected:
		for x in range(box.position.x,box.end.x):
			for z in range(box.position.y,box.end.y):
				occupied_cells[Vector2i(x,z)]=true
				if not shoreline.classic_coast and shoreline.coast(Vector2(x,z))<1.35:
					shoreline.classic_coast=true
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
	# Shipped seeds use captures of the actual scene; custom seeds use the same
	# terrain sampler as the playable world.
	if seed_value==MAPS[id][1] and not shoreline.legacy_channel and not shoreline.classic_coast:
		var path:="res://assets/art/maps/"+id+".webp"
		if ResourceLoader.exists(path): return load(path)
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
	v.world_grid.reserve_box(Vector2(0,6),Vector2(2,2),"Chegada")
	v.world_grid.reserve_box(Vector2(0,1),Vector2(8,4),"Acampamento dos visitantes")
	if not shoreline.legacy_channel:
		build_bridge(v)
		build_trails(v)
	# Keep established vegetation coordinates for save compatibility, but
	# avoid placing trunks and flowers in the new water or on narrow banks.
	for p: Vector2i in trees:
		if free_land(v,Vector2(p),2.7):
			v.tree(p.x,p.y,0.78+0.07*posmod(p.x,5),MAPS[id][3])
	for p: Vector2i in blossoms:
		if free_land(v,Vector2(p),1.7):
			v.flowers(p.x,p.y,DISTRICTS[id][1][posmod(p.x,3)])
	if not shoreline.legacy_channel:
		build_districts(v)
	v.plant_grass()

func free_land(v,p: Vector2,margin: float) -> bool:
	if shoreline.distance_at(p)<margin: return false
	var box:=Rect2i(Vector2i(p.round())-Vector2i.ONE,Vector2i(3,3))
	if DISTRICTS[id][2].intersects(box): return false
	for saved in protected:
		if saved.intersects(box): return false
	return v.world_grid.reason(box)==""

func build_districts(v) -> void:
	var rng:=RandomNumberGenerator.new()
	rng.seed=seed_value+1703
	var s: float=shoreline.side
	# Woodland clusters on the opposite side of the river, open central village.
	for center in DISTRICTS[id][0]:
		for i in 25:
			var p: Vector2=center+Vector2.from_angle(rng.randf()*TAU)*rng.randf_range(1.5,7.5)
			if free_land(v,p,2.6):
				v.tree(p.x,p.y,rng.randf_range(.8,1.22),MAPS[id][3] if i%4 else 0)
	# In the marsh, rushes follow the intermittent damp fringe beside the river.
	if id=="brejo":
		for i in 70:
			var z:=rng.randf_range(-24,9)
			var x: float=shoreline.river_center(z)+rng.randf_range(2,5)*(-1 if i%2 else 1)
			var p:=Vector2(x,z)
			if shoreline.inland(p)>1.9 or not free_land(v,p,.4): continue
			for j in 5:
				var offset:=Vector2.from_angle(j*2.4)*.16
				var h:=rng.randf_range(.34,.71)
				v.piece("flower_part",Vector3(x+offset.x,h*.5,z+offset.y),Vector3(.05,h,.05),"859058")
			v.world_grid.reserve_box(p,Vector2(.45,.45),"Juncos")
	# Flower clearings and small rocky viewpoints, outside the village lots.
	for center in [Vector2(-s*13,-9),Vector2(s*11,16)]:
		for i in 12:
			var p: Vector2=center+Vector2.from_angle(i*2.39996)*sqrt(float(i))*.8
			if free_land(v,p,2.0): v.flowers(p.x,p.y,DISTRICTS[id][1][i%3])
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

func bridge_span(z: float) -> Rect2:
	var x: float=shoreline.river_center(z)
	var left:=x
	var right:=x
	while shoreline.inland(Vector2(left,z))<.8 and x-left<10: left-=.25
	while shoreline.inland(Vector2(right,z))<.8 and right-x<10: right+=.25
	if right-left<2 or right-left>13: return Rect2()
	var span:=Rect2(left,z-.85,right-left,1.7)
	for end in [left-1.6,right+1.6]:
		if shoreline.distance_at(Vector2(end,z))<1.2: return Rect2()
	var approach:=span.grow_individual(2,0,2,0)
	for saved in protected:
		if Rect2(saved).grow(.65).intersects(approach): return Rect2()
	return span

func build_bridge(v) -> void:
	var span:=Rect2()
	for offset in [10,12,8,14,16,6,-5,-7]:
		span=bridge_span(shoreline.lake.y-offset)
		if span.has_area(): break
	if not span.has_area(): return
	var z:=span.get_center().y
	var left:=span.position.x
	var right:=span.end.x
	shoreline.bridge=span
	bridge=span
	v.world_grid.reserve_box(span.get_center(),span.size+Vector2(4,.6),"Ponte")
	# One convex deck with gently sloping landings. No per-plank collision seams.
	var points:=PackedVector3Array()
	for edge in [-.85,.85]:
		for profile: Vector2 in [Vector2(left-.85,-.02),Vector2(left,.135),Vector2(right,.135),Vector2(right+.85,-.02),Vector2(right+.85,-.18),Vector2(left-.85,-.18)]:
			points.append(Vector3(profile.x,profile.y,z+edge))
	var deck:=ConvexPolygonShape3D.new()
	deck.points=points
	var collision:=CollisionShape3D.new()
	collision.shape=deck
	v.terrain.add_child(collision)
	for bank: int in [-1,1]:
		var landing:=left if bank<0 else right
		for j in 3:
			var px:=landing+bank*(j+.5)*.27
			v.piece("wood",Vector3(px,.065-j*.044,z),Vector3(.27,.09,1.7),"b58a5d")
	for i in range(ceili(span.size.x/.27)):
		var px:=left+.135+i*.27
		v.piece("wood",Vector3(px,.085,z),Vector3(.25,.10,1.7),"b58a5d" if i%2 else "c29a6c")
	for edge in [-1,1]:
		v.piece("wood",Vector3(span.get_center().x,.48,z+edge*.81),Vector3(span.size.x,.12,.12),"8d6746")
		v.wall(Vector3(span.get_center().x,.35,z+edge*.88),Vector3(span.size.x,.7,.12))
		for i in range(ceili(span.size.x/1.3)+1):
			var px:=minf(right,left+i*1.3)
			v.piece("wood",Vector3(px,.29,z+edge*.81),Vector3(.15,.62,.15),"8d6746")


# Sample curved footpaths in short sections so upgraded farms retain their ground.
func trail(v,a: Vector2,b: Vector2,c: Vector2,d: Vector2,width: float) -> void:
	var steps:=ceili((a.distance_to(b)+b.distance_to(c)+c.distance_to(d))/1.6)
	var last:=a
	for i in range(1,steps+1):
		var p:=a.bezier_interpolate(b,c,d,float(i)/steps)
		var mid:=(last+p)*.5
		var bounds:=Rect2(last,Vector2.ZERO).expand(p).grow(width*.5+.5)
		if shoreline.distance_at(mid)>.65 and not protected.any(func(r): return Rect2(r).intersects(bounds)):
			v.path_between(last,p,width)
		last=p

func build_trails(v) -> void:
	var s: float=shoreline.side
	var hub:=Vector2(0,-5)
	trail(v,Vector2(-7,22.2),Vector2(5,27),Vector2(3,16),Vector2(1.3,7),1.3)
	trail(v,Vector2(1.3,7),Vector2(7,3),Vector2(6,-3),hub,1.25)
	trail(v,hub,Vector2(-s*7,-7),Vector2(-s*14,-17),DISTRICTS[id][0][0],1.15)
	if not bridge.has_area(): return
	var z:=bridge.get_center().y
	var near_x:=bridge.position.x if s>0 else bridge.end.x
	var far_x:=bridge.end.x if s>0 else bridge.position.x
	trail(v,hub,Vector2(s*5,-10),Vector2(near_x-s*7,z),Vector2(near_x,z),1.45)
	trail(v,Vector2(far_x,z),Vector2(far_x+s*4,z),Vector2(s*31,z+3),Vector2(s*30,z+7),1.25)
