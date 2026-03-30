@tool
## MainEditor – the top-level panel shown when the "VisualCoder" tab is selected.
##
## Contains:
##   - A top toolbar (New, Open, Save, Generate Code, Apply to Script)
##   - A TabContainer switching between Node Graph and Block Editor
##   - A bottom status bar
class_name VCMainEditor
extends VBoxContainer

# Injected by plugin.gd
var editor_interface: EditorInterface = null

# ── Children ──────────────────────────────────────────────────────────────────
var _tabs: TabContainer
var _node_graph_editor: NodeGraphEditor
var _block_editor: BlockEditor
var _status_bar: Label
var _file_label: Label
var _code_popup: Window = null

var _current_resource: VCResource = null
var _dirty: bool = false
var _current_file_path: String = ""

# ── Lifecycle ─────────────────────────────────────────────────────────────────

func _ready() -> void:
	_build_ui()

# ── UI construction ───────────────────────────────────────────────────────────

func _build_ui() -> void:
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical   = Control.SIZE_EXPAND_FILL

	# ── Top toolbar ───────────────────────────────────────────────────────────
	var toolbar := HBoxContainer.new()
	add_child(toolbar)

	_add_btn(toolbar, "New Node Graph",    _on_new_node_graph)
	_add_btn(toolbar, "New Block Script",  _on_new_block_script)
	toolbar.add_child(VSeparator.new())
	_add_btn(toolbar, "Open…",             _on_open)
	_add_btn(toolbar, "Save",              _on_save)
	_add_btn(toolbar, "Save As…",          _on_save_as)
	toolbar.add_child(VSeparator.new())
	_add_btn(toolbar, "Generate Code",     _on_generate_code)
	_add_btn(toolbar, "Apply to Script",   _on_apply_to_script)
	toolbar.add_child(VSeparator.new())
	_add_btn(toolbar, "Addon Manager",     _on_addon_manager)

	# Current file label
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	toolbar.add_child(spacer)
	_file_label = Label.new()
	_file_label.name = "FilePath"
	_file_label.text = "[unsaved]"
	_file_label.modulate = Color(0.8, 0.8, 0.8)
	_file_label.add_theme_font_size_override("font_size", 11)
	toolbar.add_child(_file_label)

	# ── Tab container ─────────────────────────────────────────────────────────
	_tabs = TabContainer.new()
	_tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(_tabs)

	# Node Graph tab
	_node_graph_editor = NodeGraphEditor.new()
	_node_graph_editor.name = "Node Graph"
	_node_graph_editor.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_tabs.add_child(_node_graph_editor)
	_node_graph_editor.graph_changed.connect(_on_graph_changed)

	# Block Editor tab
	_block_editor = BlockEditor.new()
	_block_editor.name = "Block Editor"
	_block_editor.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_tabs.add_child(_block_editor)
	_block_editor.blocks_changed.connect(_on_blocks_changed)

	# ── Status bar ────────────────────────────────────────────────────────────
	var status_row := HBoxContainer.new()
	add_child(status_row)
	_status_bar = Label.new()
	_status_bar.text = "Ready. Create a new graph or open a .vcr file."
	_status_bar.add_theme_font_size_override("font_size", 11)
	_status_bar.modulate = Color(0.75, 0.75, 0.75)
	status_row.add_child(_status_bar)

	# ── Welcome message ───────────────────────────────────────────────────────
	_set_status("Welcome to Visual Coder! Press 'New Node Graph' or 'New Block Script' to start.")

