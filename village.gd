extends Node3D

const LIMIT_X := 30
const LIMIT_Z := 23
const WOOD := "896449"
const TRAIL := "ddbf8e"

var meshes := {}
var batches := {}
var terrain := StaticBody3D.new()

func _ready() -> void:
	add_child(terrain)
	var crown := SphereMesh.new()
	crown.radial_segments = 8
	crown.rings = 3
	crown.height = 1
	crown.radius = 0.5
	var disc := CylinderMesh.new()
	disc.radial_segments = 16
	disc.height = 1
	var cone := CylinderMesh.new()
	cone.radial_segments = 8
	cone.top_radius = 0
	cone.height = 1
	meshes = {"box": BoxMesh.new(), "round": crown, "disc": disc, "pine": cone, "roof": PrismMesh.new()}
	build_paths()
	build_homes()
	build_lake()
	build_groves()
	flush_batches()

# Share primitive geometry and draw repeated scenery in spatial batches.
func piece(kind: String, position_3d: Vector3, size: Vector3, tint: String, angle := 0.0) -> void:
	var key := "%s:%d:%d" % [kind, floori(position_3d.x / 16), floori(position_3d.z / 16)]
	if not batches.has(key):
		batches[key] = []
	var basis := Basis(Vector3.UP, angle) * Basis.from_scale(size)
	batches[key].append([Transform3D(basis, position_3d), Color(tint)])

func flush_batches() -> void:
	var material := StandardMaterial3D.new()
	material.vertex_color_use_as_albedo = true
	for key: String in batches:
		var items: Array = batches[key]
		var batch := MultiMesh.new()
		batch.transform_format = MultiMesh.TRANSFORM_3D
		batch.use_colors = true
		batch.mesh = meshes[key.get_slice(":", 0)]
		batch.instance_count = items.size()
		for i in items.size():
			batch.set_instance_transform(i, items[i][0])
			batch.set_instance_color(i, items[i][1])
		var instance := MultiMeshInstance3D.new()
		instance.multimesh = batch
		instance.material_override = material
		add_child(instance)
	batches.clear()

func wall(pos: Vector3, size: Vector3, angle := 0.0) -> void:
	var collider := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	collider.shape = box
	collider.position = pos
	collider.rotation.y = angle
	terrain.add_child(collider)

func path_between(a: Vector2, b: Vector2, width: float) -> void:
	var mid := (a + b) / 2
	var line := b - a
	piece("box", Vector3(mid.x,0.014,mid.y), Vector3(width,0.02,line.length()), TRAIL, atan2(line.x,line.y))
	piece("disc", Vector3(b.x,0.019,b.y), Vector3(width,0.02,width), TRAIL)

func build_paths() -> void:
	piece("box", Vector3(0,-0.32,0), Vector3(120,0.64,102), "91b579")
	wall(Vector3(0,-0.3,0), Vector3(70,0.6,56))
	var plaza := Vector2(0,2)
	piece("disc", Vector3(0,0.038,2), Vector3(12,0.03,9), "d7bc96")
	# A loop links the cottages, orchard and lakeside picnic spot.
	var loop := PackedVector2Array([plaza, Vector2(-12,3), Vector2(-22,1), Vector2(-22,12), Vector2(-12,16), Vector2(3,15), Vector2(14,9), Vector2(16,1), Vector2(9,-1), plaza])
	for i in range(1,loop.size()):
		path_between(loop[i-1],loop[i],2.2)
	path_between(Vector2(-12,3),Vector2(-12,-4),2)
	path_between(plaza,Vector2(0,-9),2.7)
	path_between(Vector2(9,-1),Vector2(10,-6),2)
	path_between(Vector2(-22,1),Vector2(-24,-9),1.7)
	# Central shade tree on a low circular planter.
	piece("disc",Vector3(-2,0.14,1),Vector3(3,0.25,3),"ac9577")
	tree(-2,1,1.05,0)
	bench(-4.3,3.2)
	bench(14,6)

func build_homes() -> void:
	cottage(-12,-6,"b76349","efd2a2")
	cottage(0,-11,"597e80","f0d8ab")
	cottage(10,-8,"84905d","eac398")
	for x in [-16,-8,6,14]:
		fence(Vector2(x,-8),Vector2(x,-3))
	fence(Vector2(-4,-13),Vector2(-4,-8))
	fence(Vector2(4,-13),Vector2(4,-8))
	for x in [-14,-10,-2,2,8,12]:
		var z := -3.8 if x < -5 else (-8.8 if x < 4 else -5.8)
		flowers(x,z,"edac69" if x < 4 else "e6b4af")

func cottage(x: float,z: float,roof: String,plaster: String) -> void:
	var center := Vector3(x,1.22,z)
	piece("box",center,Vector3(4.4,2.44,3.4),plaster)
	wall(center,Vector3(4.4,2.44,3.4))
	piece("box",Vector3(x,0.19,z),Vector3(4.5,0.38,3.5),"988874")
	piece("roof",Vector3(x,3.13,z),Vector3(5.15,1.55,4.15),roof)
	piece("box",Vector3(x+1.35,3.41,z-0.7),Vector3(0.46,1.65,0.52),"947c69")
	piece("box",Vector3(x,0.85,z+1.74),Vector3(0.93,1.7,0.12),WOOD)
	piece("round",Vector3(x+0.29,0.77,z+1.83),Vector3(0.12,0.12,0.09),"e7bf77")
	for dx in [-1.42,1.42]:
		piece("box",Vector3(x+dx,1.4,z+1.72),Vector3(0.98,1.02,0.08),WOOD)
		piece("box",Vector3(x+dx,1.4,z+1.78),Vector3(0.76,0.8,0.06),"91c1bc")
		piece("box",Vector3(x+dx,1.4,z+1.82),Vector3(0.08,0.83,0.04),"f1dcb8")

