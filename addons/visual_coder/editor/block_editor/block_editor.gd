@tool
## BlockEditor – Scratch-style block coding editor.
##
## Layout:
##   Left: palette of block categories + items
##   Center: scrollable canvas with block stacks
##   Right: variable declarations panel
class_name BlockEditor
extends HSplitContainer

signal blocks_changed

# ── State ─────────────────────────────────────────────────────────────────────

var _canvas_scroll: ScrollContainer
var _canvas: HFlowContainer   # holds stacks side by side
var _palette_list: Tree
var _var_panel: VBoxContainer
var _all_defs: Array[Dictionary] = []
var _next_id: int = 0
var _variables: Array = []

# ── Lifecycle ─────────────────────────────────────────────────────────────────

func _ready() -> void:
	_build_ui()
	_refresh_defs()
	AddonRegistry.instance().types_changed.connect(_refresh_defs)

func _refresh_defs() -> void:
	_all_defs = BlockDefinitions.get_all()
	_all_defs.append_array(AddonRegistry.instance().get_extra_block_types())
	_rebuild_palette()

# ── UI construction ───────────────────────────────────────────────────────────

func _build_ui() -> void:
	# ── Left: palette ─────────────────────────────────────────────────────────
	var left := VBoxContainer.new()
	left.custom_minimum_size = Vector2(180, 0)
	add_child(left)

	var search := LineEdit.new()
	search.placeholder_text = "Search blocks..."
	search.text_changed.connect(_on_search)
	left.add_child(search)

	_palette_list = Tree.new()
	_palette_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_palette_list.hide_root = true
	_palette_list.item_activated.connect(_on_palette_activated)
	left.add_child(_palette_list)

	var hint := Label.new()
	hint.text = "Double-click to add\nor drag to canvas"
	hint.add_theme_font_size_override("font_size", 10)
	hint.modulate = Color(0.7, 0.7, 0.7)
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	left.add_child(hint)

	# ── Center: canvas ────────────────────────────────────────────────────────
	var center := VBoxContainer.new()
	center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_child(center)

	# Toolbar
	var toolbar := HBoxContainer.new()
	center.add_child(toolbar)

	_add_btn(toolbar, "Clear Canvas", _on_clear)
	_add_btn(toolbar, "Add Stack", _on_add_stack)

	_canvas_scroll = ScrollContainer.new()
	_canvas_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_canvas_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	center.add_child(_canvas_scroll)

	_canvas = HFlowContainer.new()
	_canvas.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_canvas_scroll.add_child(_canvas)

	# ── Right: variables ──────────────────────────────────────────────────────
	var right_scroll := ScrollContainer.new()
	right_scroll.custom_minimum_size = Vector2(200, 0)
	add_child(right_scroll)

	var right := VBoxContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right_scroll.add_child(right)

	var var_title := Label.new()
	var_title.text = "Script Variables"
	var_title.add_theme_font_size_override("font_size", 13)
	right.add_child(var_title)
	right.add_child(HSeparator.new())

	_var_panel = VBoxContainer.new()
	right.add_child(_var_panel)

	_add_btn(right, "+ Add Variable", _on_add_variable)

