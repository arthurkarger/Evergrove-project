extends CanvasLayer

signal home_requested
signal use_requested
signal picked(slot: int)
signal bag_toggled(open: bool)
signal moved(from: int,to: int)

const Bag = preload("res://backpack.gd")
const ICONS := {
	"axe":["...ii...","..iiii..",".iiiiw..","....w...","...w....","..w.....",".w......","........"],
	"pick":["..iiii..",".iiiwii.","i...w..i","...w....","...w....","..w.....","..w.....","........"],
	"hoe":["..iiiii.","..i..w..",".....w..","....w...","...w....","...w....","..w.....","........"],
	"can":["...aaa..","..a...a.","..aaaa..","a.aaaai.","aaaaaai.","..aaaai.","...aaa..","........"],
	"seed":["..wwww..","...ww...","..yyyy..",".yyggyy.",".yygyyy.",".yyyyyy.","..yyyy..","........"],
	"wood":["........","....www.","...wyyww","..wwyyww",".wwwwww.",".yyyww..",".ywyw...","..yy...."],
	"stone":["........","...iii..","..iiiia.",".iiiiaa.",".iiaaaaa","..aaaaa.","........","........"],
	"twig":["........",".....w..","....ww..","..w.w...","...ww...","..ww....",".ww.....","........"],
	"fruit":["....gg..","...wg...","..rr.rr.",".ryrrrr.",".rrrrrr.","..rrrr..","...rr...","........"],
	"flower":["...rr...","..ryyr..","...rr...","....g...","..ggg...","....ggg.","....g...","........"],
	"turnip":["..g..g..","...gg...","..yyyy..",".yyiyyy.",".yyyyyy.","..yyyy..","...yy...","...y...."]}
const INK := {"i":"d6dae0","a":"789ca5","w":"ab784d","y":"ecd399","g":"8da857","r":"db8876"}
var bag
var icons := {}
var clock_label := Label.new()
var note := Label.new()
var action := Button.new()
var shade := ColorRect.new()
var quick: Array[Button] = []
var cells: Array[Button] = []
var source := -1
var notice_time := 0.0
var hint := Label.new()

func panel_style(fill: String,border: String) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(fill)
	style.border_color = Color(border)
	style.set_border_width_all(2)
	style.set_corner_radius_all(6)
	for side in [SIDE_LEFT,SIDE_RIGHT,SIDE_TOP,SIDE_BOTTOM]: style.set_content_margin(side,5)
	return style

func decorate(b: Button) -> void:
	b.add_theme_stylebox_override("normal",panel_style("35453bf2","77816b"))
	b.add_theme_stylebox_override("hover",panel_style("48594a","d7c69a"))
	b.add_theme_stylebox_override("pressed",panel_style("5c684e","eed29a"))
	b.add_theme_font_size_override("font_size",15)

func icon_for(id: String) -> Texture2D:
	if icons.has(id): return icons[id]
	var img := Image.create(8,8,false,Image.FORMAT_RGBA8)
	img.fill(Color.TRANSPARENT)
	for y in 8:
		for x in 8:
			var ink: String = ICONS[id][y][x]
			if INK.has(ink): img.set_pixel(x,y,Color(INK[ink]))
	img.resize(24,24,Image.INTERPOLATE_NEAREST)
	icons[id] = ImageTexture.create_from_image(img)
	return icons[id]

func bar_button(parent: Container,i: int,inventory: bool) -> Button:
	var b := Button.new()
	decorate(b)
	b.custom_minimum_size = Vector2(55,48)
	b.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	parent.add_child(b)
	if inventory: b.pressed.connect(cell_pressed.bind(i))
	else: b.pressed.connect(picked.emit.bind(i))
	return b

func build(model) -> void:
	bag = model
	var top := HBoxContainer.new()
	add_child(top)
	top.position = Vector2(12,10)
	top.add_theme_constant_override("separation",12)
	var pack := Button.new()
	pack.text = "Mochila  [I]" if not DisplayServer.is_touchscreen_available() else "Mochila"
	decorate(pack)
	top.add_child(pack)
	pack.pressed.connect(toggle)
	var house_button := Button.new()
	house_button.text="Lar"
	decorate(house_button)
	top.add_child(house_button)
	house_button.pressed.connect(home_requested.emit)
	top.add_child(clock_label)
	clock_label.add_theme_constant_override("outline_size",4)
	clock_label.add_theme_color_override("font_outline_color",Color("344538"))
	var row := HBoxContainer.new()
	add_child(row)
	row.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	row.grow_horizontal = Control.GROW_DIRECTION_BOTH
	row.offset_bottom = -8
	row.offset_top = -56
	for i in Bag.QUICK: quick.append(bar_button(row,i,false))
	add_child(action)
	decorate(action)
	action.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	action.offset_left = -167
	action.offset_right = -12
	action.offset_top = -77
	action.offset_bottom = -20
	action.pressed.connect(use_requested.emit)
	add_child(note)
	note.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	note.grow_horizontal = Control.GROW_DIRECTION_BOTH
	note.offset_top = -91
	note.offset_bottom = -63
	note.add_theme_constant_override("outline_size",5)
	note.add_theme_color_override("font_outline_color",Color("354535"))
	add_child(shade)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.color = Color("263228cb")
	var center := CenterContainer.new()
	shade.add_child(center)
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel",panel_style("34443c","c0ae88"))
	center.add_child(panel)
	var column := VBoxContainer.new()
	panel.add_child(column)
	var head := HBoxContainer.new()
	column.add_child(head)
	var title := Label.new()
	title.text = "Mochila   ·   24 espaços"
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(title)
	var close := Button.new()
	close.text = "Fechar"
	decorate(close)
	head.add_child(close)
	close.pressed.connect(toggle)
	column.add_child(hint)
	var grid := GridContainer.new()
	grid.columns = 6
	column.add_child(grid)
	for i in Bag.SIZE: cells.append(bar_button(grid,i,true))
	shade.hide()
	refresh()

func toggle() -> void:
	shade.visible = not shade.visible
	source = -1
	refresh()
	if shade.visible: cells[bag.selected].grab_focus()
	bag_toggled.emit(shade.visible)

func cell_pressed(i: int) -> void:
	if source >= 0:
		moved.emit(source,i)
		source = -1
	elif bag.slots[i] != null:
		source = i
	refresh()

func refresh() -> void:
	for list in [quick,cells]:
		for i in list.size():
			var b: Button = list[i]
			var item = bag.slots[i]
			b.icon = null if item == null else icon_for(item.id)
			b.text = str(int(item.n)) if item != null and item.n > 1 else ""
			if item == null and i < Bag.QUICK: b.text = str(i+1)
			b.tooltip_text = "Vazio" if item == null else Bag.NAMES[item.id]
			var chosen: bool = i == source if shade.visible else i == bag.selected
			b.self_modulate = Color.WHITE if chosen or i < Bag.QUICK else Color("c2c5ba")
			b.add_theme_stylebox_override("normal",panel_style("626d4f" if chosen else "35453bf2","f6ce7d" if chosen else "77816b"))
	hint.text = "1ª linha = barra rápida. Escolha um item." if source < 0 else "%s · escolha o destino" % Bag.NAMES[bag.slots[source].id]

func show_note(message: String) -> void:
	note.text = message
	notice_time = 2.2

func _process(delta: float) -> void:
	if notice_time > 0:
		notice_time -= delta
		if notice_time <= 0: note.text = ""
