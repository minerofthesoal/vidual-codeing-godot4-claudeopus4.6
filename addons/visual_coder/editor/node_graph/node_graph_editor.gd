@tool
## NodeGraphEditor – GraphEdit-based visual coding canvas.
##
## Provides:
##  - A left palette panel listing all node types by category
##  - A central GraphEdit canvas for creating and connecting nodes
##  - A properties panel on the right for selected node details
##  - Full serialization / deserialization of graph state
class_name NodeGraphEditor
extends HSplitContainer

signal graph_changed

# ── State ─────────────────────────────────────────────────────────────────────

var _graph: GraphEdit
var _palette_list: Tree
var _prop_panel: VBoxContainer
var _prop_scroll: ScrollContainer
var _next_id: int = 0
var _nodes: Dictionary = {}        # id -> VCGraphNode
var _connections: Array = []       # [{from_node, from_port, to_node, to_port}]
var _variables: Array = []         # [{name, type, default}]
var _selected_node_id: int = -1
var _all_defs: Array[Dictionary] = []

# ── Lifecycle ─────────────────────────────────────────────────────────────────

func _ready() -> void:
	_build_ui()
	_refresh_defs()
	AddonRegistry.instance().types_changed.connect(_refresh_defs)

func _refresh_defs() -> void:
	_all_defs = NodeDefinitions.get_all()
	_all_defs.append_array(AddonRegistry.instance().get_extra_node_types())
	_rebuild_palette()

# ── UI construction ───────────────────────────────────────────────────────────

func _build_ui() -> void:
	# ── Left: palette + search ────────────────────────────────────────────────
	var left := VBoxContainer.new()
	left.custom_minimum_size = Vector2(200, 0)
	add_child(left)

	var search := LineEdit.new()
	search.placeholder_text = "Search nodes..."
	search.text_changed.connect(_on_search_changed)
	left.add_child(search)

	_palette_list = Tree.new()
	_palette_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_palette_list.hide_root = true
	_palette_list.item_activated.connect(_on_palette_item_activated)
	left.add_child(_palette_list)

	var hint := Label.new()
	hint.text = "Double-click to add node\nRight-click canvas to add"
	hint.add_theme_font_size_override("font_size", 10)
	hint.modulate = Color(0.7, 0.7, 0.7)
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	left.add_child(hint)

	# ── Center: GraphEdit ──────────────────────────────────────────────────────
	var center := VBoxContainer.new()
	center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_child(center)

	_graph = GraphEdit.new()
	_graph.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_graph.right_disconnects = true
	_graph.snapping_enabled = true
	_graph.snapping_distance = 16
	# Allow all port type combinations (we validate manually)
	for i in range(12):
		for j in range(12):
			_graph.add_valid_connection_type(i, j)
	_graph.connection_request.connect(_on_connection_request)
	_graph.disconnection_request.connect(_on_disconnection_request)
	_graph.node_selected.connect(_on_node_selected)
	_graph.node_deselected.connect(_on_node_deselected)
	_graph.gui_input.connect(_on_graph_gui_input)
	_graph.delete_nodes_request.connect(_on_delete_nodes_request)
	center.add_child(_graph)

	# Graph toolbar
	var toolbar := HBoxContainer.new()
	center.add_child(toolbar)
	center.move_child(toolbar, 0)

	_add_toolbar_button(toolbar, "Add Variable", _on_add_variable_pressed)
	_add_toolbar_button(toolbar, "Clear Graph", _on_clear_pressed)
	_add_toolbar_button(toolbar, "Auto-Arrange", _on_arrange_pressed)

	# Variable list
	var var_lbl := Label.new()
	var_lbl.text = "  Script Variables:"
	toolbar.add_child(var_lbl)

	# ── Right: properties ──────────────────────────────────────────────────────
	_prop_scroll = ScrollContainer.new()
	_prop_scroll.custom_minimum_size = Vector2(220, 0)
	add_child(_prop_scroll)

	_prop_panel = VBoxContainer.new()
	_prop_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_prop_scroll.add_child(_prop_panel)

	_show_empty_props()

func _add_toolbar_button(parent: Control, text: String, callback: Callable) -> Button:
	var btn := Button.new()
	btn.text = text
	btn.pressed.connect(callback)
	parent.add_child(btn)
	return btn

# ── Palette ───────────────────────────────────────────────────────────────────

