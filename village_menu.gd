extends CanvasLayer

signal closed
signal changed
const Style = preload("res://ui_style.gd")
var world
var shade := ColorRect.new()
var heading := Label.new()
var body := Label.new()
var options := VBoxContainer.new()
var scroll := ScrollContainer.new()
var dialog := PanelContainer.new()
var shop_panel := PanelContainer.new()
var shop_body := Label.new()
var shop_heading := Label.new()
var dialog_actions := HBoxContainer.new()
var next_button := Button.new()
var resident := -1
var buying := true
var message := ""
var reveal := 0.0
var speaking := false
var beat := 0.0
var voice := AudioStreamPlayer.new()
var motion: Tween
var old_camera := Vector3.ZERO
var actor: Node3D
var actor_body: Node3D
var old_actor_rotation := 0.0
var old_body_y := 0.0
var old_body_rotation := Vector3.ZERO

func build(game) -> void:
	world=game
	layer=5
	add_child(shade)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.theme=Style.theme()
	shade.color=Color(0,0,0,0)
	shade.mouse_filter=Control.MOUSE_FILTER_STOP
	shade.gui_input.connect(on_background)
	var bottom := CenterContainer.new()
	shade.add_child(bottom)
	bottom.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bottom.anchor_top=0.59
	bottom.offset_bottom=-14
	bottom.mouse_filter=Control.MOUSE_FILTER_IGNORE
	bottom.add_child(dialog)
	dialog.custom_minimum_size=Vector2(690,164)
	dialog.add_theme_stylebox_override("panel",Style.box(Style.PAPER,Color("dfcba2"),26,15,2))
	var col := VBoxContainer.new()
	dialog.add_child(col)
	col.add_theme_constant_override("separation",8)
	heading.add_theme_font_size_override("font_size",21)
	heading.add_theme_color_override("font_color",Color("6f8b58"))
	col.add_child(heading)
	body.custom_minimum_size=Vector2(650,57)
	body.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	body.add_theme_font_size_override("font_size",23)
	body.mouse_filter=Control.MOUSE_FILTER_STOP
	body.gui_input.connect(on_background)
	col.add_child(body)
	col.add_child(dialog_actions)
	dialog_actions.add_theme_constant_override("separation",7)
	next_button.text="Continuar  ›"
	Style.button(next_button)
	next_button.custom_minimum_size.y=40
	next_button.pressed.connect(advance_dialogue)
	col.add_child(next_button)
	var center := CenterContainer.new()
	shade.add_child(center)
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter=Control.MOUSE_FILTER_IGNORE
	center.add_child(shop_panel)
	shop_panel.custom_minimum_size.x=465
	shop_panel.add_theme_stylebox_override("panel",Style.box(Style.PAPER,Color("dfcba2"),22,14,2))
	var shop_col := VBoxContainer.new()
	shop_panel.add_child(shop_col)
	shop_col.add_theme_constant_override("separation",8)
	shop_heading.add_theme_font_size_override("font_size",26)
	shop_col.add_child(shop_heading)
	shop_body.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	shop_col.add_child(shop_body)
	scroll.custom_minimum_size=Vector2(0,220)
	scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED
	shop_col.add_child(scroll)
	scroll.add_child(options)
	options.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	button(shop_col,"Voltar",close)
	add_child(voice)
	make_voice()
	shade.hide()

func make_voice() -> void:
	var wave := AudioStreamWAV.new()
	wave.format=AudioStreamWAV.FORMAT_16_BITS
	wave.mix_rate=22050
	var samples := PackedByteArray()
	samples.resize(1320*2)
	for i in 1320:
		var t := float(i)/22050.0
		var envelope := minf(t/.007,1.0)*exp(-t*70.0)
		var s := (sin(t*TAU*630.0)+.28*sin(t*TAU*940.0))*envelope
		samples.encode_s16(i*2,roundi(s*2100))
	wave.data=samples
	voice.stream=wave
	voice.volume_db=-12.0

func button(container: Control,caption: String,callback: Callable) -> Button:
	var b := Button.new()
	Style.button(b)
	b.text=caption
	b.custom_minimum_size.y=42
	container.add_child(b)
	b.pressed.connect(callback)
	return b

func clear_buttons(container: Control) -> void:
	for child in container.get_children():
		container.remove_child(child)
		child.queue_free()

func open_person(i: int,hour: int,person: Node3D=null) -> void:
	resident=i
	message=world.life.social.talk(i,world.life.day,hour,world.life.room>=0)
	shade.color=Color(0,0,0,0.06)
	shade.show()
	dialog.show()
	shop_panel.hide()
	old_camera=world.camera.position
	actor=person if person!=null else world.town.actors[i]
	actor_body=actor.get("body") as Node3D
	old_actor_rotation=actor.rotation.y
	if is_instance_valid(actor_body):
		old_body_y=actor_body.position.y
		old_body_rotation=actor_body.rotation
	var dir: Vector3=world.player.position-actor.position
	actor.rotation.y=atan2(dir.x,dir.z)
	var midpoint: Vector3=(world.player.position+actor.position)*0.5
	if motion!=null and motion.is_running(): motion.kill()
	motion=create_tween()
	motion.tween_property(world.camera,"position",midpoint+Vector3(0,10,10),0.35)
	animate_message(true)
	changed.emit()

