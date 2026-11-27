extends RefCounted
# Imported GLB mesh data is shared; no Blender process is needed at runtime.
const ROOT := "res://assets/models/generated/"
static var cache: Dictionary = {}

static func collect(node: Node, parent_transform: Transform3D, result: Array) -> void:
	var local := parent_transform
	if node is Node3D:
		local = parent_transform * (node as Node3D).transform
	if node is MeshInstance3D:
		var instance := node as MeshInstance3D
		if instance.mesh != null:
			result.append([instance.mesh, local])
	for child in node.get_children():
		collect(child, local, result)

static func parts(name: String) -> Array:
	if not cache.has(name):
		var result: Array = []
		var path := ROOT + name + ".glb"
		if ResourceLoader.exists(path, "PackedScene"):
			var scene := load(path) as PackedScene
			if scene != null:
				var node := scene.instantiate()
				collect(node, Transform3D.IDENTITY, result)
				node.free()
		cache[name] = result
	return cache[name]

static func character_mesh(label: String) -> Mesh:
	var kind := ""
	match label:
		"Head": kind = "head"
		"Torso": kind = "torso"
		"Trouser", "Sleeve", "Hand", "Neck": kind = "limb"
		"Shoe": kind = "shoe"
		"Hair cap", "Back hair", "Side lock", "Fringe", "Bun": kind = "hair"
		_: return null
	var data := parts("character_" + kind)
	if data.is_empty():
		return null
	return data[0][0] as Mesh

static func mount(parent: Node3D, id: String, size := Vector3.ONE) -> bool:
	var components:=parts(id)
	for entry in components:
		var model:=MeshInstance3D.new()
		model.mesh=entry[0]
		model.transform=Transform3D(Basis.from_scale(size),Vector3.ZERO)*entry[1]
		parent.add_child(model)
	return not components.is_empty()
