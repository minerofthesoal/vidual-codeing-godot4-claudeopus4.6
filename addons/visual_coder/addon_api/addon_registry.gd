@tool
## AddonRegistry – singleton-style registry for Visual Coder addons.
##
## Accessed via:
##   AddonRegistry.instance()   (returns the singleton created by plugin.gd)
##   or through the EditorPlugin reference stored in plugin.gd.
class_name AddonRegistry
extends RefCounted

signal addon_registered(addon: VCAddonBase)
signal addon_unregistered(addon: VCAddonBase)
signal types_changed

# ── Singleton ────────────────────────────────────────────────────────────────

static var _instance: AddonRegistry

static func instance() -> AddonRegistry:
	if _instance == null:
		_instance = AddonRegistry.new()
	return _instance

# ── Storage ──────────────────────────────────────────────────────────────────

var _addons: Array[VCAddonBase] = []

# ── Public API ────────────────────────────────────────────────────────────────

## Register an addon. Duplicate registrations are silently ignored.
func register(addon: VCAddonBase) -> void:
	if addon in _addons:
		return
	_addons.append(addon)
	addon.on_registered()
	addon_registered.emit(addon)
	types_changed.emit()

## Unregister an addon.
func unregister(addon: VCAddonBase) -> void:
	if not addon in _addons:
		return
	_addons.erase(addon)
	addon.on_unregistered()
	addon_unregistered.emit(addon)
	types_changed.emit()

func get_addons() -> Array[VCAddonBase]:
	return _addons.duplicate()

## Collect all extra node-type definitions from all registered addons.
func get_extra_node_types() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for addon in _addons:
		result.append_array(addon.get_node_types())
	return result

## Collect all extra block-type definitions from all registered addons.
func get_extra_block_types() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for addon in _addons:
		result.append_array(addon.get_block_types())
	return result

## Try addon code generators for a node type. Returns "" if no addon handles it.
func generate_node_code(node_data: Dictionary, get_input: Callable,
		get_chain: Callable, depth: int) -> String:
	for addon in _addons:
		var code := addon.generate_node_code(node_data, get_input, get_chain, depth)
		if code != "":
			return code
	return ""

## Try addon code generators for a block type. Returns "" if no addon handles it.
func generate_block_code(block_data: Dictionary, get_inner: Callable,
		get_next: Callable, depth: int) -> String:
	for addon in _addons:
		var code := addon.generate_block_code(block_data, get_inner, get_next, depth)
		if code != "":
			return code
	return ""
