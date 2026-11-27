extends CanvasLayer

signal home_requested
signal use_requested
signal picked(slot: int)
signal bag_toggled(open: bool)
signal moved(from: int,to: int)

const Bag = preload("res://backpack.gd")
const Style = preload("res://ui_style.gd")
const ExternalArt = preload("res://art_assets.gd")
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
var held_label := Label.new()
var build_button := Button.new()
var run_button := Button.new()

func panel_style(fill: String,border: String) -> StyleBoxFlat:
	return Style.box(Color(fill),Color(border),16,10)

func decorate(b: Button) -> void:
	Style.button(b)

func icon_for(id: String) -> Texture2D:
	if icons.has(id): return icons[id]
	var imported := ExternalArt.icon(id)
	if imported != null:
		icons[id] = imported
		return imported
	var art := {
		"axe":'<path d="M16 46 L40 15" stroke="#9b6847" stroke-width="7" stroke-linecap="round"/><path d="M29 9 Q42 6 51 18 L38 30 L23 18Z" fill="#a4bac1"/>',
		"pick":'<path d="M14 47L35 19" stroke="#9b6847" stroke-width="7" stroke-linecap="round"/><path d="M9 21Q25 1 48 18L54 29Q33 14 9 21" fill="#a4bac1"/>',
		"hoe":'<path d="M15 48L39 14" stroke="#a87750" stroke-width="7" stroke-linecap="round"/><path d="M28 11L49 9L47 20L29 23Z" fill="#a4bac1"/>',
		"can":'<path d="M17 22Q7 7 27 9Q43 9 39 23" fill="none" stroke="#6f979a" stroke-width="5"/><rect x="15" y="21" width="30" height="28" rx="9" fill="#82b6b6"/><path d="M16 33L6 23L2 27L14 44" fill="#82b6b6"/><path d="M43 28L54 22L59 28" fill="none" stroke="#6f979a" stroke-width="6"/>',
		"seed":'<path d="M19 9H45L49 49Q32 56 15 49Z" fill="#e8c684"/><path d="M19 9L15 17H49L45 9" fill="#c59659"/><path d="M31 43V28Q17 27 21 17Q34 18 33 30Q36 18 45 21Q46 33 33 35" fill="#73965d"/>',
		"wood":'<rect x="7" y="18" width="46" height="29" rx="12" fill="#b58052"/><ellipse cx="45" cy="32" rx="12" ry="15" fill="#e6bc79"/><ellipse cx="45" cy="32" rx="6" ry="9" fill="none" stroke="#b58052" stroke-width="2"/><path d="M9 28H31M13 37H32" stroke="#986540" stroke-width="3" stroke-linecap="round"/>',
		"stone":'<path d="M9 43L7 30L19 13L41 10L55 31L49 48L25 52Z" fill="#a3aaa7" stroke="#5d706f" stroke-width="3" stroke-linejoin="round"/><path d="M19 13L29 33L7 30M29 33L55 31L41 10" fill="#c4ccc6"/><path d="M29 33L25 52L49 48L55 31" fill="#818e8b"/>',
		"twig":'<path d="M11 52L45 10M27 32L13 22M33 25L49 29" fill="none" stroke="#a67448" stroke-width="7" stroke-linecap="round"/><path d="M40 17Q43 3 54 5Q55 17 40 17" fill="#86a96a"/>',
		"fruit":'<path d="M32 16Q37 7 35 4" fill="none" stroke="#805b38" stroke-width="4"/><path d="M33 14Q40 3 52 8Q46 19 33 14" fill="#7fa15c"/><path d="M32 19Q8 6 7 31Q9 58 31 51Q53 58 57 31Q54 9 32 19" fill="#e7453e" stroke="#873633" stroke-width="3"/><path d="M12 37Q23 49 32 44Q44 49 52 36Q49 54 32 51Q16 55 12 37" fill="#b92e35"/><ellipse cx="19" cy="27" rx="5" ry="7" fill="#ffb9a9"/>',
		"flower":'<path d="M32 32V56M32 46Q16 32 13 44Q20 54 32 50M32 47Q48 32 52 42Q43 53 32 51" fill="none" stroke="#78a264" stroke-width="5" stroke-linecap="round"/><g fill="#e9a4ac"><ellipse cx="32" cy="12" rx="9" ry="12"/><ellipse cx="18" cy="24" rx="12" ry="9"/><ellipse cx="46" cy="24" rx="12" ry="9"/><ellipse cx="32" cy="36" rx="9" ry="11"/></g><circle cx="32" cy="24" r="8" fill="#eac568"/>',
		"turnip":'<path d="M31 23Q12 10 19 4Q31 4 32 20Q35 2 45 5Q49 17 34 23" fill="#82aa6b"/><path d="M13 32Q10 18 32 19Q54 18 51 36Q48 48 32 57Q13 48 13 32" fill="#f0e2c9"/><path d="M13 31Q13 20 32 19Q50 20 51 32" fill="#d6a6b8"/>'
	}
	if not art.has(id): return null
	var img := Image.new()
	var svg := '<svg xmlns="http://www.w3.org/2000/svg" width="64" height="64" viewBox="0 0 64 64">'+str(art[id])+'</svg>'
	if img.load_svg_from_string(svg)!=OK: return null
	icons[id]=ImageTexture.create_from_image(img)
	return icons[id]

