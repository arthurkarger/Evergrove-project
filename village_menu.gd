extends CanvasLayer

signal closed
signal changed

var world
var shade := ColorRect.new()
var heading := Label.new()
var body := Label.new()
var options := VBoxContainer.new()
var scroll := ScrollContainer.new()
var resident := -1
var buying := true
var message := ""

func build(game) -> void:
	world = game
	layer = 5
	add_child(shade)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.color = Color("223027b8")
	var center := CenterContainer.new()
	shade.add_child(center)
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var panel := PanelContainer.new()
	center.add_child(panel)
	panel.custom_minimum_size = Vector2(415,0)
	panel.add_theme_stylebox_override("panel",game.hud.panel_style("36493f","c2ae85"))
	var column := VBoxContainer.new()
	panel.add_child(column)
	heading.add_theme_font_size_override("font_size",20)
	column.add_child(heading)
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(body)
	scroll.custom_minimum_size = Vector2(0,210)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	column.add_child(scroll)
	scroll.add_child(options)
	options.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var leave := button(column,"Fechar",close)
	leave.custom_minimum_size.y = 42
	shade.hide()

func button(container: Control,caption: String,callback: Callable) -> Button:
	var b := Button.new()
	world.hud.decorate(b)
	b.text = caption
	b.custom_minimum_size.y = 42
	container.add_child(b)
	b.pressed.connect(callback)
	return b

func open_person(i: int,hour: int) -> void:
	resident = i
	message = world.life.social.talk(i,world.life.day,hour,world.life.room>=0)
	show_panel()
	changed.emit()

func open_shop() -> void:
	resident = -1
	buying = true
	message = "O balcão troca produtos por folhas."
	show_panel()

func show_panel() -> void:
	shade.show()
	scroll.scroll_vertical = 0
	redraw_menu()
	options.get_child(0).grab_focus()

func close() -> void:
	shade.hide()
	closed.emit()

func redraw_menu() -> void:
	for child in options.get_children():
		options.remove_child(child)
		child.queue_free()
	var life = world.life
	var social = life.social
	var bag = life.bag
	body.text = message
	if resident>=0:
		var p: Array = social.PEOPLE[resident]
		var f: Dictionary = social.record(resident)
		heading.text = "%s   ·   ♥ %d/10" % [p[0],floori(float(f.bond)/10)]
		var held: String = bag.held()
		var present := button(options,"Presentear · "+("selecione um item" if held.is_empty() else str(bag.NAMES[held])),give)
		present.disabled = f.gift==life.day or held.is_empty() or held in bag.TOOLS
		var title := "Entregar" if f.quest else "Aceitar pedido"
		var order := button(options,"%s · %d %s · %d folhas" % [title,p[2],bag.NAMES[p[1]],p[3]],request)
		order.disabled = f.done==life.day
		if order.disabled: order.text = "Pedido concluído hoje"
	else:
		heading.text = "Armazém   ·   %d folhas" % social.coins
		button(options,"Ir para vendas" if buying else "Ir para compras",switch_trade)
		var prices: Dictionary = social.BUY if buying else social.SELL
		for id in prices:
			var label_text := "%s %s · %d F   (%d na mochila)" % ["Comprar" if buying else "Vender",bag.NAMES[id],prices[id],bag.quantity(id)]
			var b := button(options,label_text,trade.bind(id))
			b.disabled = social.coins<int(prices[id]) if buying else bag.quantity(id)==0

func give() -> void:
	message = world.life.social.gift(resident,world.life.bag,world.life.day)
	finish()

func request() -> void:
	message = world.life.social.quest(resident,world.life.bag,world.life.day)
	finish()

func trade(id: String) -> void:
	message = world.life.social.trade(world.life.bag,id,buying)
	finish()

func switch_trade() -> void:
	buying = not buying
	message = "Compras" if buying else "Vendas"
	scroll.scroll_vertical = 0
	redraw_menu()

func finish() -> void:
	changed.emit()
	redraw_menu()
