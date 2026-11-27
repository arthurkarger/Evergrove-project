extends PanelContainer

const Saves=preload("res://world_saves.gd")
const Character=preload("res://cozy_character.gd")
const Style=preload("res://ui_style.gd")
const CATEGORY:=["Pele","Cabelo","Olhos","Roupa"]
const ICONS:=[
	'<circle cx="24" cy="24" r="14" fill="#e1ad83"/><path d="M16 26q8 8 16 0" fill="none" stroke="#814d39" stroke-width="2.5"/>',
	'<path d="M7 32Q3 8 24 7q21 1 18 25l-9-13-5 7-3-6-9 10 1-7Z" fill="#ad7955" stroke="#664833" stroke-width="2"/>',
	'<path d="M4 24Q24 0 44 24Q24 47 4 24Z" fill="#fff4da" stroke="#544d42" stroke-width="2"/><circle cx="24" cy="24" r="8" fill="#588379"/><circle cx="22" cy="21" r="2" fill="white"/>',
	'<path d="m15 8-11 8 6 10 5-3v16h18V23l5 3 6-10-11-8q-8 9-18 0Z" fill="#7c9bb5" stroke="#475d72" stroke-width="2"/>']
var host
var body:=VBoxContainer.new()
var stage:=""
var pending_delete:=0
var number:=1
var category:=0
var profile: Dictionary
var look: Array
var world_name: String
var selected_map: String
var avatar: Node3D
var rotation_angle:=0.0
var editor_controls: VBoxContainer
var thumbnails: Dictionary={}
var category_icons: Array[Texture2D]=[]
var notice: Label

func setup(title) -> void:
	host=title
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_theme_stylebox_override("panel",host.rounded(Color("284738f5"),Color("abbd92")))
	var scroll:=ScrollContainer.new()
	add_child(scroll)
	scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED
	var center:=CenterContainer.new()
	scroll.add_child(center)
	center.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	center.size_flags_vertical=Control.SIZE_EXPAND_FILL
	center.add_child(body)
	body.add_theme_constant_override("separation",8)
	for svg in ICONS:
		var img:=Image.new()
		img.load_svg_from_string('<svg xmlns="http://www.w3.org/2000/svg" width="48" height="48" viewBox="0 0 48 48">'+svg+'</svg>')
		category_icons.append(ImageTexture.create_from_image(img))
	hide()

func clear(parent: Node) -> void:
	for child in parent.get_children():
		parent.remove_child(child)
		child.queue_free()

func page(id: String,heading: String) -> void:
	stage=id
	avatar=null
	clear(body)
	show()
	host.text_label(body,heading,29)
	modulate.a=.8
	create_tween().tween_property(self,"modulate:a",1,.15)

func slots() -> void:
	pending_delete=0
	page("slots","Escolha seu save")
	for n in range(1,4):
		var data:=Saves.read_save(Saves.slot(n))
		var row:=HBoxContainer.new()
		body.add_child(row)
		if not Saves.occupied(n):
			host.button(row,"%d   ·   Criar mundo" % n,create.bind(n))
		else:
			var minutes:=int(float(data.get("played",0))/60)
			var caption:="%d   ·   %s   ·   %s\nDia %d   ·   %dh %02dmin" % [n,data.get("profile",{}).get("name","Morador"),Saves.world_name(data),data.get("day",1),minutes/60,minutes%60]
			if data.is_empty(): caption="%d   ·   Save ilegível" % n
			var resume_button: Button=host.button(row,caption,resume.bind(n))
			resume_button.custom_minimum_size.x=minf(460,maxf(165,get_viewport_rect().size.x-175))
			resume_button.clip_text=true
			resume_button.tooltip_text=caption
			resume_button.disabled=data.is_empty()
			host.button(row,"Excluir",confirm_delete.bind(n))
	if not Saves.legacy_files().is_empty(): host.text_label(body,"Mundos antigos extras podem ser importados em um slot vazio.",15)
	host.button(body,"Voltar",host.show_menu)

func confirm_delete(n: int) -> void:
	pending_delete=n
	page("delete","Excluir o save %d?" % n)
	var data:=Saves.read_save(Saves.slot(n))
	host.text_label(body,"Todo o progresso de %s será apagado." % Saves.world_name(data),18)
	host.button(body,"Manter save",slots,true)
	host.button(body,"Excluir definitivamente",remove_slot.bind(n))

func remove_slot(n: int) -> void:
	if stage!="delete" or n!=pending_delete: return
	var ok:=Saves.erase(n)
	slots()
	if not ok: host.text_label(body,"Falha ao excluir o save.",18)

func resume(n: int) -> void:
	if host.leaving or Saves.read_save(Saves.slot(n)).is_empty(): return
	Saves.current=n
	host.start_game()

func create(n: int) -> void:
	if Saves.occupied(n): return
	number=n
	profile={"name":"","skin":0,"eye_shape":0,"eye_color":0}
	look=[0,0,0,0]
	category=0
	world_name=""
	selected_map=Saves.STARTERS[0]
	rotation_angle=0
	editor()

func field(parent: Control,placeholder: String,value: String,changed: Callable) -> void:
	var input:=LineEdit.new()
	input.placeholder_text=placeholder
	input.text=value
	input.max_length=20
	input.custom_minimum_size=Vector2(180,44)
	parent.add_child(input)
	input.text_changed.connect(changed)