func fence(a: Vector2,b: Vector2) -> void:
	var line := b-a
	var mid := (a+b)/2
	var angle := atan2(line.x,line.y)
	var count := ceili(line.length()/1.7)
	for i in range(count+1):
		var p := a.lerp(b,float(i)/count)
		piece("box",Vector3(p.x,0.49,p.y),Vector3(0.21,0.98,0.21),"997751")
	for h in [0.34,0.71]:
		piece("box",Vector3(mid.x,h,mid.y),Vector3(0.13,0.14,line.length()),"bb9569",angle)
	wall(Vector3(mid.x,0.5,mid.y),Vector3(0.22,1,line.length()+0.2),angle)

func bench(x: float,z: float) -> void:
	for dx in [-0.7,0.7]:
		piece("box",Vector3(x+dx,0.27,z),Vector3(0.21,0.54,0.58),WOOD)
	piece("box",Vector3(x,0.55,z),Vector3(2,0.14,0.65),"bb8a59")
	piece("box",Vector3(x,0.9,z-0.28),Vector3(2,0.45,0.12),"a77b52")
	wall(Vector3(x,0.48,z),Vector3(2,0.96,0.65))

func build_lake() -> void:
	var x := 22.0
	var z := -7.0
	piece("disc",Vector3(x,0.065,z),Vector3(12.8,0.09,16.8),"c8b38b")
	piece("disc",Vector3(x,0.12,z),Vector3(12,0.06,16),"77b8b3")
	piece("disc",Vector3(x+0.35,0.16,z-0.3),Vector3(10,0.03,13.7),"64a6aa")
	# Match the faceted waterline, with vertical sides above the player capsule.
	var outline := PackedVector3Array()
	for i in 16:
		var a := TAU*i/16.0
		for y in [-0.25,1.3]:
			outline.append(Vector3(x+6*cos(a),y,z+8*sin(a)))
	var hull := ConvexPolygonShape3D.new()
	hull.points = outline
	var bank := CollisionShape3D.new()
	bank.shape = hull
	terrain.add_child(bank)
	for i in 8:
		var a := i*2.4
		piece("round",Vector3(x+3.7*cos(a),0.18,z+5*sin(a)),Vector3(0.85,0.035,0.16),"a7d6c8")
	for p in [Vector2(17,-13),Vector2(27,-2),Vector2(27,-12),Vector2(21,2)]:
		for j in 5:
			piece("pine",Vector3(p.x+0.17*j,0.38,p.y+0.16*sin(j)),Vector3(0.21,0.76,0.2),"748e57")

func tree(x: float,z: float,s: float,kind: int) -> void:
	var base := Vector3(x,0,z)
	piece("box",base+Vector3.UP*s,Vector3(0.52,2,0.52)*s,WOOD)
	wall(base+Vector3.UP*s,Vector3(0.65,2,0.65)*s)
	if kind == 1:
		for i in 3:
			var w := 2.9-i*0.61
			piece("pine",base+Vector3.UP*(1.9+i*0.76)*s,Vector3(w,2,w)*s,["50785c","628567","769672"][i])
	else:
		var dark := "628753" if kind == 0 else "799755"
		var light := "87a862" if kind == 0 else "a4b86b"
		piece("round",base+Vector3(0,2.45,0)*s,Vector3(3.3,2.7,3)*s,dark)
		piece("round",base+Vector3(-0.5,3.04,0.18)*s,Vector3(2.45,2,2.35)*s,light)
		if kind == 2:
			for offset in [Vector3(-0.7,2.6,1.15),Vector3(0.63,2.3,1.24),Vector3(1.34,2.65,0.15)]:
				piece("round",base+offset*s,Vector3.ONE*0.31*s,"d8815d")

func flowers(x: float,z: float,color: String) -> void:
	for i in 8:
		var p := Vector3(x+cos(i*2.4)*sqrt(i)*0.28,0,z+sin(i*2.4)*sqrt(i)*0.21)
		piece("round",p+Vector3.UP*0.14,Vector3(0.31,0.28,0.25),"658b59")
		piece("round",p+Vector3.UP*0.29,Vector3(0.23,0.13,0.22),color)

func build_groves() -> void:
	for i in range(-5,6):
		tree(i*5.6,-21+sin(i)*1.4,1.05+0.12*cos(i),posmod(i,2))
		tree(i*5.6,24+cos(i),0.92+0.13*sin(i),posmod(i+1,2))
	for i in range(-3,4):
		tree(-29+sin(i),i*5.6,1.04,posmod(i,2))
		tree(30+cos(i),i*5.6,0.95,posmod(i+1,2))
	for x in [-20,-25]:
		for z in [5,9,15]:
			tree(x,z,0.83,2)
	for p in [Vector2(-18,-12),Vector2(-9,11),Vector2(6,10),Vector2(19,16),Vector2(-6,-15)]:
		tree(p.x,p.y,0.95,0)
		flowers(p.x+1.2,p.y+0.9,"f1d99c")
	for p in [Vector2(17,-16),Vector2(25,3),Vector2(-26,-12),Vector2(-17,18),Vector2(20,13)]:
		for j in 2:
			var w := 1.6-j*0.65
			var pos := Vector3(p.x+j*1.1,w*0.24,p.y+j*0.55)
			piece("round",pos,Vector3(w,w*0.77,w*0.9),"93988a")
			wall(pos,Vector3(w*0.84,w*0.69,w*0.77))
