extends RefCounted

const PRIMARY := "user://homestead-v1.json"
const Maps = preload("res://natural_maps.gd")
const STARTERS := ["vale","pinhal","pomar"]
static var current := 1

static func slot(number: int) -> String:
	assert(number in [1,2,3])
	return "user://slot-%d.json" % number

static func active() -> String:
	return slot(current)

static func occupied(number: int) -> bool:
	for suffix in ["",".bak",".tmp"]:
		if FileAccess.file_exists(slot(number)+suffix): return true
	return false

static func decode(path: String) -> Dictionary:
	if not FileAccess.file_exists(path): return {}
	var parser:=JSON.new()
	if parser.parse(FileAccess.get_file_as_string(path))!=OK: return {}
	var data=parser.data
	if data is Dictionary and data.has("payload"):
		if not data.payload is String or data.payload.sha256_text()!=data.get("hash"): return {}
		if parser.parse(data.payload)!=OK: return {}
		data=parser.data
	if not data is Dictionary or int(data.get("version",0)) not in [1,2,3,4]: return {}
	if not data.get("slots") is Array or data.slots.size()!=24 or not data.get("plots") is Array: return {}
	if not data.get("pos") is Array or data.pos.size()!=2: return {}
	return data

static func read_save(path: String) -> Dictionary:
	for suffix in ["",".bak",".tmp"]:
		var data:=decode(path+suffix)
		if not data.is_empty(): return data
	return {}

static func write_save(path: String,data: Dictionary) -> bool:
	var payload:=JSON.stringify(data)
	var file:=FileAccess.open(path+".tmp",FileAccess.WRITE)
	if file==null: return false
	file.store_string(JSON.stringify({"payload":payload,"hash":payload.sha256_text()}))
	file.flush()
	var error:=file.get_error()
	file.close()
	if error!=OK: return false
	if not decode(path).is_empty():
		if DirAccess.copy_absolute(path,path+".bak.new")!=OK: return false
		if DirAccess.rename_absolute(path+".bak.new",path+".bak")!=OK: return false
	return DirAccess.rename_absolute(path+".tmp",path)==OK

static func erase(number: int) -> bool:
	for suffix in [".bak.new",".tmp",".bak",".v1",".v2",""]:
		var path: String=slot(number)+suffix
		if FileAccess.file_exists(path) and DirAccess.remove_absolute(path)!=OK: return false
	return true

static func legacy_files() -> Array[String]:
	var paths:Array[String]=[]
	for id in Maps.MAPS:
		var path:="user://homestead-"+str(id)+".json"
		if FileAccess.file_exists(path): paths.append(path)
	if FileAccess.file_exists(PRIMARY): paths.push_front(PRIMARY)
	return paths

static func import_world(path: String,number: int) -> bool:
	if occupied(number) or path not in legacy_files() or decode(path).is_empty(): return false
	return DirAccess.rename_absolute(path,slot(number))==OK

static func migrate() -> void:
	# A single rename transfers a complete world. Extra worlds remain available for import.
	var pending:=legacy_files()
	if pending.is_empty() or FileAccess.file_exists("user://slot-migration.done"): return
	for path in pending:
		for number in range(1,4):
			if not occupied(number):
				import_world(path,number)
				break

	var marker:=FileAccess.open("user://slot-migration.done",FileAccess.WRITE)
	if marker!=null: marker.store_string("1")

static func world_name(data: Dictionary) -> String:
	var id: String=data.get("world",{}).get("id","starter_village")
	return data.get("world_name",Maps.MAPS[id][0] if Maps.MAPS.has(id) else "Vila original")
