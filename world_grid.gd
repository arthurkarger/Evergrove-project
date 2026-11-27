extends RefCounted
# Map-independent 1-unit cells, centered on integer X/Z. No scene references.
const FOOTPRINTS := {"path":Vector2i(1,1),"fence":Vector2i(2,1),"bench":Vector2i(2,1),"table":Vector2i(1,1),"chest":Vector2i(1,1),"arch":Vector2i(2,2),"flower":Vector2i(1,1),"shrub":Vector2i(1,1),"lamp":Vector2i(1,1),"tree":Vector2i(2,2),"fountain":Vector2i(3,3),"house":Vector2i(5,4),"shop":Vector2i(6,5)}
var bounds: Rect2i
var map_id: String
var seed_value: int
var reserved := {}
var terrain_provider: Callable

func terrain_at(cell: Vector2i) -> String:
	if not bounds.has_point(cell): return "outside"
	return terrain_provider.call(Vector2(cell)) if terrain_provider.is_valid() else "grass"

func _init(area := Rect2i(-30,-23,61,47), id := "starter_village", map_seed := 0) -> void:
	bounds=area
	map_id=id
	seed_value=map_seed

static func world_to_cell(p: Vector2) -> Vector2i:
	return Vector2i(floori(p.x+0.5),floori(p.y+0.5))

static func cell_center(tile: Vector2i, size: Vector2i) -> Vector2:
	return Vector2(tile)+(Vector2(size)-Vector2.ONE)*0.5

static func footprint(id: String,r: int) -> Vector2i:
	var size: Vector2i=FOOTPRINTS.get(id,Vector2i.ONE)
	return Vector2i(size.y,size.x) if posmod(r,2)==1 else size

func reserve_rect(box: Rect2i, reason: String) -> void:
	var clipped := bounds.intersection(box)
	for x in range(clipped.position.x,clipped.end.x):
		for z in range(clipped.position.y,clipped.end.y):
			var tile := Vector2i(x,z)
			if not reserved.has(tile): reserved[tile]=reason

# Conservative rasterization of real geometry; angles handled by caller.
func reserve_box(center: Vector2, size: Vector2, reason: String) -> void:
	var lo := world_to_cell(center-size*0.5+Vector2.ONE*0.001)
	var hi := world_to_cell(center+size*0.5-Vector2.ONE*0.001)
	reserve_rect(Rect2i(lo,hi-lo+Vector2i.ONE),reason)

func reserve_line(a: Vector2,b: Vector2,width: float,reason: String) -> void:
	var d := b-a
	var radius := width*0.5+0.45
	var lo := world_to_cell(Vector2(minf(a.x,b.x),minf(a.y,b.y))-Vector2.ONE*radius)
	var hi := world_to_cell(Vector2(maxf(a.x,b.x),maxf(a.y,b.y))+Vector2.ONE*radius)
	for x in range(lo.x,hi.x+1):
		for z in range(lo.y,hi.y+1):
			var p := Vector2(x,z)
			var t := clampf((p-a).dot(d)/maxf(d.length_squared(),0.0001),0,1)
			if p.distance_to(a+d*t)<=radius and bounds.has_point(Vector2i(x,z)):
				reserve_rect(Rect2i(Vector2i(x,z),Vector2i.ONE),reason)

func reason(box: Rect2i) -> String:
	if not bounds.encloses(box): return "Fora do mapa"
	for x in range(box.position.x,box.end.x):
		for z in range(box.position.y,box.end.y):
			var tile := Vector2i(x,z)
			if reserved.has(tile): return str(reserved[tile])
	return ""
