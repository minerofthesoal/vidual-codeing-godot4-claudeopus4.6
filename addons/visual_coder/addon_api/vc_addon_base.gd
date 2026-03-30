@tool
## VCAddonBase - Base class for all Visual Coder addons.
##
## Extend this class and place the script in a Godot addon. Then register it
## with AddonRegistry via plugin.gd or your own autoload.
##
## Example usage:
##   class_name MyVCAddon
##   extends VCAddonBase
##
##   func get_addon_name() -> String:
##       return "My Addon"
##
##   func get_node_types() -> Array[Dictionary]:
##       return [
##           NodeDefinitions.make_def(
##               "my_addon/custom_node",   # unique type id
##               "Custom Node",            # display name
##               "My Addon",               # category
##               Color(0.4, 0.2, 0.9),     # header color
##               [],                        # inputs
##               [{"name":"out","type":5,"color":Color(0.7,0.7,0.7)}], # outputs
##               {"value": ""},             # default properties
##               "# custom node\n"          # code template (optional)
##           )
##       ]
class_name VCAddonBase
extends RefCounted

# ── Identity ────────────────────────────────────────────────────────────────

## Return a unique, human-readable name for this addon.
func get_addon_name() -> String:
	return "Unnamed Addon"

## Return a short description shown in the addon list.
func get_addon_description() -> String:
	return ""

## Return a version string.
func get_addon_version() -> String:
	return "1.0.0"

# ── Node Graph extension ─────────────────────────────────────────────────────

## Return an array of node-type definition dictionaries.
## Use NodeDefinitions.make_def() to build each entry.
func get_node_types() -> Array[Dictionary]:
	return []

# ── Block editor extension ───────────────────────────────────────────────────

## Return an array of block-type definition dictionaries.
## Use BlockDefinitions.make_def() to build each entry.
func get_block_types() -> Array[Dictionary]:
	return []

# ── Code generation extension ────────────────────────────────────────────────

## Called by NodeCodeGenerator when it encounters one of the node types
## registered by this addon. Return the GDScript code string, or "" to fall
## back to the default template mechanism.
## @param node_data  The full node dictionary from the graph.
## @param get_input  Callable(port_index) -> String  – resolves a data input.
## @param get_chain  Callable(port_index) -> String  – resolves an exec chain.
## @param depth      Current indentation depth.
func generate_node_code(node_data: Dictionary, get_input: Callable,
		get_chain: Callable, depth: int) -> String:
	return ""

## Same as generate_node_code but for block types.
func generate_block_code(block_data: Dictionary, get_inner: Callable,
		get_next: Callable, depth: int) -> String:
	return ""

# ── Lifecycle ────────────────────────────────────────────────────────────────

## Called when the addon is registered with AddonRegistry.
func on_registered() -> void:
	pass

## Called when the addon is unregistered.
func on_unregistered() -> void:
	pass
