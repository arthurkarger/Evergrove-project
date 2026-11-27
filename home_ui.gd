extends CanvasLayer

var world
var site
var menu := ColorRect.new()
var board := Control.new()
var surface := ColorRect.new()
var title := Label.new()
var note := Label.new()
var options := VBoxContainer.new()
var hint := Label.new()
var accept := Button.new()
var remove := Button.new()
var rotate := Button.new()
var scroll := ScrollContainer.new()
var chest := -1
var page := ""
var deposit := true
var finger := -2
var start := Vector2.ZERO
var last := Vector2.ZERO
var dragged := false

func button(parent: Control,caption: String,fn: Callable) -> Button:
	var b := Button.new()
	world.hud.decorate(b)
	b.text=caption
	b.custom_minimum_size=Vector2(0,42)
	parent.add_child(b)
	b.pressed.connect(fn)
	return b

func setup(game) -> void:
	layer=6
	world=game
	site=game.site
	add_child(menu)
	menu.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	menu.color=Color("233028b8")
	var center := CenterContainer.new()
	menu.add_child(center)
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var panel := PanelContainer.new()
	center.add_child(panel)
	panel.custom_minimum_size.x=410
	panel.add_theme_stylebox_override("panel",game.hud.panel_style("35483e","c5b08b"))
	var col := VBoxContainer.new()
	panel.add_child(col)
	col.add_child(title)
	col.add_child(note)
	note.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	col.add_child(scroll)
	scroll.custom_minimum_size.y=226
	scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED
	scroll.add_child(options)
	options.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	button(col,"Fechar",close)
	menu.hide()
	add_child(board)
	board.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	board.add_child(surface)
	surface.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	surface.color=Color(0.12,0.29,0.42,0.14)
	surface.gui_input.connect(board_input)
	var rows := VBoxContainer.new()
	board.add_child(rows)
	rows.position=Vector2(12,8)
	rows.add_child(hint)
	hint.add_theme_constant_override("outline_size",4)
	var tools := HBoxContainer.new()
	rows.add_child(tools)
	button(tools,"Catálogo",catalog)
	rotate=button(tools,"Girar",rotate_item)
	accept=button(tools,"Confirmar",confirm)
	remove=button(tools,"Remover",remove_item)
	button(tools,"Cancelar",cancel)
	button(tools,"Sair",close)
	board.hide()

func open(which: String="home") -> void:
	world.toggle_bag(true)
	world.hud.visible=false
	menu.show()
	board.hide()
	page=which
	note.text=""
	scroll.scroll_vertical=0
	draw()

func close() -> void:
	if site.active: site.stop()
	menu.hide()
	board.hide()
	finger=-2
	world.hud.visible=true
	world.hud.refresh()
	world.toggle_bag(false)

func catalog() -> void:
	site.stop()
	open("catalog")

func link(label_text: String,which: String) -> void:
	button(options,label_text,open.bind(which))

func draw() -> void:
	for child in options.get_children():
		options.remove_child(child)
		child.queue_free()
	var house=world.life.house
	var bag=world.life.bag
	var room: int=world.life.room
	match page:
		"home":
			title.text="Lar · %d folhas" % world.life.social.coins
			note.text="Sua casa de telhado azul fica ao sul da praça."
			link("Oficina","craft")
			if room in [-1,6]: link("Planta da casa" if room==6 else "Planta do quintal","catalog")
			link("Aparência","look")
			if room==6 and not house.expanded:
				button(options,"Ampliar a casa · 70 folhas",expand_room)
		"catalog","craft":
			title.text="Objetos disponíveis" if page=="catalog" else "Oficina"
			if page=="catalog": button(options,"Selecionar móvel colocado",build.bind(""))
			for id in house.NAMES:
				var line: String=house.NAMES[id]+"  ×"+str(int(house.stock.get(id,0)))
				if page=="catalog":
					button(options,line,build.bind(id)).disabled=int(house.stock.get(id,0))==0
				else:
					var costs := PackedStringArray()
					for k in house.RECIPES[id]:
						costs.append("%d %s" % [house.RECIPES[id][k],bag.NAMES[k]])
					button(options,line+"   ·   "+", ".join(costs),craft.bind(id))
			link("Voltar","home")
		"look":
			title.text="Aparência"
			var values := [["Curto","Franja","Coque"],["Castanho","Mel","Preto","Cobre"],["Camisa","Jardineira","Cachecol"],["Azul","Verde","Vinho","Mostarda"]]
			for i in 4:
				button(options,"%s · %s" % [["Corte","Cabelo","Roupa","Tecido"][i],values[i][int(house.look[i])]],change_look.bind(i,values[i].size()))
			link("Voltar","home")
		"chest":
			title.text="Baú · 36 espaços"
			button(options,"Guardar → trocar para retirar" if deposit else "Retirar → trocar para guardar",switch_chest)
			var slots: Array=bag.slots if deposit else house.objects[chest].slots
			var count := 0
			for i in slots.size():
				if slots[i]==null: continue
				count+=1
				button(options,"%s · %s ×%d" % ["Guardar" if deposit else "Retirar",bag.NAMES[slots[i].id],int(slots[i].n)],transfer.bind(i))
			if count==0: note.text="Mochila vazia" if deposit else "Baú vazio"

