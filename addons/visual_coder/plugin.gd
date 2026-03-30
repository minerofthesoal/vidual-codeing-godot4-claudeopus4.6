@tool
## Visual Coder Plugin – main entry point.
##
## Registers the Visual Coder as a new main screen tab in the Godot editor.
## Also initializes the AddonRegistry singleton.
extends EditorPlugin

const MainEditor = preload("res://addons/visual_coder/editor/main_editor.gd")

var _main_editor: VCMainEditor

func _enter_tree() -> void:
	# Ensure the addon registry singleton exists
	AddonRegistry.instance()

	# Create and register the main screen
	_main_editor = MainEditor.new()
	_main_editor.editor_interface = get_editor_interface()
	get_editor_interface().get_editor_main_screen().add_child(_main_editor)
	_make_visible(false)

	print("[Visual Coder] Plugin loaded. Version 1.0.0")

func _exit_tree() -> void:
	if _main_editor:
		_main_editor.queue_free()
		_main_editor = null

# ── EditorPlugin overrides ────────────────────────────────────────────────────

func _has_main_screen() -> bool:
	return true

func _make_visible(visible: bool) -> void:
	if _main_editor:
		_main_editor.visible = visible

func _get_plugin_name() -> String:
	return "VisualCoder"

func _get_plugin_icon() -> Texture2D:
	# Use a built-in editor icon as fallback; replace with a custom icon if desired
	var base := get_editor_interface().get_base_control()
	if base.has_theme_icon("VisualScript", "EditorIcons"):
		return base.get_theme_icon("VisualScript", "EditorIcons")
	if base.has_theme_icon("Script", "EditorIcons"):
		return base.get_theme_icon("Script", "EditorIcons")
	return base.get_theme_icon("Node", "EditorIcons")
