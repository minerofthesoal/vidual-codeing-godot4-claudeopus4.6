@tool
## BlockItem – visual representation of one block in the block editor.
##
## Blocks are VBoxContainers rendered with coloured backgrounds.
## Control blocks contain inner VBoxContainers for nested blocks.
class_name BlockItem
extends PanelContainer

signal block_moved(block_item: BlockItem, new_parent_stack: Node, index: int)
signal block_deleted(block_item: BlockItem)
signal block_changed

const CORNER_RADIUS := 6
const MIN_HEIGHT := 36
const NOTCH_W := 16   # width of connector notch (visual only)
const INDENT_W := 20  # indent for inner blocks

var block_id: int = -1
var block_type: String = ""
var block_def: Dictionary = {}
var properties: Dictionary = {}

# Child containers for inner/else blocks
var _inner_container: VBoxContainer = null
var _else_container: VBoxContainer = null

var _header: HBoxContainer
var _field_widgets: Dictionary = {}   # prop_name -> Control

var _dragging := false
var _drag_start_pos := Vector2.ZERO

# ── Construction ──────────────────────────────────────────────────────────────

func setup(id: int, def: Dictionary, saved_props: Dictionary = {}) -> void:
	block_id = id
	block_type = def.get("type", "")
	block_def = def
	properties = def.get("properties", {}).duplicate(true) if "properties" in def else {}
	# Copy field defaults into properties
	for field in def.get("fields", []):
		var fname: String = field.get("name", "")
		if fname != "" and not fname in properties:
			properties[fname] = field.get("default", "")
	# Apply any saved overrides
	for k in saved_props:
		properties[k] = saved_props[k]

	_build_ui(def)
	_apply_style(def.get("color", Color(0.3, 0.3, 0.35)))

func _apply_style(col: Color) -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = col
	style.corner_radius_top_left = CORNER_RADIUS
	style.corner_radius_top_right = CORNER_RADIUS
	style.corner_radius_bottom_left = CORNER_RADIUS
	style.corner_radius_bottom_right = CORNER_RADIUS
	style.content_margin_left = 8
	style.content_margin_right = 8
	style.content_margin_top = 4
	style.content_margin_bottom = 4
	add_theme_stylebox_override("panel", style)

# ── UI building ───────────────────────────────────────────────────────────────

func _build_ui(def: Dictionary) -> void:
	var shape: String = def.get("shape", "statement")
	var label: String = def.get("label", block_type)
	var fields: Array = def.get("fields", [])
	var has_inner: bool = def.get("has_inner", false)
	var has_else: bool  = def.get("has_else", false)

	custom_minimum_size.y = MIN_HEIGHT

	var outer := VBoxContainer.new()
	outer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_child(outer)

	# ── Header row (label + fields) ───────────────────────────────────────────
	_header = HBoxContainer.new()
	_header.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	outer.add_child(_header)

	# Drag handle
	var drag_lbl := Label.new()
	drag_lbl.text = "⣿"
	drag_lbl.modulate = Color(1, 1, 1, 0.5)
	drag_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_header.add_child(drag_lbl)

	# Block label – may be split around fields
	# Parse label for {field_name} placeholders
	var parts := _parse_label(label, fields)
	for part in parts:
		if part["is_field"]:
			var widget := _make_field_widget(part["field"])
			_header.add_child(widget)
		else:
			var lbl := Label.new()
			lbl.text = part["text"]
			lbl.add_theme_font_size_override("font_size", 12)
			lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
			_header.add_child(lbl)

	# Delete button (only for non-hat blocks)
	if shape != "hat":
		var del_btn := Button.new()
		del_btn.text = "✕"
		del_btn.flat = true
		del_btn.custom_minimum_size = Vector2(24, 24)
		del_btn.modulate = Color(1, 1, 1, 0.6)
		del_btn.pressed.connect(func(): block_deleted.emit(self))
		_header.add_child(del_btn)

	# ── Inner block area (for control blocks) ─────────────────────────────────
	if has_inner:
		var inner_wrapper := PanelContainer.new()
		inner_wrapper.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var style_in := StyleBoxFlat.new()
		style_in.bg_color = Color(0, 0, 0, 0.25)
		style_in.corner_radius_top_left = 0
		style_in.corner_radius_bottom_left = 0
		style_in.corner_radius_top_right = CORNER_RADIUS
		style_in.corner_radius_bottom_right = CORNER_RADIUS
		style_in.content_margin_left = INDENT_W
		style_in.content_margin_right = 4
		style_in.content_margin_top = 4
		style_in.content_margin_bottom = 4
		inner_wrapper.add_theme_stylebox_override("panel", style_in)
		outer.add_child(inner_wrapper)

		_inner_container = VBoxContainer.new()
		_inner_container.name = "InnerContainer"
		_inner_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		inner_wrapper.add_child(_inner_container)

		# Drop hint
		var hint := _make_drop_hint()
		_inner_container.add_child(hint)

		if has_else:
			var else_lbl := PanelContainer.new()
			var sl := StyleBoxFlat.new()
			sl.bg_color = def.get("color", Color.GRAY).darkened(0.2)
			sl.content_margin_left = 8; sl.content_margin_top = 2; sl.content_margin_bottom = 2
			else_lbl.add_theme_stylebox_override("panel", sl)
			var el := Label.new(); el.text = "else"
			else_lbl.add_child(el)
			outer.add_child(else_lbl)

			var else_wrapper := PanelContainer.new()
			else_wrapper.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			else_wrapper.add_theme_stylebox_override("panel", style_in.duplicate())
			outer.add_child(else_wrapper)

			_else_container = VBoxContainer.new()
			_else_container.name = "ElseContainer"
			_else_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			else_wrapper.add_child(_else_container)

			_else_container.add_child(_make_drop_hint())