func craft(id: String) -> void:
	if world.life.house.craft(id,world.life.bag):
		note.text="Fabricado · "+str(world.life.house.NAMES[id])
		world.save_game()
	else: note.text="Faltam materiais."
	draw()

func expand_room() -> void:
	if world.life.house.expand(world.life.social):
		site.room_geometry()
		world.save_game()
		draw()
		note.text="O novo cômodo está pronto."
	else: note.text="São necessárias 70 folhas."

func change_look(i: int,n: int) -> void:
	var look: Array=world.life.house.look
	look[i]=(int(look[i])+1)%n
	world.update_look()
	world.save_game()
	draw()

func open_chest(i: int) -> void:
	chest=i
	deposit=true
	open("chest")

func switch_chest() -> void:
	deposit=not deposit
	note.text=""
	draw()

func transfer(i: int) -> void:
	if world.life.house.transfer(chest,world.life.bag,i,deposit):
		world.save_game()
		note.text="Transferido."
	else: note.text="Sem espaço para essa pilha."
	draw()

func build(id: String) -> void:
	menu.hide()
	board.show()
	site.begin(id)
	status()

func status() -> void:
	hint.text="Toque em um móvel para editar · arraste para mover a câmera" if site.kind=="" else str(world.life.house.NAMES[site.kind])+" · escolha um quadrado"
	rotate.disabled=site.kind==""
	accept.disabled=not site.valid
	remove.disabled=site.index<0

func rotate_item() -> void:
	site.turns=(site.turns+1)%4
	site.update_preview()
	status()

func confirm() -> void:
	site.confirm()
	status()

func cancel() -> void:
	if site.kind=="": close()
	else:
		site.reset_selection("")
		status()

func remove_item() -> void:
	if site.index>=0 and world.life.house.remove_object(site.index):
		site.reset_selection("")
		site.refresh()
		world.save_game()
		status()
	else: hint.text="Esvazie o baú antes de removê-lo."

func board_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch: pointer(event.index,event.position,event.pressed)
	elif event is InputEventScreenDrag and event.index==finger: motion(event.position)
	elif event is InputEventMouseButton and event.device!=-1 and event.button_index==MOUSE_BUTTON_LEFT: pointer(-1,event.position,event.pressed)
	elif event is InputEventMouseMotion and finger==-1 and event.device!=-1: motion(event.position)

func pointer(id: int,p: Vector2,down: bool) -> void:
	if down:
		if finger!=-2: return
		finger=id
		start=p
		last=p
		dragged=false
	elif finger==id:
		if not dragged:
			var local: Vector3=site.ray(p)-site.base(world.life.room)
			site.pick(Vector2i(roundi(local.x),roundi(local.z)))
			status()
		finger=-2

func motion(p: Vector2) -> void:
	if p.distance_to(start)>7: dragged=true
	if dragged:
		site.pan+=site.ray(last)-site.ray(p)
		site.bound_pan()
	last=p