func _add_btn(parent: Control, text: String, cb: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.pressed.connect(cb)
	parent.add_child(b)
	return b

# ── Palette ───────────────────────────────────────────────────────────────────

func _rebuild_palette(filter: String = "") -> void:
	_palette_list.clear()
	var root := _palette_list.create_item()
	var cat_items: Dictionary = {}

	for def in _all_defs:
		var label: String = def.get("label", "")
		var cat: String = def.get("category", "Other")
		if filter != "" and not filter.to_lower() in label.to_lower():
			continue
		if not cat in cat_items:
			var ci := _palette_list.create_item(root)
			ci.set_text(0, cat)
			ci.set_selectable(0, false)
			ci.set_custom_color(0, def.get("color", Color.WHITE))
			cat_items[cat] = ci
		var item := _palette_list.create_item(cat_items[cat])
		item.set_text(0, "  " + label)
		item.set_metadata(0, def.get("type", ""))

func _on_search(text: String) -> void:
	_rebuild_palette(text)

func _on_palette_activated() -> void:
	var item := _palette_list.get_selected()
	if item == null:
		return
	var type: String = item.get_metadata(0)
	if type == "":
		return
	# Add to first stack that accepts this block, or create a new stack
	_add_block_to_new_stack(type)

# ── Stack management ──────────────────────────────────────────────────────────

func _on_add_stack() -> void:
	_create_stack()

func _create_stack(x: float = 0, _y: float = 0) -> VBoxContainer:
	var stack := VBoxContainer.new()
	stack.name = "stack_%d" % _canvas.get_child_count()
	stack.custom_minimum_size = Vector2(260, 0)
	stack.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	_canvas.add_child(stack)

	# Make it a drop target
	stack.set_meta("_is_stack", true)

	# Drop area hint
	var hint := PanelContainer.new()
	var hs := StyleBoxFlat.new()
	hs.bg_color = Color(1, 1, 1, 0.05)
	hs.border_color = Color(1, 1, 1, 0.15)
	hs.border_width_left = 1; hs.border_width_right = 1
	hs.border_width_top = 1; hs.border_width_bottom = 1
	hs.corner_radius_top_left = 6; hs.corner_radius_top_right = 6
	hs.corner_radius_bottom_left = 6; hs.corner_radius_bottom_right = 6
	hs.content_margin_left = 8; hs.content_margin_top = 8
	hs.content_margin_right = 8; hs.content_margin_bottom = 8
	hint.add_theme_stylebox_override("panel", hs)
	hint.custom_minimum_size = Vector2(0, 40)
	var lbl := Label.new()
	lbl.text = "  drop blocks here"
	lbl.modulate = Color(1, 1, 1, 0.3)
	lbl.add_theme_font_size_override("font_size", 10)
	hint.add_child(lbl)
	stack.add_child(hint)
	stack.set_meta("_hint", hint)

	return stack

func _add_block_to_new_stack(type: String) -> void:
	var def := _find_def(type)
	if def.is_empty():
		return
	var shape: String = def.get("shape", "statement")

	# Hat blocks always start a new stack
	if shape == "hat":
		var stack := _create_stack()
		var block := _create_block(def)
		stack.add_child(block)
		return

	# Look for an existing stack with a hat
	for child in _canvas.get_children():
		if child is VBoxContainer:
			var has_hat := false
			for sc in child.get_children():
				if sc is BlockItem and sc.block_def.get("shape", "") == "hat":
					has_hat = true
					break
			if has_hat:
				var block := _create_block(def)
				child.add_child(block)
				return

	# No suitable stack – create a new one
	var stack := _create_stack()
	var block := _create_block(def)
	stack.add_child(block)

func _create_block(def: Dictionary, saved_props: Dictionary = {}) -> BlockItem:
	var block := BlockItem.new()
	block.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var nid := _next_id
	_next_id += 1
	block.setup(nid, def, saved_props)
	block.block_deleted.connect(_on_block_deleted)
	block.block_changed.connect(func(): blocks_changed.emit())
	return block

func _find_def(type: String) -> Dictionary:
	for d in _all_defs:
		if d["type"] == type:
			return d
	return {}

func _on_block_deleted(block: BlockItem) -> void:
	block.queue_free()
	blocks_changed.emit()

# ── Toolbar actions ───────────────────────────────────────────────────────────

func _on_clear() -> void:
	for child in _canvas.get_children():
		child.queue_free()
	_variables.clear()
	_next_id = 0
	_refresh_var_panel()
	blocks_changed.emit()

# ── Variable panel ────────────────────────────────────────────────────────────

func _on_add_variable() -> void:
	var dialog := ConfirmationDialog.new()
	dialog.title = "Add Variable"
	var vbox := VBoxContainer.new()
	dialog.add_child(vbox)

	var name_field := LineEdit.new()
	name_field.placeholder_text = "var_name"
	vbox.add_child(_labeled("Name", name_field))

	var type_opt := OptionButton.new()
	for t in ["(any)", "int", "float", "String", "bool", "Vector2", "Vector3", "Array", "Dictionary"]:
		type_opt.add_item(t)
	vbox.add_child(_labeled("Type", type_opt))

	var default_field := LineEdit.new()
	default_field.placeholder_text = "default value"
	vbox.add_child(_labeled("Default", default_field))

	add_child(dialog)
	dialog.confirmed.connect(func():
		var vname := name_field.text.strip_edges()
		if vname == "":
			return
		var tidx := type_opt.selected
		var vtype := "" if tidx == 0 else type_opt.get_item_text(tidx)
		_variables.append({"name": vname, "type": vtype, "default": default_field.text.strip_edges()})
		_refresh_var_panel()
		blocks_changed.emit()
		dialog.queue_free()
	)
	dialog.canceled.connect(func(): dialog.queue_free())
	dialog.popup_centered(Vector2(280, 180))

func _labeled(label: String, widget: Control) -> HBoxContainer:
	var row := HBoxContainer.new()
	var lbl := Label.new()
	lbl.text = label
	lbl.custom_minimum_size = Vector2(65, 0)
	row.add_child(lbl)
	widget.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(widget)
	return row

func _refresh_var_panel() -> void:
	for c in _var_panel.get_children():
		c.queue_free()
	for v in _variables:
		var row := HBoxContainer.new()
		var lbl := Label.new()
		lbl.text = v.get("name", "") + ": " + v.get("type", "var")
		lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(lbl)
		var del := Button.new()
		del.text = "✕"
		del.flat = true
		var vc: Dictionary = v  # capture for lambda
		del.pressed.connect(func(): _variables.erase(vc); _refresh_var_panel(); blocks_changed.emit())
		row.add_child(del)
		_var_panel.add_child(row)

# ── Serialization ─────────────────────────────────────────────────────────────

func get_block_data() -> Dictionary:
	var stacks_arr: Array = []
	for child in _canvas.get_children():
		if not child is VBoxContainer:
			continue
		var blocks_arr: Array = []
		for sc in child.get_children():
			if sc is BlockItem:
				blocks_arr.append(sc.to_dict())
		if not blocks_arr.is_empty():
			stacks_arr.append({"blocks": blocks_arr})

	return {
		"version": VCResource.VERSION,
		"type": "block_script",
		"stacks": stacks_arr,
		"variables": _variables.duplicate(true)
	}

func load_block_data(data: Dictionary) -> void:
	_on_clear()
	_variables = data.get("variables", [])

	var stacks_arr: Array = data.get("stacks", [])
	for stack_data in stacks_arr:
		var stack := _create_stack()
		for block_data in stack_data.get("blocks", []):
			_load_block_into(block_data, stack)

	_refresh_var_panel()

func _load_block_into(block_data: Dictionary, container: Control) -> void:
	var type: String = block_data.get("type", "")
	var def := _find_def(type)
	if def.is_empty():
		return
	var block := _create_block(def, block_data.get("properties", {}))
	container.add_child(block)

	# Recursively load inner blocks
	for inner_bd in block_data.get("inner", []):
		if block._inner_container:
			_load_block_into(inner_bd, block._inner_container)
	for else_bd in block_data.get("inner_else", []):
		if block._else_container:
			_load_block_into(else_bd, block._else_container)