func _make_drop_hint() -> Label:
	var lbl := Label.new()
	lbl.text = "  drop blocks here..."
	lbl.add_theme_font_size_override("font_size", 10)
	lbl.modulate = Color(1, 1, 1, 0.3)
	lbl.custom_minimum_size = Vector2(0, 24)
	return lbl

# ── Label parsing ─────────────────────────────────────────────────────────────

func _parse_label(label: String, fields: Array) -> Array:
	# If no fields, just return the label text
	if fields.is_empty():
		return [{"is_field": false, "text": label}]

	var parts := []
	# Insert each field inline – simple approach: show label then all fields
	parts.append({"is_field": false, "text": label + " "})
	for field in fields:
		parts.append({"is_field": true, "field": field})
	return parts

# ── Field widgets ─────────────────────────────────────────────────────────────

func _make_field_widget(field: Dictionary) -> Control:
	var fname: String = field.get("name", "")
	var ftype: String = field.get("type", "string")
	var fdefault = properties.get(fname, field.get("default", ""))

	var widget: Control
	match ftype:
		"bool":
			var cb := CheckButton.new()
			cb.button_pressed = bool(fdefault)
			cb.toggled.connect(func(v): _set_prop(fname, v))
			widget = cb
		"int":
			var sp := SpinBox.new()
			sp.min_value = -999999; sp.max_value = 999999
			sp.value = int(fdefault) if fdefault is int or fdefault is float else 0
			sp.custom_minimum_size = Vector2(70, 0)
			sp.value_changed.connect(func(v): _set_prop(fname, int(v)))
			widget = sp
		"float":
			var sp := SpinBox.new()
			sp.min_value = -999999.0; sp.max_value = 999999.0; sp.step = 0.01
			sp.value = float(fdefault) if fdefault is float or fdefault is int else 0.0
			sp.custom_minimum_size = Vector2(80, 0)
			sp.value_changed.connect(func(v): _set_prop(fname, float(v)))
			widget = sp
		"choice":
			var opt := OptionButton.new()
			var options: Array = field.get("options", [])
			for op in options:
				opt.add_item(str(op))
			var cur_idx := 0
			for oi in range(options.size()):
				if str(options[oi]) == str(fdefault):
					cur_idx = oi
					break
			opt.select(cur_idx)
			opt.item_selected.connect(func(idx: int): _set_prop(fname, opt.get_item_text(idx)))
			widget = opt
		_:  # "string" and fallback
			var le := LineEdit.new()
			le.text = str(fdefault) if fdefault != null else ""
			le.custom_minimum_size = Vector2(80, 0)
			le.text_changed.connect(func(v): _set_prop(fname, v))
			widget = le

	_field_widgets[fname] = widget
	return widget

func _set_prop(name: String, value) -> void:
	properties[name] = value
	block_changed.emit()

# ── Drag & drop ───────────────────────────────────────────────────────────────

func _gui_input(event: InputEvent) -> void:
	if block_def.get("shape", "") == "hat":
		return  # Hat blocks cannot be dragged
	if event is InputEventMouseButton:
		var mbe := event as InputEventMouseButton
		if mbe.button_index == MOUSE_BUTTON_LEFT:
			if mbe.pressed:
				_dragging = true
				_drag_start_pos = get_global_mouse_position()
			else:
				_dragging = false
	elif event is InputEventMouseMotion and _dragging:
		if get_global_mouse_position().distance_to(_drag_start_pos) > 5:
			_dragging = false
			# Build a lightweight drag preview label
			var preview := Label.new()
			preview.text = block_def.get("label", "Block")
			preview.add_theme_font_size_override("font_size", 12)
			var ps := StyleBoxFlat.new()
			ps.bg_color = block_def.get("color", Color(0.3, 0.3, 0.35))
			ps.corner_radius_top_left = 4
			ps.corner_radius_top_right = 4
			ps.corner_radius_bottom_left = 4
			ps.corner_radius_bottom_right = 4
			ps.content_margin_left = 8
			ps.content_margin_right = 8
			ps.content_margin_top = 4
			ps.content_margin_bottom = 4
			preview.add_theme_stylebox_override("normal", ps)
			force_drag(to_dict(), preview)

func _get_drag_data(_at_position: Vector2) -> Variant:
	return to_dict()

# ── Serialization ─────────────────────────────────────────────────────────────

func get_inner_blocks() -> Array:
	return _serialize_container(_inner_container)

func get_else_blocks() -> Array:
	return _serialize_container(_else_container)

func _serialize_container(container: VBoxContainer) -> Array:
	if container == null:
		return []
	var result := []
	for child in container.get_children():
		if child is BlockItem:
			result.append(child.to_dict())
	return result

func to_dict() -> Dictionary:
	var d := {
		"id": block_id,
		"type": block_type,
		"properties": properties.duplicate(true)
	}
	var inner := get_inner_blocks()
	if not inner.is_empty():
		d["inner"] = inner
	var else_b := get_else_blocks()
	if not else_b.is_empty():
		d["inner_else"] = else_b
	return d
