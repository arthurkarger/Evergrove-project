extends SceneTree
const BlenderModels = preload("res://blender_models.gd")
var failures := 0

func check(ok: bool, message: String) -> void:
	if not ok:
		printerr("FAIL: ",message)
		failures += 1

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	for name in ["house_628693","house_946e57","house_96778c","house_577453","house_b76349","house_597e80","house_84905d","tree","pine","fruit_tree","bench","wildflowers","river_stones","table","chest","character_head","character_torso","character_limb","character_shoe","character_hair"]:
		check(not BlenderModels.parts(name).is_empty(),"Imported "+name)
	var world = preload("res://main.tscn").instantiate()
	root.add_child(world)
	await physics_frame
	check(world.village.imported_counts.size()==11,"Seven cottages and four scenery asset kinds placed")
	check(world.village.imported_counts.get("bench",0)==2,"Both village benches imported")
	check(not world.village.blender_batches.is_empty(),"Imported scenery batched")
	check(world.village.wind_materials.size()>=3,"Blender foliage materials animate")
	for id in ["stone","flower"]:
		var resource: Node3D=world.life.resources.filter(func(r): return r.id==id)[0].node
		var mesh: Mesh=BlenderModels.parts("river_stones" if id=="stone" else "wildflowers")[0][0]
		check(resource.get_child(0).mesh==mesh,"Forage visual uses "+id)
	for id in ["table","chest","bench"]:
		var prop: Node3D=world.site.model(id,false)
		check(prop.get_child(0).mesh==BlenderModels.parts(id)[0][0],"Furniture uses "+id)
		prop.free()
	var head = world.character.body.get_node_or_null("Head")
	check(head is MeshInstance3D and head.mesh == BlenderModels.character_mesh("Head"),"Player uses Blender head")
	var torso = world.character.body.get_node_or_null("Torso")
	check(torso is MeshInstance3D and torso.mesh == BlenderModels.character_mesh("Torso"),"Player uses Blender torso")
	print("Blender model integration failures: ",failures)
	quit(1 if failures else 0)