func _rebuild_palette(filter: String = "") -> void:
	_palette_list.clear()
	var root := _palette_list.create_item()

	var cat_items: Dictionary = {}
	for def in _all_defs:
		var title: String = def.get("title", "")
		var cat: String = def.get("category", "Other")
		if filter != "" and not filter.to_lower() in title.to_lower():
			continue
		if not cat in cat_items:
			var cat_item := _palette_list.create_item(root)
			cat_item.set_text(0, cat)
			cat_item.set_selectable(0, false)
			cat_item.set_custom_color(0, def.get("color", Color.WHITE))
			cat_items[cat] = cat_item
		var item := _palette_list.create_item(cat_items[cat])
		item.set_text(0, "  " + title)
		item.set_metadata(0, def.get("type", ""))

func _on_search_changed(text: String) -> void:
	_rebuild_palette(text)

func _on_palette_item_activated() -> void:
	var item := _palette_list.get_selected()
	if item == null:
		return
	var type: String = item.get_metadata(0)
	if type == "":
		return
	_add_node_at_center(type)

# ── Node creation ─────────────────────────────────────────────────────────────

func _add_node_at_center(type: String) -> void:
	var center_pos := _graph.get_size() / 2 - _graph.scroll_offset
	_add_node(type, center_pos)

func _add_node(type: String, position: Vector2, id: int = -1,
		saved_props: Dictionary = {}) -> VCGraphNode:
	var def := _find_def(type)
	if def.is_empty():
		push_error("NodeGraphEditor: unknown node type '%s'" % type)
		return null

	var nid := id if id >= 0 else _next_id
	_next_id = maxi(_next_id + 1, nid + 1)

	var gn := VCGraphNode.new()
	gn.name = "node_%d" % nid
	_graph.add_child(gn)
	gn.setup(nid, def, saved_props)
	gn.position_offset = position
	gn.property_changed.connect(_on_node_property_changed)

	_nodes[nid] = gn
	graph_changed.emit()
	return gn

func _find_def(type: String) -> Dictionary:
	for d in _all_defs:
		if d["type"] == type:
			return d
	return {}

# ── Connections ───────────────────────────────────────────────────────────────

func _on_connection_request(from_name: StringName, from_port: int,
		to_name: StringName, to_port: int) -> void:
	# Validate: exec→exec or data→data (same type or variant)
	var from_node := _graph.get_node(NodePath(from_name)) as VCGraphNode
	var to_node   := _graph.get_node(NodePath(to_name))   as VCGraphNode
	if from_node == null or to_node == null:
		return

	var from_def := _find_def(from_node.node_type)
	var to_def   := _find_def(to_node.node_type)
	var from_outs: Array = from_def.get("outputs", [])
	var to_ins: Array    = to_def.get("inputs", [])

	if from_port >= from_outs.size() or to_port >= to_ins.size():
		return

	var ftype: int = from_outs[from_port].get("type", NodeDefinitions.T_VARIANT)
	var ttype: int = to_ins[to_port].get("type", NodeDefinitions.T_VARIANT)

	# Exec can only connect to exec
	var exec := NodeDefinitions.T_EXEC
	if (ftype == exec) != (ttype == exec):
		return

	# Data: variant accepts anything
	if ftype != exec and ttype != exec:
		if ftype != ttype and ftype != NodeDefinitions.T_VARIANT and ttype != NodeDefinitions.T_VARIANT:
			# Type mismatch – still allow but show warning
			push_warning("NodeGraphEditor: connecting mismatched types %d→%d" % [ftype, ttype])

	# Remove any existing connection to the same input port
	for c in _connections.duplicate():
		if c["to_node"] == to_node.node_id and c["to_port"] == to_port:
			_graph.disconnect_node(
				StringName("node_%d" % c["from_node"]), c["from_port"],
				StringName("node_%d" % c["to_node"]),   c["to_port"])
			_connections.erase(c)

	_graph.connect_node(from_name, from_port, to_name, to_port)
	_connections.append({
		"from_node": from_node.node_id,
		"from_port": from_port,
		"to_node":   to_node.node_id,
		"to_port":   to_port
	})
	graph_changed.emit()

func _on_disconnection_request(from_name: StringName, from_port: int,
		to_name: StringName, to_port: int) -> void:
	_graph.disconnect_node(from_name, from_port, to_name, to_port)
	var fn_node := _graph.get_node(NodePath(from_name)) as VCGraphNode
	var tn_node := _graph.get_node(NodePath(to_name))   as VCGraphNode
	if fn_node == null or tn_node == null:
		return
	for c in _connections.duplicate():
		if c["from_node"] == fn_node.node_id and c["from_port"] == from_port \
				and c["to_node"] == tn_node.node_id and c["to_port"] == to_port:
			_connections.erase(c)
	graph_changed.emit()

