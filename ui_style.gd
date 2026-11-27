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

# Center the actual visible artwork, not its potentially asymmetric SVG canvas.
static var centered_cache: Dictionary = {}

static func centered_texture(source: Texture2D) -> Texture2D:
	if source == null: return null
	var key := source.get_instance_id()
	if centered_cache.has(key): return centered_cache[key]
	var image := source.get_image()
	if image == null or image.is_empty(): return source
	if image.is_compressed() and image.decompress()!=OK: return source
	image.convert(Image.FORMAT_RGBA8)
	var bounds := image.get_used_rect()
	if bounds.size.x<=0 or bounds.size.y<=0: return source
	var art := image.get_region(bounds)
	var factor := 56.0/float(maxi(bounds.size.x,bounds.size.y))
	var target := Vector2i(maxi(1,roundi(bounds.size.x*factor)),maxi(1,roundi(bounds.size.y*factor)))
	art.resize(target.x,target.y,Image.INTERPOLATE_LANCZOS)
	var canvas := Image.create(64,64,false,Image.FORMAT_RGBA8)
	canvas.fill(Color.TRANSPARENT)
	canvas.blit_rect(art,Rect2i(Vector2i.ZERO,target),Vector2i((64-target.x)/2,(64-target.y)/2))
	var texture := ImageTexture.create_from_image(canvas)
	centered_cache[key]=texture
	return texture

static func center_icon(b: Button, texture: Texture2D, extent: float) -> TextureRect:
	# Independent child: button captions and theme margins cannot move this icon.
	var art := TextureRect.new()
	art.name="CenteredIcon"
	art.mouse_filter=Control.MOUSE_FILTER_IGNORE
	art.expand_mode=TextureRect.EXPAND_IGNORE_SIZE
	art.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	art.texture_filter=CanvasItem.TEXTURE_FILTER_LINEAR
	art.texture=centered_texture(texture)
	b.icon=null
	b.add_child(art)
	art.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	art.offset_left=-extent*0.5
	art.offset_right=extent*0.5
	art.offset_top=-extent*0.5
	art.offset_bottom=extent*0.5
	return art
