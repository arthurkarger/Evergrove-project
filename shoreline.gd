extends RefCounted
# Continuous distances in world units. Positive values lie on the dry side.
const AREA := Rect2i(-44,-36,89,73)
const EXTENT := Vector2(100,84)
# Shallow coves interrupt the outer beach at different scales on each island.
const COVES := [
	[Vector3(-39,-11,8),Vector3(24,31,7)],
	[Vector3(31,-25,12),Vector3(-39,9,6)],
	[Vector3(-28,30,11),Vector3(36,8,8)],
	[Vector3(-36,18,12),Vector3(22,-30,10)]]
var relief: RefCounted
var classic_coast:=false
var variant: int
var phase: float
var side: float
var lake: Vector2
var radii: Vector2
var legacy_channel := false
var bridge := Rect2()

func _init(layout: int, world_seed: int) -> void:
	variant=layout
	phase=fposmod(world_seed*0.173,TAU)
	side=1 if layout%2==0 else -1
	lake=Vector2(22,-7) if layout<0 else Vector2(side*(18+layout),-10+layout*3)
	radii=Vector2(6,8) if layout<0 else Vector2(5+layout,7-layout)

func coast(p: Vector2) -> float:
	var a:=atan2(p.y/31.5,p.x/38.5)
	var norm:=pow(pow(absf(p.x/38.5),4)+pow(absf(p.y/31.5),4),0.25)
	var distance:=(1.0-norm)*34 + 1.35*sin(3*a+phase)+0.85*sin(5*a-phase)+0.45*cos(8*a+phase) + (0.0 if variant<0 or legacy_channel else 1.15*sin(2*a+variant)*cos(3*a-phase))

	if variant>=0 and not classic_coast and not legacy_channel:
		for c: Vector3 in COVES[variant]:
			distance=smooth_union(distance,p.distance_to(Vector2(c.x,c.y))-c.z,3.5)
	return distance

# Each natural map has a continuous inlet from the ocean, through its lake,
# and a short rounded upstream arm. The southern land corridor remains open.
func river_center(z: float) -> float:
	var bend:=side*(21.0+4.0*sin(z*.14+variant)+2.0*cos(z*.23))
	var lake_blend:=1.0-smoothstep(2.0,9.0,absf(z-lake.y))
	return lerpf(bend,lake.x,lake_blend)

func river_end() -> float:
	return 9.5-float(variant)*.7

func smooth_union(a: float,b: float,k: float) -> float:
	var h:=maxf(k-absf(a-b),0.0)/k
	return minf(a,b)-h*h*k*.25

func inland(p: Vector2) -> float:
	var base:=original_inland(p)
	return smooth_union(base,relief.water_distance(p),.8) if relief else base

func original_inland(p: Vector2) -> float:
	var q:=(p-lake)/radii
	var a:=q.angle()
	var edge:=0.84+0.055*cos(3*a+phase)+0.045*sin(2*a-phase)
	var pond:=(q.length()-edge)*minf(radii.x,radii.y)
	if variant<0: return pond
	if legacy_channel:
		var center:=side*(21+4*sin(p.y*0.14+variant)+2*cos(p.y*0.23))
		var old_width:=1.12+0.36*variant
		var ford:=maxf(0,2.6+old_width-absf(p.y-14+variant))
		var old_river:=Vector2(p.x-center,ford).length()-old_width
		return minf(pond,maxf(old_river,1.5-pond))
	var z:=minf(p.y,river_end())
	var width:=1.28+.20*variant+.23*sin(z*.26+phase)
	width*=lerpf(1.0,.73,smoothstep(river_end()-4.0,river_end(),z))
	var river:=Vector2(p.x-river_center(z),maxf(0.0,p.y-river_end())).length()-width
	# Join the lake to the river with a soft confluence, not a sandy ring.
	return smooth_union(pond,river,1.1)

func distance_at(p: Vector2) -> float:
	return minf(coast(p),inland(p))

# Terrain providers expose surface height independently of the X/Z tile grid.
func height_at(p: Vector2) -> float:
	return relief.height(p) if relief else 0.0

func beach_width(p: Vector2) -> float:
	if variant<0 or legacy_channel: return 3.25
	var angle:=atan2(p.y/31.5,p.x/38.5)
	return 3.05+.85*sin(2.0*angle+phase)+.55*cos(3.0*angle-variant)

