extends CanvasLayer
const Style = preload("res://ui_style.gd")
const Grid = preload("res://world_grid.gd")

var world
var site
var menu := ColorRect.new()
var board := Control.new()
var surface := ColorRect.new()
var title := Label.new()
var note := Label.new()
var options := VBoxContainer.new()
var hint := Label.new()
var accept: Button
var remove: Button
var rotate: Button
var scroll := ScrollContainer.new()
var candidate := ""
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
	menu.color=Color("23302888")
	menu.theme=Style.theme()
	var center := CenterContainer.new()
	menu.add_child(center)
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var panel := PanelContainer.new()
	center.add_child(panel)
	panel.custom_minimum_size.x=470
	panel.add_theme_stylebox_override("panel",Style.box(Style.PAPER,Color("dfcba2"),22,14,2))
	var col := VBoxContainer.new()
	panel.add_child(col)
	col.add_theme_constant_override("separation",8)
	title.add_theme_font_size_override("font_size",27)
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
			note.text="Sua casa de telhado azul fica ao sul."
			link("Moradores e obras","settlement")
			link("Oficina","craft")
			if room in [-1,6]: link("Planta da casa" if room==6 else "Construir na vila","catalog")
			link("Aparência","look")
			if room==6 and not house.expanded:
				button(options,"Ampliar a casa · 70 folhas",expand_room)
		"catalog","craft":
			title.text="Objetos disponíveis" if page=="catalog" else "Oficina"
			if page=="catalog": button(options,"Selecionar móvel colocado",build.bind(""))
			for id in house.NAMES:
				if page=="catalog" and room!=-1 and id in ["flower","shrub","lamp","fountain","tree","shop","house"]: continue
				var line: String=house.NAMES[id]+"  ×"+str(int(house.stock.get(id,0)))
				if page=="catalog":
					button(options,line,build.bind(id)).disabled=int(house.stock.get(id,0))==0
				else:
					var costs := PackedStringArray()
					for k in house.RECIPES[id]:
						costs.append("%d %s" % [house.RECIPES[id][k],bag.NAMES[k]])
					var craft_button := button(options,line+"   ·   "+", ".join(costs),craft.bind(id))
					var enough := true
					for k in house.RECIPES[id]:
						if bag.quantity(k)<int(house.RECIPES[id][k]): enough=false
					craft_button.disabled=not enough
			link("Voltar","home")
		"settlement":
			settlement_board()
		"resident":
			resident_page()
		"shipping":
			title.text="Caixa de remessas"
			note.text="Venda sua coleta para financiar a primeira construção."
			button(options,"Comprar sementes · 3 folhas",buy_seed).disabled=world.life.social.coins<3
			for id in world.life.social.SELL:
				var qty: int=bag.quantity(id)
				if qty>0: button(options,"%s ×%d · vender 1 por %d" % [bag.NAMES[id],qty,world.life.social.SELL[id]],sell.bind(id))
			link("Voltar","settlement")
		"look":
			title.text="Aparência"
			var values := [["Curto","Franja","Coque"],["Castanho","Mel","Preto","Cobre"],["Camisa","Jardineira","Cachecol"],["Azul","Verde","Vinho","Mostarda"]]
			if world.life.settlement.stages.get("stylist")=="installed":
				values[3].append_array(["Lago","Terracota"])
			for i in 4:
				button(options,"%s · %s" % [["Corte","Cabelo","Roupa","Tecido"][i],values[i][int(house.look[i])]],change_look.bind(i,values[i].size()))
			link("Voltar","home")
		"chest":
			title.text="Baú · 36 espaços"
			button(options,"Guardar itens  /  Retirar" if deposit else "Retirar itens  /  Guardar",switch_chest)
			var used := 0
			for entry in house.objects[chest].slots:
				if entry!=null: used+=1
			note.text="%d / 36 espaços ocupados" % used
			var slots: Array=bag.slots if deposit else house.objects[chest].slots
			var count := 0
			for i in slots.size():
				if slots[i]==null: continue
				count+=1
				button(options,"%s · %s ×%d" % ["Guardar" if deposit else "Retirar",bag.NAMES[slots[i].id],int(slots[i].n)],transfer.bind(i))
			if count==0: note.text="Mochila vazia" if deposit else "Baú vazio"

func craft(id: String) -> void:
	if world.life.house.craft(id,world.life.bag):
		if id in ["bench","table","chest","arch"]: world.life.settlement.count("furniture")
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
	if site.kind!="":
		var footprint: Vector2i=world.life.house.size_of(site.kind,site.turns)
		hint.text+=" · %d × %d" % [footprint.x,footprint.y]
		if not site.valid: hint.text+=" · "+site.failure_reason
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
			site.pick(Grid.world_to_cell(Vector2(local.x,local.z)))
			status()
		finger=-2

func motion(p: Vector2) -> void:
	if p.distance_to(start)>7: dragged=true
	if dragged:
		site.pan+=site.ray(last)-site.ray(p)
		site.bound_pan()
	last=p

func sell(id: String) -> void:
	world.life.social.trade(world.life.bag,id,false)
	world.save_game()
	draw()

func meet(id: String) -> void:
	candidate=id
	open("resident")