func _add_btn(parent: Control, text: String, cb: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.pressed.connect(cb)
	parent.add_child(b)
	return b

# ── Status helpers ────────────────────────────────────────────────────────────

func _set_status(msg: String) -> void:
	if _status_bar:
		_status_bar.text = msg

func _mark_dirty() -> void:
	_dirty = true
	_update_file_label()

func _mark_clean() -> void:
	_dirty = false
	_update_file_label()

func _update_file_label() -> void:
	if _file_label:
		var base := _current_file_path if _current_file_path != "" else "[unsaved]"
		_file_label.text = base + (" *" if _dirty else "")

# ── Toolbar handlers ──────────────────────────────────────────────────────────

func _on_new_node_graph() -> void:
	_current_resource = VCResource.new_node_graph()
	_current_file_path = ""
	_node_graph_editor._on_clear_pressed()
	_tabs.current_tab = 0
	_mark_clean()
	_set_status("New node graph created.")

func _on_new_block_script() -> void:
	_current_resource = VCResource.new_block_script()
	_current_file_path = ""
	_block_editor._on_clear()
	_tabs.current_tab = 1
	_mark_clean()
	_set_status("New block script created.")

func _on_open() -> void:
	var dialog := FileDialog.new()
	dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	dialog.access = FileDialog.ACCESS_FILESYSTEM
	dialog.filters = PackedStringArray(["*.vcr ; Visual Coder Resource", "*.json ; JSON"])
	add_child(dialog)
	dialog.file_selected.connect(func(path: String):
		_load_file(path)
		dialog.queue_free()
	)
	dialog.canceled.connect(func(): dialog.queue_free())
	dialog.popup_centered(Vector2(800, 600))

func _on_save() -> void:
	if _current_file_path == "":
		_on_save_as()
	else:
		_do_save(_current_file_path)

func _on_save_as() -> void:
	var dialog := FileDialog.new()
	dialog.file_mode = FileDialog.FILE_MODE_SAVE_FILE
	dialog.access = FileDialog.ACCESS_FILESYSTEM
	dialog.filters = PackedStringArray(["*.vcr ; Visual Coder Resource"])
	add_child(dialog)
	dialog.file_selected.connect(func(path: String):
		_do_save(path)
		dialog.queue_free()
	)
	dialog.canceled.connect(func(): dialog.queue_free())
	dialog.popup_centered(Vector2(800, 600))

func _on_generate_code() -> void:
	var code := _generate_current_code()
	_show_code_popup(code)

func _on_apply_to_script() -> void:
	if editor_interface == null:
		_set_status("Error: editor_interface not set.")
		return
	var script := editor_interface.get_script_editor().get_current_script()
	if script == null:
		_set_status("No script open in the editor. Open a GDScript file first.")
		return
	var code := _generate_current_code()
	script.source_code = code
	ResourceSaver.save(script)
	editor_interface.get_script_editor().reload_scripts()
	_set_status("Code applied to '%s'." % script.resource_path)

func _on_addon_manager() -> void:
	_show_addon_manager()

# ── Change callbacks ──────────────────────────────────────────────────────────

func _on_graph_changed() -> void:
	_mark_dirty()

func _on_blocks_changed() -> void:
	_mark_dirty()

# ── File I/O ──────────────────────────────────────────────────────────────────

func _do_save(path: String) -> void:
	var res := VCResource.new()
	if _tabs.current_tab == 0:
		res.set_node_graph_data(_node_graph_editor.get_graph_data())
	else:
		res.set_block_data(_block_editor.get_block_data())

	# Save as JSON file
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		_set_status("Error: could not write to '%s'." % path)
		return
	f.store_string(res.json_data)
	f.close()

	_current_file_path = path
	_current_resource = res
	_mark_clean()
	_set_status("Saved to '%s'." % path)

func _load_file(path: String) -> void:
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		_set_status("Error: could not read '%s'." % path)
		return
	var json_str := f.get_as_text()
	f.close()

	var data = JSON.parse_string(json_str)
	if not data is Dictionary:
		_set_status("Error: invalid file format.")
		return

	var code_type: String = data.get("type", "")
	if code_type == "node_graph":
		_node_graph_editor.load_graph_data(data)
		_tabs.current_tab = 0
	elif code_type == "block_script":
		_block_editor.load_block_data(data)
		_tabs.current_tab = 1
	else:
		_set_status("Error: unknown file type '%s'." % code_type)
		return

	_current_file_path = path
	_mark_clean()
	_set_status("Loaded '%s'." % path)

# ── Code generation ───────────────────────────────────────────────────────────

func _generate_current_code() -> String:
	if _tabs.current_tab == 0:
		var gen := NodeCodeGenerator.new()
		return gen.generate(_node_graph_editor.get_graph_data())
	else:
		var gen := BlockCodeGenerator.new()
		return gen.generate(_block_editor.get_block_data())

# ── Code popup ────────────────────────────────────────────────────────────────

func _show_code_popup(code: String) -> void:
	if _code_popup and is_instance_valid(_code_popup):
		_code_popup.queue_free()

	_code_popup = Window.new()
	_code_popup.title = "Generated GDScript"
	_code_popup.size = Vector2i(700, 500)
	_code_popup.wrap_controls = true
	add_child(_code_popup)

	var vbox := VBoxContainer.new()
	_code_popup.add_child(vbox)

	var toolbar := HBoxContainer.new()
	vbox.add_child(toolbar)

	var copy_btn := Button.new()
	copy_btn.text = "Copy to Clipboard"
	copy_btn.pressed.connect(func(): DisplayServer.clipboard_set(code); _set_status("Code copied to clipboard."))
	toolbar.add_child(copy_btn)

	var close_btn := Button.new()
	close_btn.text = "Close"
	close_btn.pressed.connect(func(): _code_popup.queue_free())
	toolbar.add_child(close_btn)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(scroll)

	var txt := TextEdit.new()
	txt.text = code
	txt.editable = true
	txt.syntax_highlighter = _make_highlighter()
	txt.size_flags_vertical = Control.SIZE_EXPAND_FILL
	txt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	txt.custom_minimum_size = Vector2(680, 440)
	scroll.add_child(txt)

	_code_popup.popup_centered()

func _make_highlighter() -> CodeHighlighter:
	var h := CodeHighlighter.new()
	# GDScript keywords
	var kw_color := Color(0.55, 0.75, 1.0)
	for kw in ["func", "var", "const", "if", "else", "elif", "for", "while",
			"match", "return", "break", "continue", "pass", "and", "or",
			"not", "in", "extends", "class_name", "signal", "enum",
			"true", "false", "null", "self", "super", "new", "await"]:
		h.add_keyword_color(kw, kw_color)
	h.add_color_region('"', '"', Color(0.85, 0.65, 0.45))
	h.add_color_region("'", "'", Color(0.85, 0.65, 0.45))
	h.add_color_region("#", "", Color(0.5, 0.65, 0.5), true)
	return h

# ── Addon Manager ─────────────────────────────────────────────────────────────

func _show_addon_manager() -> void:
	var win := Window.new()
	win.title = "Visual Coder – Addon Manager"
	win.size = Vector2i(500, 420)
	add_child(win)

	var vbox := VBoxContainer.new()
	win.add_child(vbox)

	var title_lbl := Label.new()
	title_lbl.text = "Registered Visual Coder Addons"
	title_lbl.add_theme_font_size_override("font_size", 14)
	vbox.add_child(title_lbl)
	vbox.add_child(HSeparator.new())

	var list := VBoxContainer.new()
	list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(list)

	for addon in AddonRegistry.instance().get_addons():
		var row := HBoxContainer.new()
		list.add_child(row)
		var lbl := Label.new()
		lbl.text = "%s  v%s" % [addon.get_addon_name(), addon.get_addon_version()]
		lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(lbl)
		var desc := Label.new()
		desc.text = addon.get_addon_description()
		desc.add_theme_font_size_override("font_size", 10)
		desc.modulate = Color(0.7, 0.7, 0.7)
		list.add_child(desc)

	if AddonRegistry.instance().get_addons().is_empty():
		var empty_lbl := Label.new()
		empty_lbl.text = "No addons registered.\n\nTo create an addon, extend VCAddonBase and call:\n  AddonRegistry.instance().register(MyAddon.new())\nfrom your plugin's _enter_tree()."
		empty_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		empty_lbl.modulate = Color(0.7, 0.7, 0.7)
		list.add_child(empty_lbl)

	var sep_lbl := Label.new()
	sep_lbl.text = "\nAddon API Guide"
	sep_lbl.add_theme_font_size_override("font_size", 13)
	vbox.add_child(sep_lbl)
	vbox.add_child(HSeparator.new())

	var api_lbl := Label.new()
	api_lbl.text = (
		"1. Create a new Godot plugin\n"
		+ "2. In your plugin.gd _enter_tree():\n"
		+ "     var my_addon = MyVCAddon.new()\n"
		+ "     AddonRegistry.instance().register(my_addon)\n"
		+ "3. In _exit_tree():\n"
		+ "     AddonRegistry.instance().unregister(my_addon)\n\n"
		+ "See addon_api/vc_addon_base.gd for full API docs."
	)
	api_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	api_lbl.add_theme_font_size_override("font_size", 11)
	vbox.add_child(api_lbl)

	var close := Button.new()
	close.text = "Close"
	close.pressed.connect(func(): win.queue_free())
	vbox.add_child(close)

	win.close_requested.connect(func(): win.queue_free())
	win.popup_centered()