# ── Node selection / properties panel ────────────────────────────────────────

func _on_node_selected(node: Node) -> void:
	if node is VCGraphNode:
		_selected_node_id = node.node_id
		_show_node_props(node)

func _on_node_deselected(_node: Node) -> void:
	_selected_node_id = -1
	_show_empty_props()

func _show_empty_props() -> void:
	for c in _prop_panel.get_children():
		c.queue_free()
	var lbl := Label.new()
	lbl.text = "Select a node to\nedit its properties."
	lbl.add_theme_font_size_override("font_size", 11)
	lbl.modulate = Color(0.7, 0.7, 0.7)
	_prop_panel.add_child(lbl)

func _show_node_props(gn: VCGraphNode) -> void:
	for c in _prop_panel.get_children():
		c.queue_free()

	var title := Label.new()
	title.text = gn.title
	title.add_theme_font_size_override("font_size", 14)
	_prop_panel.add_child(title)

	var sep := HSeparator.new()
	_prop_panel.add_child(sep)

	if gn.properties.is_empty():
		var lbl := Label.new()
		lbl.text = "No properties."
		lbl.add_theme_font_size_override("font_size", 11)
		lbl.modulate = Color(0.7, 0.7, 0.7)
		_prop_panel.add_child(lbl)
		return

	for pk in gn.properties.keys():
		var row := HBoxContainer.new()
		row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_prop_panel.add_child(row)

		var lbl := Label.new()
		lbl.text = pk.replace("_", " ").capitalize()
		lbl.custom_minimum_size = Vector2(90, 0)
		row.add_child(lbl)

		var widget := _make_prop_widget(gn, pk, gn.properties[pk])
		if widget:
			row.add_child(widget)

func _make_prop_widget(gn: VCGraphNode, pk: String, value) -> Control:
	if value is bool:
		var cb := CheckButton.new()
		cb.button_pressed = value
		cb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		cb.toggled.connect(func(v): gn.properties[pk] = v; graph_changed.emit())
		return cb
	if value is int:
		var sp := SpinBox.new()
		sp.min_value = -10000000; sp.max_value = 10000000
		sp.value = value
		sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		sp.value_changed.connect(func(v): gn.properties[pk] = int(v); graph_changed.emit())
		return sp
	if value is float:
		var sp := SpinBox.new()
		sp.min_value = -10000000.0; sp.max_value = 10000000.0; sp.step = 0.001
		sp.value = value
		sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		sp.value_changed.connect(func(v): gn.properties[pk] = float(v); graph_changed.emit())
		return sp
	var le := LineEdit.new()
	le.text = str(value) if value != null else ""
	le.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	le.text_changed.connect(func(v): gn.properties[pk] = v; graph_changed.emit())
	return le

func _on_node_property_changed(_nid: int, _prop: String, _val: Variant) -> void:
	graph_changed.emit()

# ── Context menu ──────────────────────────────────────────────────────────────

func _on_graph_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
			_show_context_menu(event.position)

func _show_context_menu(at_pos: Vector2) -> void:
	var popup := PopupMenu.new()
	add_child(popup)

	# Group by category
	var cats := NodeDefinitions.get_categories()
	for addon_def in AddonRegistry.instance().get_extra_node_types():
		var cat: String = addon_def.get("category", "Addon")
		if not cat in cats:
			cats.append(cat)

	var item_id := 0
	for cat in cats:
		# Add disabled category header (no id, will not trigger id_pressed)
		popup.add_separator(cat)
		for d in _all_defs:
			if d["category"] != cat:
				continue
			popup.add_item("  " + d.get("title", ""), item_id)
			popup.set_item_metadata(popup.item_count - 1, d.get("type", ""))
			item_id += 1

	# Convert local GraphEdit position → graph-space position
	var graph_pos := at_pos / _graph.zoom + _graph.scroll_offset

	popup.popup(Rect2(get_global_mouse_position(), Vector2.ZERO))

	popup.id_pressed.connect(func(id: int):
		var idx := popup.get_item_index(id)
		if idx >= 0:
			var meta = popup.get_item_metadata(idx)
			if meta is String and meta != "":
				_add_node(meta, graph_pos)
		popup.queue_free()
	)

# ── Delete nodes ──────────────────────────────────────────────────────────────