func bar_button(parent: Container,i: int,inventory: bool) -> Button:
	var b := Button.new()
	decorate(b)
	b.custom_minimum_size = Vector2(51,48)
	b.expand_icon = true
	b.add_theme_constant_override("icon_max_width",42 if inventory else 36)
	b.add_theme_font_size_override("font_size",13)
	b.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	parent.add_child(b)
	if inventory: b.pressed.connect(cell_pressed.bind(i))
	else: b.pressed.connect(picked.emit.bind(i))
	return b

func build(model) -> void:
	bag = model
	var top := HBoxContainer.new()
	add_child(top)
	top.position = Vector2(12,10)
	top.add_theme_constant_override("separation",8)
	var pack := Button.new()
	pack.text = "Mochila"
	pack.custom_minimum_size=Vector2(88,42)
	decorate(pack)
	top.add_child(pack)
	pack.pressed.connect(toggle)
	build_button.name="BuildButton"
	build_button.icon=preload("res://assets/art/icons/build.svg")
	build_button.tooltip_text="Construir · B"
	build_button.expand_icon=true
	build_button.add_theme_constant_override("icon_max_width",32)
	build_button.custom_minimum_size=Vector2(48,42)
	decorate(build_button)
	build_button.focus_mode=Control.FOCUS_NONE
	top.add_child(build_button)
	build_button.pressed.connect(home_requested.emit)
	var info := PanelContainer.new()
	info.add_theme_stylebox_override("panel",Style.box(Color("fff2ded9"),Color.TRANSPARENT,14,7,0))
	top.add_child(info)
	info.add_child(clock_label)
	clock_label.add_theme_color_override("font_color",Style.INK)
	clock_label.add_theme_font_size_override("font_size",16)
	var row := HBoxContainer.new()
	add_child(row)
	row.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	row.grow_horizontal = Control.GROW_DIRECTION_BOTH
	row.offset_bottom = -12
	row.offset_top = -60
	row.add_theme_constant_override("separation",5)
	for i in Bag.QUICK: quick.append(bar_button(row,i,false))
	add_child(action)
	decorate(action)
	action.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	action.offset_left = -205
	action.offset_right = -12
	action.offset_top = -78
	action.offset_bottom = -20
	action.add_theme_font_size_override("font_size",18)
	action.pressed.connect(use_requested.emit)
	add_child(run_button)
	run_button.name="RunButton"
	decorate(run_button)
	run_button.icon=preload("res://assets/art/icons/run.svg")
	run_button.tooltip_text="Correr · toque para alternar"
	run_button.toggle_mode=true
	run_button.focus_mode=Control.FOCUS_NONE
	run_button.expand_icon=true
	run_button.add_theme_constant_override("icon_max_width",33)
	run_button.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	run_button.offset_left=-70
	run_button.offset_right=-12
	run_button.offset_top=-144
	run_button.offset_bottom=-88
	run_button.visible=DisplayServer.is_touchscreen_available()
	add_child(note)
	note.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	note.grow_horizontal = Control.GROW_DIRECTION_BOTH
	note.offset_top = -111
	note.offset_bottom = -82
	note.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	note.add_theme_constant_override("outline_size",5)
	note.add_theme_color_override("font_outline_color",Color("354535"))
	add_child(shade)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.color = Color("26322888")
	shade.theme=Style.theme()
	var center := CenterContainer.new()
	shade.add_child(center)
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel",panel_style("fff5df","d8c59d"))
	center.add_child(panel)
	var column := VBoxContainer.new()
	panel.add_child(column)
	var head := HBoxContainer.new()
	column.add_child(head)
	var title := Label.new()
	title.text = "Mochila"
	title.add_theme_font_size_override("font_size",27)
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
	grid.add_theme_constant_override("h_separation",8)
	grid.add_theme_constant_override("v_separation",8)
	column.add_child(grid)
	for i in Bag.SIZE:
		var cell := bar_button(grid,i,true)
		cell.custom_minimum_size=Vector2(72,64)
		cells.append(cell)
	column.add_child(held_label)
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
			b.self_modulate = Color.WHITE
			b.add_theme_stylebox_override("normal",Style.box(Color("dae9bb") if chosen else Color("f4e7cb"),Color("779958") if chosen else Color("d8c59d"),14,5,2 if chosen else 1))
	hint.text = "Toque em um item para organizar." if source < 0 else "%s · escolha o destino" % Bag.NAMES[bag.slots[source].id]
	var used := 0
	for item in bag.slots:
		if item != null: used+=1
	held_label.text = "%d / 24 espaços  ·  Equipado: %s" % [used,"Nenhum" if bag.held().is_empty() else Bag.NAMES[bag.held()]]

func show_note(message: String) -> void:
	note.text = message
	notice_time = 2.2

func _process(delta: float) -> void:
	action.visible=not action.disabled
	run_button.visible=DisplayServer.is_touchscreen_available() and not shade.visible
	if not is_visible() or shade.visible: run_button.set_pressed_no_signal(false)
	if notice_time > 0:
		notice_time -= delta
		if notice_time <= 0: note.text = ""