func settlement_board() -> void:
	var life=world.life
	var s=life.settlement
	var m: Dictionary=s.metrics(life)
	title.text="Comunidade · %d ★" % m.stars
	note.text="Decoração %d · Verde %d · Infraestrutura %d · Comércio %d · Moradores %d" % [m.decor,m.green,m.infra,m.trade,m.residents]
	link("Caixa de remessas","shipping")
	if life.room==-1:
		for kind in ["house","shop"]:
			button(options,"Demarcar "+str(life.house.NAMES[kind]).to_lower(),plot.bind(kind))
	for i in life.house.objects.size():
		var obj: Dictionary=life.house.objects[i]
		if not s.COST.has(obj.id): continue
		var label_text:=plot_name(obj)
		if obj.has("due"): label_text+=" · pronto no dia %d" % obj.due
		elif obj.get("complete",false): label_text+=" · pronto"
		if not obj.has("due") and (not obj.get("complete",false) or s.stages.get(obj.get("who",""))=="materials"):
			var cost: Dictionary=s.COST[obj.id]
			button(options,label_text+" · entregar %d madeiras, %d pedras e %d folhas" % [cost.wood,cost.stone,s.PRICE[obj.id]],fund.bind(obj))
		else: button(options,label_text,func(): pass).disabled=true
	for id in s.PEOPLE:
		button(options,s.PEOPLE[id][0]+" · "+stage_label(id),meet.bind(id))
	link("Voltar","home")

func plot_name(obj: Dictionary) -> String:
	return "%s (%d, %d)" % [world.life.house.NAMES[obj.id],obj.x,obj.z]

func stage_label(id: String) -> String:
	var s=world.life.settlement
	if s.PEOPLE[id][3]!="": return "Aguarda "+s.PEOPLE[id][3]
	return {"visitor":"Visitante","invited":"Escolher terreno","materials":"Entregar materiais","building":"Em obras","installed":"Instalado"}.get(s.stages.get(id,""),"Requisitos")

func resident_page() -> void:
	var life=world.life
	var s=life.settlement
	var info: Array=s.PEOPLE[candidate]
	title.text=info[0]+" · "+info[1]
	var metrics: Dictionary=s.metrics(life)
	var needs:=PackedStringArray()
	for k in info[2]:
		needs.append("%s %d/%d" % [s.LABEL[k],metrics.get(k,0),info[2][k]])
	note.text=stage_label(candidate)+" · "+", ".join(needs)
	match s.stages.get(candidate,""):
		"visitor": button(options,"Convidar para morar",invite)
		"invited":
			var kind: String="shop" if candidate=="merchant" else "house"
			for obj in life.house.objects:
				if obj.id==kind and obj.get("who","")=="" and not obj.has("due"):
					button(options,"Escolher "+plot_name(obj),assign_plot.bind(obj))
			if life.room==-1: button(options,"Demarcar novo terreno",plot.bind(kind))
		"installed":
			if world.town.frontier and candidate in ["lia","davi","bento"] and world.life.room==-1:
				button(options,"Conversar e trocar presentes",talk_common)
			if candidate=="merchant":
				button(options,"Abrir armazém",shop)
			elif candidate=="stylist": link("Ateliê de aparência","look")
			else:
				var gifts: Dictionary={"gardener":"flower","carpenter":"wood","architect":"stone","artist":"shrub","lia":"seed","davi":"twig","bento":"stone"}
				var item: String=gifts.get(candidate,"seed")
				var name_text: String=life.bag.NAMES.get(item,life.house.NAMES.get(item,item))
				button(options,"Receber "+name_text+" do morador",collect.bind(item)).disabled=int(s.stats.get("gift_"+candidate,0))==life.day
	link("Voltar","settlement")

func plot(kind: String) -> void:
	var house=world.life.house
	if int(house.stock.get(kind,0))<=0 and not house.craft(kind,world.life.bag):
		note.text="Reúna %d gravetos para marcar o terreno." % house.RECIPES[kind].twig
		return
	world.save_game()
	build(kind)

func invite() -> void:
	if world.life.settlement.stages.get(candidate)=="visitor":
		world.life.settlement.stages[candidate]="invited"
	world.save_game()
	draw()

func assign_plot(obj: Dictionary) -> void:
	if world.life.settlement.assign(candidate,obj):
		site.refresh()
		world.save_game()
		open("settlement")

func fund(obj: Dictionary) -> void:
	if world.life.settlement.fund(obj,world.life):
		world.save_game()
		draw()
	else: note.text="Faltam materiais ou folhas para a entrega."

func talk_common() -> void:
	var actor=site.settlers.get_node_or_null(NodePath(candidate))
	if actor==null: return
	menu.hide()
	world.village_menu.open_person({"lia":0,"davi":1,"bento":3}[candidate],world.game_hour(),actor)

func shop() -> void:
	menu.hide()
	world.village_menu.open_shop()

func collect(item: String) -> void:
	var life=world.life
	var key: String="gift_"+candidate
	if int(life.settlement.stats.get(key,0))==life.day: return
	if life.house.NAMES.has(item) and not life.bag.NAMES.has(item):
		life.house.stock[item]=int(life.house.stock.get(item,0))+1
	elif not life.bag.add(item,1):
		note.text="Mochila cheia."
		return
	life.settlement.stats[key]=life.day
	world.save_game()
	draw()

func buy_seed() -> void:
	var result: String=world.life.social.trade(world.life.bag,"seed",true)
	world.save_game()
	draw()
	note.text=result