func _on_delete_nodes_request(nodes_to_delete: Array) -> void:
	for node_name in nodes_to_delete:
		var gn := _graph.get_node(NodePath(node_name)) as VCGraphNode
		if gn == null:
			continue
		# Remove all connections involving this node
		var nid := gn.node_id
		for c in _connections.duplicate():
			if c["from_node"] == nid or c["to_node"] == nid:
				_graph.disconnect_node(
					StringName("node_%d" % c["from_node"]), c["from_port"],
					StringName("node_%d" % c["to_node"]),   c["to_port"])
				_connections.erase(c)
		_nodes.erase(nid)
		gn.queue_free()
	graph_changed.emit()

# ── Toolbar actions ───────────────────────────────────────────────────────────

func _on_add_variable_pressed() -> void:
	var dialog := _VariableDialog.new()
	add_child(dialog)
	dialog.confirmed.connect(func():
		_variables.append({
			"name": dialog.var_name,
			"type": dialog.var_type,
			"default": dialog.var_default
		})
		graph_changed.emit()
		dialog.queue_free()
	)
	dialog.canceled.connect(func(): dialog.queue_free())
	dialog.popup_centered(Vector2(300, 180))

func _on_clear_pressed() -> void:
	for nid in _nodes.keys():
		_nodes[nid].queue_free()
	_nodes.clear()
	_connections.clear()
	_variables.clear()
	_next_id = 0
	graph_changed.emit()

func _on_arrange_pressed() -> void:
	# Simple auto-layout: spread nodes in a grid
	var spacing := Vector2(280, 180)
	var col := 0
	var row := 0
	for nid in _nodes:
		_nodes[nid].position_offset = Vector2(col * spacing.x + 50, row * spacing.y + 50)
		col += 1
		if col >= 4:
			col = 0
			row += 1
	graph_changed.emit()

# ── Serialization ─────────────────────────────────────────────────────────────

func get_graph_data() -> Dictionary:
	var nodes_arr: Array = []
	for nid in _nodes:
		nodes_arr.append(_nodes[nid].to_dict())
	return {
		"version": VCResource.VERSION,
		"type": "node_graph",
		"nodes": nodes_arr,
		"connections": _connections.duplicate(true),
		"variables": _variables.duplicate(true)
	}

func load_graph_data(data: Dictionary) -> void:
	# Clear existing
	for nid in _nodes.keys():
		_nodes[nid].queue_free()
	_nodes.clear()
	_connections.clear()
	_variables = data.get("variables", [])
	_next_id = 0

	# Recreate nodes
	var nodes_arr: Array = data.get("nodes", [])
	for nd in nodes_arr:
		var pos := Vector2(nd.get("position", {}).get("x", 0.0),
				nd.get("position", {}).get("y", 0.0))
		_add_node(nd.get("type", ""), pos, nd.get("id", -1),
				nd.get("properties", {}))

	# Recreate connections
	for c in data.get("connections", []):
		var fn_name := StringName("node_%d" % c["from_node"])
		var tn_name := StringName("node_%d" % c["to_node"])
		if _graph.get_node_or_null(NodePath(fn_name)) and _graph.get_node_or_null(NodePath(tn_name)):
			_graph.connect_node(fn_name, c["from_port"], tn_name, c["to_port"])
			_connections.append(c.duplicate())

# ── Inner helper: variable dialog ─────────────────────────────────────────────

class _VariableDialog extends ConfirmationDialog:
	var var_name: String = "my_var"
	var var_type: String = ""
	var var_default: String = ""

	func _init() -> void:
		title = "Add Script Variable"
		var vbox := VBoxContainer.new()
		add_child(vbox)

		vbox.add_child(_row("Name:", "my_var", func(v): var_name = v))

		var type_row := HBoxContainer.new()
		type_row.add_child(_lbl("Type:"))
		var opt := OptionButton.new()
		for t in ["(any)", "int", "float", "String", "bool", "Vector2", "Vector3", "Array", "Dictionary", "Node"]:
			opt.add_item(t)
		opt.item_selected.connect(func(idx: int):
			var_type = "" if idx == 0 else opt.get_item_text(idx))
		type_row.add_child(opt)
		vbox.add_child(type_row)

		vbox.add_child(_row("Default:", "", func(v): var_default = v))

	func _row(label: String, placeholder: String, on_change: Callable) -> HBoxContainer:
		var r := HBoxContainer.new()
		r.add_child(_lbl(label))
		var le := LineEdit.new()
		le.placeholder_text = placeholder
		le.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		le.text_changed.connect(on_change)
		r.add_child(le)
		return r

	func _lbl(text: String) -> Label:
		var l := Label.new()
		l.text = text
		l.custom_minimum_size = Vector2(70, 0)
		return l
