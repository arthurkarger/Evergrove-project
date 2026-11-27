extends RefCounted
const INK := Color("35463b")
const PAPER := Color("fff1d6")
const MUTED := Color("71816c")

static func box(fill: Color, edge: Color, radius := 16, margin := 8, border := 1) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color=fill
	s.border_color=edge
	s.set_border_width_all(border)
	s.set_corner_radius_all(radius)
	for side in [SIDE_LEFT,SIDE_RIGHT,SIDE_TOP,SIDE_BOTTOM]:
		s.set_content_margin(side,margin)
	return s

static func theme() -> Theme:
	var t := Theme.new()
	t.set_color("font_color","Label",INK)
	t.set_color("font_color","Button",INK)
	t.set_color("font_hover_color","Button",INK)
	t.set_color("font_pressed_color","Button",INK)
	t.set_color("font_focus_color","Button",INK)
	t.set_color("font_disabled_color","Button",Color("a6aa96"))
	t.set_font_size("font_size","Label",18)
	t.set_font_size("font_size","Button",17)
	return t

static func button(b: Button) -> void:
	b.add_theme_stylebox_override("normal",box(Color("fff2dceF"),Color("dfd2af"),14,7))
	b.add_theme_stylebox_override("hover",box(Color("e4edca"),Color("9bae7f"),14,7))
	b.add_theme_stylebox_override("pressed",box(Color("c8dbac"),Color("8ba273"),14,7))
	b.add_theme_stylebox_override("disabled",box(Color("ece5d4"),Color("e1d9c4"),14,7))
	b.add_theme_stylebox_override("focus",box(Color.TRANSPARENT,Color("7e9e68"),14,7,2))
	for key in ["font_color","font_hover_color","font_pressed_color","font_focus_color"]:
		b.add_theme_color_override(key,INK)
	b.add_theme_color_override("font_disabled_color",Color("a2a493"))
	b.add_theme_font_size_override("font_size",17)
