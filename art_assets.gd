extends RefCounted

# Optional, reviewed art shipped with the game; no networking or credentials.
const Bag = preload("res://backpack.gd")
const ICON_DIR := "res://assets/art/icons/"
const SURFACE_DIR := "res://assets/art/textures/"
const SURFACES := ["grass"]

static func load_texture(path: String) -> Texture2D:
	if not ResourceLoader.exists(path, "Texture2D"):
		return null
	var resource := ResourceLoader.load(path, "Texture2D")
	return resource as Texture2D

static func icon(id: String) -> Texture2D:
	if not Bag.NAMES.has(id):
		return null
	var vector := load_texture(ICON_DIR + id + ".svg")
	if vector != null: return vector
	return load_texture(ICON_DIR + id + ".png")

static func surface(id: String) -> Texture2D:
	if not id in SURFACES:
		return null
	return load_texture(SURFACE_DIR + id + ".png")
