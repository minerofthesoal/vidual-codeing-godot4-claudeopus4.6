@tool
## VCGraphNode – a GraphNode that represents one visual code node.
##
## Created programmatically from a node definition dictionary.
## Exposes signal: property_changed(node_id, prop_name, value)
class_name VCGraphNode
extends GraphNode

signal property_changed(node_id: int, prop_name: String, value: Variant)

var node_id: int = -1
var node_type: String = ""
var node_def: Dictionary = {}
var properties: Dictionary = {}

# ── Construction ──────────────────────────────────────────────────────────────

## Build the node UI from a definition dictionary.
## @param id       Unique node id
## @param def      Node definition from NodeDefinitions
## @param saved_props  Optional dictionary of saved property values
func setup(id: int, def: Dictionary, saved_props: Dictionary = {}) -> void:
	node_id = id
	node_type = def.get("type", "")
	node_def = def
	properties = def.get("properties", {}).duplicate(true)

	# Apply any saved property overrides
	for k in saved_props:
		properties[k] = saved_props[k]

	title = def.get("title", node_type)

	# Resizable so users can see long content
	resizable = true

	_build_ui(def)
	_apply_color(def.get("color", Color(0.25, 0.25, 0.25)))

func _apply_color(col: Color) -> void:
	# Tint the title bar using a StyleBoxFlat override
	var style := StyleBoxFlat.new()
	style.bg_color = col
	style.corner_radius_top_left = 4
	style.corner_radius_top_right = 4
	add_theme_stylebox_override("titlebar", style)

# ── UI building ───────────────────────────────────────────────────────────────

func _build_ui(def: Dictionary) -> void:
	var inputs: Array  = def.get("inputs", [])
	var outputs: Array = def.get("outputs", [])
	var props: Dictionary = def.get("properties", {})

	# We need one row per max(inputs, outputs) for the slot system.
	# Ports are associated with child indices.
	# We'll create rows: each row can have a left port, optional property, right port.

	var max_slots := maxi(inputs.size(), outputs.size())
	# Also add one row per editable property that has no corresponding port
	var extra_props: Array[String] = []
	for pk in props.keys():
		extra_props.append(pk)

	# Build slot rows
	for i in range(max_slots):
		var row := HBoxContainer.new()
		row.size_flags_horizontal = Control.SIZE_EXPAND_FILL

		# Left label (input port name)
		var left_label := Label.new()
		if i < inputs.size():
			left_label.text = inputs[i].get("name", "")
		else:
			left_label.text = ""
		left_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(left_label)

		# Right label (output port name)
		var right_label := Label.new()
		if i < outputs.size():
			right_label.text = outputs[i].get("name", "")
		else:
			right_label.text = ""
		right_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		right_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(right_label)

		add_child(row)

		var l_enable := i < inputs.size()
		var r_enable := i < outputs.size()
		var l_type   := inputs[i].get("type", 0) if l_enable else 0
		var r_type   := outputs[i].get("type", 0) if r_enable else 0
		var l_color  := inputs[i].get("color", Color.WHITE) if l_enable else Color.WHITE
		var r_color  := outputs[i].get("color", Color.WHITE) if r_enable else Color.WHITE

		set_slot(get_child_count() - 1, l_enable, l_type, l_color,
				 r_enable, r_type, r_color)

	# Editable property rows (shown below ports)
	if not props.is_empty():
		var sep := HSeparator.new()
		add_child(sep)
		# Separator has no ports
		set_slot(get_child_count() - 1, false, 0, Color.WHITE, false, 0, Color.WHITE)

		for pk in props.keys():
			var prow := HBoxContainer.new()
			prow.size_flags_horizontal = Control.SIZE_EXPAND_FILL

			var lbl := Label.new()
			lbl.text = pk.replace("_", " ").capitalize() + ":"
			lbl.custom_minimum_size = Vector2(80, 0)
			prow.add_child(lbl)

			var widget := _make_property_widget(pk, properties.get(pk))
			if widget:
				prow.add_child(widget)

			add_child(prow)
			set_slot(get_child_count() - 1, false, 0, Color.WHITE, false, 0, Color.WHITE)

# ── Property widget factory ───────────────────────────────────────────────────

func _make_property_widget(prop_name: String, value) -> Control:
	if value is bool:
		var cb := CheckButton.new()
		cb.button_pressed = value
		cb.toggled.connect(func(v): _on_prop_changed(prop_name, v))
		cb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		return cb

	if value is int:
		var sp := SpinBox.new()
		sp.min_value = -1000000
		sp.max_value = 1000000
		sp.value = value
		sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		sp.value_changed.connect(func(v): _on_prop_changed(prop_name, int(v)))
		return sp

	if value is float:
		var sp := SpinBox.new()
		sp.min_value = -1000000.0
		sp.max_value = 1000000.0
		sp.step = 0.01
		sp.value = value
		sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		sp.value_changed.connect(func(v): _on_prop_changed(prop_name, float(v)))
		return sp

	# Default: text edit
	var le := LineEdit.new()
	le.text = str(value) if value != null else ""
	le.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	le.text_changed.connect(func(v): _on_prop_changed(prop_name, v))
	return le

func _on_prop_changed(prop_name: String, value: Variant) -> void:
	properties[prop_name] = value
	property_changed.emit(node_id, prop_name, value)

# ── Serialization ─────────────────────────────────────────────────────────────

func to_dict() -> Dictionary:
	return {
		"id": node_id,
		"type": node_type,
		"position": {"x": position_offset.x, "y": position_offset.y},
		"properties": properties.duplicate(true)
	}