func animate_message(entrance := false) -> void:
	var p: Array=world.life.social.PEOPLE[resident]
	var record: Dictionary=world.life.social.record(resident)
	heading.text="%s   ·   ♥ %d/10" % [p[0],floori(float(record.bond)/10)]
	body.text=message
	body.visible_characters=0
	reveal=0.0
	beat=0.0
	speaking=true
	dialog_actions.hide()
	next_button.show()
	next_button.text="Mostrar texto  ›"
	if entrance:
		dialog.modulate.a=0.0
		create_tween().tween_property(dialog,"modulate:a",1.0,0.25)

func advance_dialogue() -> void:
	if resident<0: return
	if speaking:
		complete_message()
	else:
		close()

func complete_message() -> void:
	speaking=false
	body.visible_characters=-1
	voice.stop()
	if is_instance_valid(actor_body):
		actor_body.position.y=old_body_y
		actor_body.rotation=old_body_rotation
	redraw_person()
	next_button.text="Encerrar conversa  ›"
	next_button.grab_focus()

func redraw_person() -> void:
	clear_buttons(dialog_actions)
	var life=world.life
	var bag=life.bag
	var p: Array=life.social.PEOPLE[resident]
	var record: Dictionary=life.social.record(resident)
	var held: String=bag.held()
	var gift_btn := button(dialog_actions,"Presentear",give)
	gift_btn.tooltip_text="Selecione um presente na barra rápida" if held.is_empty() or held in bag.TOOLS else str(bag.NAMES[held])
	gift_btn.disabled=record.gift==life.day or held.is_empty() or held in bag.TOOLS
	var order := button(dialog_actions,"Entregar pedido" if record.quest else "Pedir tarefa",request)
	order.tooltip_text="%d × %s · %d folhas" % [p[2],bag.NAMES[p[1]],p[3]]
	order.disabled=record.done==life.day
	dialog_actions.show()

func open_shop() -> void:
	resident=-1
	buying=true
	message="O que você procura hoje?"
	shade.color=Color("26322888")
	shade.show()
	dialog.hide()
	shop_panel.show()
	scroll.scroll_vertical=0
	redraw_menu()
	options.get_child(0).grab_focus()

func show_panel() -> void:
	if resident>=0: animate_message()
	else: redraw_menu()

func close() -> void:
	speaking=false
	voice.stop()
	if motion!=null and motion.is_running(): motion.kill()
	if resident>=0:
		world.camera.position=old_camera
		if is_instance_valid(actor): actor.rotation.y=old_actor_rotation
		if is_instance_valid(actor_body):
			actor_body.position.y=old_body_y
			actor_body.rotation=old_body_rotation
	actor=null
	actor_body=null
	shade.hide()
	closed.emit()

func redraw_menu() -> void:
	if resident>=0:
		animate_message()
		return
	clear_buttons(options)
	var life=world.life
	var social=life.social
	var bag=life.bag
	shop_heading.text="Armazém  ·  %d folhas" % social.coins
	shop_body.text=message
	button(options,"Comprar  /  Vender" if buying else "Vender  /  Comprar",switch_trade)
	var prices: Dictionary=social.BUY if buying else social.SELL
	for id in prices:
		var b := button(options,"%s    %d folhas   ·   %d na mochila" % [bag.NAMES[id],prices[id],bag.quantity(id)],trade.bind(id))
		b.icon=world.hud.icon_for(id)
		b.expand_icon=true
		b.add_theme_constant_override("icon_max_width",31)
		b.disabled=social.coins<int(prices[id]) or (id in bag.TOOLS and bag.quantity(id)>0) if buying else bag.quantity(id)==0

func give() -> void:
	message=world.life.social.gift(resident,world.life.bag,world.life.day)
	finish()

func request() -> void:
	message=world.life.social.quest(resident,world.life.bag,world.life.day)
	finish()

func trade(id: String) -> void:
	message=world.life.social.trade(world.life.bag,id,buying)
	finish()

func switch_trade() -> void:
	buying=not buying
	message="Escolha o que deseja comprar." if buying else "Escolha o que deseja vender."
	scroll.scroll_vertical=0
	redraw_menu()

func finish() -> void:
	changed.emit()
	redraw_menu()

func on_background(event: InputEvent) -> void:
	if resident<0: return
	if event is InputEventMouseButton and event.button_index==MOUSE_BUTTON_LEFT and event.pressed:
		advance_dialogue()
		get_viewport().set_input_as_handled()

func _process(delta: float) -> void:
	if not shade.visible or not speaking: return
	reveal+=delta*40.0
	var count:=mini(body.text.length(),floori(reveal))
	if count>body.visible_characters:
		body.visible_characters=count
		beat+=delta
		if not voice.playing and DisplayServer.get_name()!="headless":
			voice.pitch_scale=0.86+float(resident)*0.11+sin(reveal)*0.06
			voice.play()
	if is_instance_valid(actor_body):
		actor_body.position.y=old_body_y+absf(sin(reveal*.27))*.035
		actor_body.rotation.z=old_body_rotation.z+sin(reveal*.2)*.035
	if count>=body.text.length(): complete_message()