func editor() -> void:
	page("character","Seu personagem")
	var columns:=HBoxContainer.new()
	body.add_child(columns)
	columns.add_theme_constant_override("separation",16)
	var preview:=SubViewportContainer.new()
	columns.add_child(preview)
	preview.custom_minimum_size=Vector2(160,212)
	preview.stretch=true
	var view:=SubViewport.new()
	preview.add_child(view)
	view.own_world_3d=true
	view.transparent_bg=true
	avatar=Character.new()
	view.add_child(avatar)
	avatar.autonomous_idle=true
	avatar.rotation.y=rotation_angle
	var camera:=Camera3D.new()
	view.add_child(camera)
	camera.projection=Camera3D.PROJECTION_ORTHOGONAL
	camera.size=2.25
	camera.position=Vector3(0,1.12,4)
	camera.look_at(Vector3.UP*.91)
	var env:=Environment.new()
	env.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color=Color("fff2dc")
	env.ambient_light_energy=.72
	camera.environment=env
	var light:=DirectionalLight3D.new()
	view.add_child(light)
	light.rotation_degrees=Vector3(-40,-145,0)
	preview.gui_input.connect(turn_preview)
	var col:=VBoxContainer.new()
	columns.add_child(col)
	field(col,"Nome do personagem",profile.name,func(s): profile.name=s)
	var tabs:=HBoxContainer.new()
	col.add_child(tabs)
	for i in 4:
		var btn:=Button.new()
		btn.icon=category_icons[i]
		btn.expand_icon=true
		btn.icon_alignment=HORIZONTAL_ALIGNMENT_CENTER
		btn.custom_minimum_size=Vector2(46,46)
		btn.tooltip_text=CATEGORY[i]
		btn.add_theme_stylebox_override("normal",Style.box(Color("f8eacc"),Color("9caa83"),12,4,1))
		tabs.add_child(btn)
		btn.pressed.connect(choose_category.bind(i))
	editor_controls=VBoxContainer.new()
	col.add_child(editor_controls)
	choose_category(category)
	notice=host.text_label(body,"",15)
	var nav:=HBoxContainer.new()
	body.add_child(nav)
	host.button(nav,"Voltar",slots)
	host.button(nav,"Continuar",next_from_character,true)
	for path in Saves.legacy_files():
		host.button(body,"Importar · "+Saves.world_name(Saves.decode(path)),import_legacy.bind(path))

func import_legacy(path: String) -> void:
	if Saves.import_world(path,number): slots()
	else: notice.text="Falha ao importar o mundo."

func turn_preview(event: InputEvent) -> void:
	var dx:=0.0
	if event is InputEventScreenDrag: dx=event.relative.x
	elif event is InputEventMouseMotion and event.button_mask&MOUSE_BUTTON_MASK_LEFT: dx=event.relative.x
	else: return
	rotation_angle+=dx*.015
	avatar.rotation.y=rotation_angle

func choose_category(index: int) -> void:
	category=index
	clear(editor_controls)
	match category:
		0: selector("Pele",["Pêssego","Clara","Dourada","Mel","Castanha","Escura"],"skin")
		1:
			selector("Corte",Character.HAIRSTYLES,0)
			selector("Cor",Character.HAIR_NAMES,1)
		2:
			selector("Formato",["Oval","Redondo","Amendoado"],"eye_shape")
			selector("Cor",["Café","Avelã","Verde","Azul","Cinza"],"eye_color")
		3:
			selector("Roupa",Character.OUTFITS,2)
			selector("Cor",Character.CLOTH_NAMES,3)
	avatar.configure_player(look,profile,0)

func selector(label: String,choices: Array,key) -> void:
	var idx:=int(look[key] if key is int else profile[key])
	host.button(editor_controls,label+" · "+choices[idx]+"  ›",cycle.bind(key,choices.size()))

func cycle(key,count: int) -> void:
	if key is int: look[key]=(int(look[key])+1)%count
	else: profile[key]=(int(profile[key])+1)%count
	choose_category(category)

func next_from_character() -> void:
	if str(profile.name).strip_edges().is_empty():
		notice.text="Digite o nome do personagem."
		return
	worlds()

func worlds() -> void:
	page("world","Escolha seu mundo")
	field(body,"Nome do mundo",world_name,func(s): world_name=s)
	var cards:=HFlowContainer.new()
	cards.custom_minimum_size.x=minf(610,maxf(280,get_viewport_rect().size.x-70))
	body.add_child(cards)
	for id in Saves.STARTERS:
		var data: Array=Saves.Maps.MAPS[id]
		if not thumbnails.has(id): thumbnails[id]=Saves.Maps.new(id,data[1]).thumbnail()
		var card: Button=host.button(cards,data[0],pick_map.bind(id,cards))
		card.icon=thumbnails[id]
		card.vertical_icon_alignment=VERTICAL_ALIGNMENT_TOP
		card.icon_alignment=HORIZONTAL_ALIGNMENT_CENTER
		card.add_theme_color_override("font_pressed_color",host.DARK)
		card.add_theme_stylebox_override("pressed",host.rounded(Color("f1dea5"),Color("fff3ca")))
		card.toggle_mode=true
		card.button_pressed=id==selected_map
		card.set_meta("map",id)
	notice=host.text_label(body,"",15)
	var nav:=HBoxContainer.new()
	body.add_child(nav)
	host.button(nav,"Voltar",editor)
	host.button(nav,"Criar mundo",finish,true)

func pick_map(id: String,cards: Control) -> void:
	selected_map=id
	for card in cards.get_children(): card.button_pressed=card.get_meta("map")==id

func finish() -> void:
	if host.leaving or Saves.occupied(number): return
	if world_name.strip_edges().is_empty():
		notice.text="Digite o nome do mundo."
		return
	Saves.current=number
	profile.name=str(profile.name).strip_edges()
	get_tree().set_meta("new_resident",{"profile":profile.duplicate(),"look":look.duplicate(),"world_name":world_name.strip_edges()})
	get_tree().set_meta("evergrove_map",selected_map)
	host.start_game()

func back() -> void:
	match stage:
		"world": editor()
		"slots": host.show_menu()
		_: slots()
