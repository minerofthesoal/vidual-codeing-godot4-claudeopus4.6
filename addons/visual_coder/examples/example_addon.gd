@tool
## ExampleAddon – demonstrates how to extend Visual Coder with custom nodes and blocks.
##
## To use this addon, call from your plugin.gd:
##   AddonRegistry.instance().register(ExampleAddon.new())
##
## See VCAddonBase for the full extension API.
class_name ExampleAddon
extends VCAddonBase

func get_addon_name() -> String:
	return "Example Addon"

func get_addon_description() -> String:
	return "Demonstrates the Visual Coder addon API with custom node and block types."

func get_addon_version() -> String:
	return "1.0.0"

# ── Custom node types ─────────────────────────────────────────────────────────

func get_node_types() -> Array[Dictionary]:
	return [
		# A simple "Hello World" node that prints a greeting
		NodeDefinitions.make_def(
			"example/hello_world",         # unique type id
			"Hello World",                  # display name
			"Example Addon",                # category (shown in palette)
			Color(0.3, 0.6, 0.9),           # header color
			# inputs: exec in
			[{"name": "▶", "type": NodeDefinitions.T_EXEC, "color": Color.WHITE}],
			# outputs: exec out
			[{"name": "▶", "type": NodeDefinitions.T_EXEC, "color": Color.WHITE}],
			# editable properties
			{"greeting": "Hello, World!"},
			# code function name (handled in generate_node_code below)
			"example_hello_world"
		),
		# A node that computes the distance between two Vector2s
		NodeDefinitions.make_def(
			"example/distance_2d",
			"Distance 2D",
			"Example Addon",
			Color(0.3, 0.6, 0.9),
			[
				{"name": "from", "type": NodeDefinitions.T_VECTOR2, "color": NodeDefinitions.port_color(NodeDefinitions.T_VECTOR2)},
				{"name": "to",   "type": NodeDefinitions.T_VECTOR2, "color": NodeDefinitions.port_color(NodeDefinitions.T_VECTOR2)}
			],
			[
				{"name": "distance", "type": NodeDefinitions.T_FLOAT, "color": NodeDefinitions.port_color(NodeDefinitions.T_FLOAT)}
			],
			{},
			"example_distance_2d"
		)
	]

# ── Custom block types ────────────────────────────────────────────────────────

func get_block_types() -> Array[Dictionary]:
	return [
		BlockDefinitions.make_def(
			"example/hello_world_block",   # unique type id
			"Say Hello",                    # display label
			"Example Addon",                # category
			Color(0.3, 0.6, 0.9),           # color
			"statement",                    # shape
			[BlockDefinitions._f("greeting", "string", "Hello, World!")]
		)
	]

# ── Code generation for custom nodes ─────────────────────────────────────────

func generate_node_code(node_data: Dictionary, get_input: Callable,
		_get_chain: Callable, _depth: int) -> String:
	match node_data.get("type", ""):
		"example/hello_world":
			var greeting: String = node_data.get("properties", {}).get("greeting", "Hello, World!")
			return 'print("%s")\n' % greeting.replace('"', '\\"')
		"example/distance_2d":
			# This is a data node (no exec) – not called from generate_node_code
			return ""
	return ""

# ── Code generation for custom blocks ────────────────────────────────────────

func generate_block_code(block_data: Dictionary, _get_inner: Callable,
		_get_next: Callable, _depth: int) -> String:
	match block_data.get("type", ""):
		"example/hello_world_block":
			var greeting: String = block_data.get("properties", {}).get("greeting", "Hello, World!")
			return 'print("%s")\n' % greeting.replace('"', '\\"')
	return ""
