extends RefCounted

const PRIMARY := "user://homestead-v1.json"
const CHOICE := "user://world-choice.cfg"
const Maps = preload("res://natural_maps.gd")

static func active() -> String:
	var cfg:=ConfigFile.new()
	if cfg.load(CHOICE)==OK:
		var key: String=cfg.get_value("world","slot","")
		if Maps.MAPS.has(key): return slot(key)
	return PRIMARY

static func slot(id: String) -> String:
	return "user://homestead-"+id+".json"

static func primary_id() -> String:
	if not FileAccess.file_exists(PRIMARY): return ""
	var data=JSON.parse_string(FileAccess.get_file_as_string(PRIMARY))
	if data is Dictionary: return data.get("world",{}).get("id","starter_village")
	return "starter_village"

static func select(id: String) -> bool:
	var cfg:=ConfigFile.new()
	var primary:=primary_id()
	var key: String="" if primary=="" or primary==id else id
	cfg.set_value("world","slot",key)
	return cfg.save(CHOICE)==OK