func terrain_at(p: Vector2) -> String:
	var sea:=coast(p)
	var fresh:=inland(p)
	if sea<0: return "ocean"
	if fresh<0: return "freshwater"
	if sea<.85 or fresh<.35: return "wet_bank"
	if sea<beach_width(p) or fresh<.75: return "sand"
	return "grass"

func texture(paths: Array=[]) -> ImageTexture:
	var size:=Vector2i(EXTENT)*3
	var img:=Image.create(size.x,size.y,false,Image.FORMAT_RGBA8)
	for y in size.y:
		for x in size.x:
			var p:=(Vector2(x,y)+Vector2.ONE*0.5)/3.0-EXTENT*0.5
			img.set_pixel(x,y,Color(clampf(coast(p)/16+0.5,0,1),clampf(inland(p)/16+0.5,0,1),beach_width(p)/8.0,0.0))
	# Bake trail coverage only inside each short segment's pixel bounds.
	for segment in paths:
		var a: Vector2=segment[0]
		var b: Vector2=segment[1]
		var width: float=segment[2]
		var box:=Rect2(a,Vector2.ZERO).expand(b).grow(width*.5+.55)
		var lo:=Vector2i(((box.position+EXTENT*.5)*3).floor()).max(Vector2i.ZERO)
		var hi:=Vector2i(((box.end+EXTENT*.5)*3).ceil()).min(size)
		for y in range(lo.y,hi.y):
			for x in range(lo.x,hi.x):
				var p:=(Vector2(x,y)+Vector2.ONE*.5)/3.0-EXTENT*.5
				var d:=p.distance_to(Geometry2D.get_closest_point_to_segment(p,a,b))
				var col:=img.get_pixel(x,y)
				col.a=maxf(col.a,1.-smoothstep(width*.25,width*.5+.45,d))
				img.set_pixel(x,y,col)
	return ImageTexture.create_from_image(img)

func add_boundary(v) -> void:
	# Extract the zero contour from triangles. The walls follow the waterline,
	# while each tile reserves enough clearance for its entire square footprint.
	var faces:=PackedVector3Array()
	for y in range(AREA.position.y,AREA.end.y):
		for x in range(AREA.position.x,AREA.end.x):
			var p:=Vector2(x,y)
			var d:=distance_at(p)
			if d<1.35: v.world_grid.reserve_rect(Rect2i(x,y,1,1),"Água ou margem úmida")
			if absf(d)>2.3: continue
			var quad: Array[Vector2]=[p,p+Vector2.RIGHT,p+Vector2.ONE,p+Vector2.DOWN]
			for tri in [[0,1,2],[0,2,3]]:
				var hits:=PackedVector2Array()
				for j in 3:
					var a:=quad[tri[j]]
					var b:=quad[tri[(j+1)%3]]
					var da:=distance_at(a)
					var db:=distance_at(b)
					if (da<0)!=(db<0): hits.append(a.lerp(b,da/(da-db)))
				if hits.size()!=2 or hits[0].distance_squared_to(hits[1])<0.000001: continue
				var a:=hits[0]
				var b:=hits[1]
				if bridge.has_area():
					if a.y>b.y:
						a=hits[1]
						b=hits[0]
					if minf(a.x,b.x)>=bridge.position.x and maxf(a.x,b.x)<=bridge.end.x and b.y>=bridge.position.y and a.y<=bridge.end.y:
						if a.y<bridge.position.y: append_wall(faces,a,a.lerp(b,(bridge.position.y-a.y)/(b.y-a.y)))
						if b.y>bridge.end.y: append_wall(faces,a.lerp(b,(bridge.end.y-a.y)/(b.y-a.y)),b)
						continue
				append_wall(faces,a,b)
	var shape:=ConcavePolygonShape3D.new()
	shape.backface_collision=true
	shape.set_faces(faces)
	var collider:=CollisionShape3D.new()
	collider.shape=shape
	v.terrain.add_child(collider)

func append_wall(faces: PackedVector3Array,from: Vector2,to: Vector2) -> void:
	var a:=Vector3(from.x,height_at(from)-.25,from.y)
	var b:=Vector3(to.x,height_at(to)-.25,to.y)
	var up:=Vector3.UP*1.8
	faces.append_array(PackedVector3Array([a,b,b+up,a,b+up,a+up]))
