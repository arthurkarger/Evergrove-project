extends RefCounted
# Starter map descriptor. Future providers can construct the same grid contract
# from a selected layout or a seed without changing construction/save logic.
const Grid = preload("res://world_grid.gd")
const ID := "starter_village"
const BOUNDS := Rect2i(-30,-23,61,47)
const SEED := 0

static func new_grid():
	return Grid.new(BOUNDS,ID,SEED)
