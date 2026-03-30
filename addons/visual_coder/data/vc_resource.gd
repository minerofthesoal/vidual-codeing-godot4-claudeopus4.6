@tool
## VCResource - Stores and serializes visual code (node graph or block script).
class_name VCResource
extends Resource

const VERSION := "1.0.0"

## "node_graph" or "block_script"
@export var code_type: String = "node_graph"
## Serialized JSON string of the visual code
@export var json_data: String = ""

# ──────────────────────────────────────────────
# NODE GRAPH helpers
# ──────────────────────────────────────────────

static func new_node_graph() -> VCResource:
	var r := VCResource.new()
	r.code_type = "node_graph"
	r.json_data = JSON.stringify({
		"version": VERSION,
		"type": "node_graph",
		"nodes": [],
		"connections": [],
		"variables": []
	}, "\t")
	return r

func get_node_graph_data() -> Dictionary:
	if code_type != "node_graph":
		return {}
	var result = JSON.parse_string(json_data)
	if result is Dictionary:
		return result
	return {}

func set_node_graph_data(data: Dictionary) -> void:
	code_type = "node_graph"
	json_data = JSON.stringify(data, "\t")

# ──────────────────────────────────────────────
# BLOCK SCRIPT helpers
# ──────────────────────────────────────────────

static func new_block_script() -> VCResource:
	var r := VCResource.new()
	r.code_type = "block_script"
	r.json_data = JSON.stringify({
		"version": VERSION,
		"type": "block_script",
		"stacks": [],
		"variables": []
	}, "\t")
	return r

func get_block_data() -> Dictionary:
	if code_type != "block_script":
		return {}
	var result = JSON.parse_string(json_data)
	if result is Dictionary:
		return result
	return {}

func set_block_data(data: Dictionary) -> void:
	code_type = "block_script"
	json_data = JSON.stringify(data, "\t")
