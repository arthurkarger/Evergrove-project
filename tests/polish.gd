extends SceneTree
var failures := 0
func check(ok: bool,msg: String) -> void:
	if not ok:
		printerr("FAIL: ",msg)
		failures+=1

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var w=preload("res://main.tscn").instantiate()
	root.add_child(w)
	await physics_frame
	var art = preload("res://art_assets.gd")
	check(art.icon("../unknown")==null,"Reject unknown art id")
	check(art.surface("unknown")==null,"Reject unknown surface id")
	for id in w.life.bag.NAMES:
		var icon: Texture2D = w.hud.icon_for(id)
		check(icon!=null,"Illustrated icon "+id)
		var external: Texture2D = art.icon(id)
		if external != null:
			check(icon==external,"Imported icon preferred "+id)
	w.hud.toggle()
	await process_frame
	check(w.hud.shade.visible and w.hud.cells.size()==24,"Inventory opens")
	for buttons in [w.hud.quick,w.hud.cells]:
		for b in buttons:
			var art_node := b.get_node("CenteredIcon") as TextureRect
			check(art_node.position.distance_to((b.size-art_node.size)*0.5)<1.1,"Icon centered independently of count")
			check(b.icon==null and b.text=="","No native icon/text offset")
			check(art_node.mouse_filter==Control.MOUSE_FILTER_IGNORE,"Icon does not intercept input")
	for b in [w.hud.build_button,w.hud.run_button,w.graphics.menu_button]:
		var art_node := b.get_node("CenteredIcon") as TextureRect
		check(art_node.position.distance_to((b.size-art_node.size)*0.5)<1.1,"HUD control icon centered")
	var count_node := w.hud.cells[4].get_node("ItemCount") as Label
	check(count_node.text=="8","Stack count separate from icon")
	var normalized := preload("res://ui_style.gd").centered_texture(w.hud.icon_for("axe"))
	var art_bounds := normalized.get_image().get_used_rect()
	check((Vector2(art_bounds.position)+Vector2(art_bounds.size)*0.5).distance_to(Vector2(32,32))<1.1,"Visible artwork centered")
	w.hud.toggle()
	w.toggle_bag(true)
	w.hud.hide()
	w.village_menu.open_person(0,10)
	var ui=w.village_menu
	check(ui.dialog.visible and not ui.shop_panel.visible and ui.speaking,"NPC bottom dialogue")
	check(ui.body.visible_characters==0 and not ui.dialog_actions.visible,"Typewriter starts before actions")
	ui.advance_dialogue()
	check(not ui.speaking and ui.body.visible_characters==-1 and ui.dialog_actions.visible,"Tap reveals and offers choices")
	ui.request()
	check(w.life.social.record(0).quest and ui.speaking,"Request preserves gameplay and animates response")
	ui.close()
	check(not ui.shade.visible and w.hud.visible and w.pad.visible,"Conversation returns controls")
	ui.open_shop()
	check(ui.shop_panel.visible and not ui.dialog.visible,"Shop has separate UI")
	ui.close()
	w.home_ui.open("craft")
	check(w.home_ui.menu.visible and w.home_ui.page=="craft","Crafting UI")
	w.home_ui.close()
	print("Polish integration failures: ",failures)
	quit(1 if failures else 0)
