extends RefCounted
# Continuous distances in world units. Positive values lie on the dry side.
const AREA := Rect2i(-44,-36,89,73)
const EXTENT := Vector2(100,84)
var variant: int
var phase: float
var side: float
var lake: Vector2
var radii: Vector2
var legacy_channel := false

func _init(layout: int, world_seed: int) -> void:
	variant=layout
	phase=fposmod(world_seed*0.173,TAU)
	side=1 if layout%2==0 else -1
	lake=Vector2(22,-7) if layout<0 else Vector2(side*(18+layout),-10+layout*3)
	radii=Vector2(6,8) if layout<0 else Vector2(5+layout,7-layout)

func coast(p: Vector2) -> float:
	var a:=atan2(p.y/31.5,p.x/38.5)
	var norm:=pow(pow(absf(p.x/38.5),4)+pow(absf(p.y/31.5),4),0.25)
	return (1.0-norm)*34 + 1.35*sin(3*a+phase)+0.85*sin(5*a-phase)+0.45*cos(8*a+phase)

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

func terrain_at(p: Vector2) -> String:
	var sea:=coast(p)
	var fresh:=inland(p)
	if sea<0: return "ocean"
	if fresh<0: return "freshwater"
	if sea<.85 or fresh<.35: return "wet_bank"
	if sea<3.25 or fresh<.75: return "sand"
	return "grass"

func texture() -> ImageTexture:
	var size:=Vector2i(EXTENT)*3
	var img:=Image.create(size.x,size.y,false,Image.FORMAT_RG8)
	for y in size.y:
		for x in size.x:
			var p:=(Vector2(x,y)+Vector2.ONE*0.5)/3.0-EXTENT*0.5
			img.set_pixel(x,y,Color(clampf(coast(p)/16+0.5,0,1),clampf(inland(p)/16+0.5,0,1),0))
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
				var a:=Vector3(hits[0].x,-0.25,hits[0].y)
				var b:=Vector3(hits[1].x,-0.25,hits[1].y)
				var up:=Vector3.UP*1.8
				faces.append_array(PackedVector3Array([a,b,b+up,a,b+up,a+up]))
	var shape:=ConcavePolygonShape3D.new()
	shape.backface_collision=true
	shape.set_faces(faces)
	var collider:=CollisionShape3D.new()
	collider.shape=shape
	v.terrain.add_child(collider)
