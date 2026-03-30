@tool
## NodeCodeGenerator – converts a node-graph data dictionary into GDScript source.
##
## Usage:
##   var gen := NodeCodeGenerator.new()
##   var code := gen.generate(graph_data)  # returns a GDScript string
class_name NodeCodeGenerator
extends RefCounted

# ── Public entry point ────────────────────────────────────────────────────────

## Generate a full GDScript from graph_data (as returned by VCResource).
func generate(graph_data: Dictionary) -> String:
	if graph_data.is_empty():
		return "# Empty graph\nextends Node\n"

	var nodes: Array = graph_data.get("nodes", [])
	var connections: Array = graph_data.get("connections", [])
	var variables: Array = graph_data.get("variables", [])

	# Index nodes by id
	var node_map: Dictionary = {}
	for n in nodes:
		node_map[n["id"]] = n

	# Build adjacency: for each target node/port, what is the source node/port?
	# data_inputs[to_node_id][to_port] = {from_node, from_port}
	var data_inputs: Dictionary = {}
	# exec_outputs[from_node_id][from_port] = to_node_id
	var exec_outputs: Dictionary = {}

	for c in connections:
		var fn: int = c["from_node"]
		var fp: int = c["from_port"]
		var tn: int = c["to_node"]
		var tp: int = c["to_port"]
		var fdef: Dictionary = _get_def(node_map.get(fn, {}))
		var fout: Array = fdef.get("outputs", [])
		if fp < fout.size() and fout[fp].get("type", -1) == NodeDefinitions.T_EXEC:
			# execution connection
			if not fn in exec_outputs:
				exec_outputs[fn] = {}
			exec_outputs[fn][fp] = tn
		else:
			# data connection
			if not tn in data_inputs:
				data_inputs[tn] = {}
			data_inputs[tn][tp] = {"from_node": fn, "from_port": fp}

	var builder := _CodeBuilder.new()

	# Gather class-level variables declared
	if variables.size() > 0:
		builder.add("extends Node")
		builder.add("")
		for v in variables:
			var vname: String = v.get("name", "var_" + str(v.get("id", 0)))
			var vtype: String = v.get("type", "")
			var vdefault = v.get("default", null)
			if vtype != "" and vdefault != null:
				builder.add("var %s: %s = %s" % [vname, vtype, _val(vdefault)])
			elif vtype != "":
				builder.add("var %s: %s" % [vname, vtype])
			elif vdefault != null:
				builder.add("var %s = %s" % [vname, _val(vdefault)])
			else:
				builder.add("var %s" % vname)
		builder.add("")
	else:
		builder.add("extends Node")
		builder.add("")

	# Find all entry nodes (nodes whose type starts with "events/")
	var entry_nodes: Array = []
	for n in nodes:
		if n.get("type", "").begins_with("events/"):
			entry_nodes.append(n)

	for entry in entry_nodes:
		_gen_function(entry, node_map, data_inputs, exec_outputs, builder)
		builder.add("")

	return builder.build()

# ── Function generation ───────────────────────────────────────────────────────

func _gen_function(entry_node: Dictionary, node_map: Dictionary,
		data_inputs: Dictionary, exec_outputs: Dictionary,
		builder: _CodeBuilder) -> void:
	var t: String = entry_node.get("type", "")
	var props: Dictionary = entry_node.get("properties", {})
	var nid: int = entry_node.get("id", -1)

	match t:
		"events/on_ready":
			builder.add("func _ready() -> void:")
		"events/on_process":
			builder.add("func _process(delta: float) -> void:")
		"events/on_physics_process":
			builder.add("func _physics_process(delta: float) -> void:")
		"events/on_input":
			builder.add("func _input(event: InputEvent) -> void:")
		"events/on_enter_tree":
			builder.add("func _enter_tree() -> void:")
		"events/on_exit_tree":
			builder.add("func _exit_tree() -> void:")
		"events/on_signal":
			var sname: String = props.get("signal_name", "my_signal")
			builder.add("func _on_%s() -> void:" % sname)
		"events/custom_function":
			var fname: String = props.get("func_name", "my_function")
			builder.add("func %s() -> void:" % fname)
		_:
			builder.add("func _unknown_entry() -> void:")

	builder.indent()
	# Find next exec node (port 0 of entry node)
	var first_exec := _get_exec_out(nid, 0, exec_outputs)
	if first_exec == -1:
		builder.add("pass")
	else:
		_gen_chain(first_exec, node_map, data_inputs, exec_outputs, builder)
	builder.dedent()

# ── Chain generation (follow exec ports) ─────────────────────────────────────

func _gen_chain(node_id: int, node_map: Dictionary, data_inputs: Dictionary,
		exec_outputs: Dictionary, builder: _CodeBuilder) -> void:
	if node_id == -1 or not node_id in node_map:
		return
	var node: Dictionary = node_map[node_id]
	var t: String = node.get("type", "")
	var props: Dictionary = node.get("properties", {})

	# Create closures (Callables) for the code gen helpers
	var get_input := func(port: int) -> String:
		return _resolve_data(node_id, port, node_map, data_inputs)
	var get_chain := func(port: int) -> String:
		var next := _get_exec_out(node_id, port, exec_outputs)
		var sub := _CodeBuilder.new()
		sub._indent = builder._indent
		_gen_chain(next, node_map, data_inputs, exec_outputs, sub)
		return sub.build()

	# Try addon generators first
	var addon_code := AddonRegistry.instance().generate_node_code(
		node, get_input, get_chain, builder._indent)
	if addon_code != "":
		builder.raw(addon_code)
		return

	# Built-in code generation
	match t:
		# ── Flow control ──────────────────────────────────────────────────────
		"flow/if", "flow/branch":
			var cond := get_input.call(1)
			builder.add("if %s:" % cond)
			builder.indent()
			var true_next := _get_exec_out(node_id, 0, exec_outputs)
			if true_next == -1:
				builder.add("pass")
			else:
				_gen_chain(true_next, node_map, data_inputs, exec_outputs, builder)
			builder.dedent()
			var false_next := _get_exec_out(node_id, 1, exec_outputs)
			if false_next != -1:
				builder.add("else:")
				builder.indent()
				_gen_chain(false_next, node_map, data_inputs, exec_outputs, builder)
				builder.dedent()
			return

		"flow/for_range":
			var from_v := get_input.call(1)
			var to_v := get_input.call(2)
			var step_v := get_input.call(3)
			builder.add("for _i in range(%s, %s, %s):" % [from_v, to_v, step_v])
			builder.indent()
			var loop_next := _get_exec_out(node_id, 0, exec_outputs)
			if loop_next == -1:
				builder.add("pass")
			else:
				_gen_chain(loop_next, node_map, data_inputs, exec_outputs, builder)
			builder.dedent()
			var done_next := _get_exec_out(node_id, 2, exec_outputs)
			_gen_chain(done_next, node_map, data_inputs, exec_outputs, builder)
			return

		"flow/for_array":
			var arr := get_input.call(1)
			var vname: String = props.get("var_name", "item")
			builder.add("for %s in %s:" % [vname, arr])
			builder.indent()
			var loop_next := _get_exec_out(node_id, 0, exec_outputs)
			if loop_next == -1:
				builder.add("pass")
			else:
				_gen_chain(loop_next, node_map, data_inputs, exec_outputs, builder)
			builder.dedent()
			var done_next := _get_exec_out(node_id, 2, exec_outputs)
			_gen_chain(done_next, node_map, data_inputs, exec_outputs, builder)
			return

		"flow/while":
			var cond := get_input.call(1)
			builder.add("while %s:" % cond)
			builder.indent()
			var loop_next := _get_exec_out(node_id, 0, exec_outputs)
			if loop_next == -1:
				builder.add("pass")
			else:
				_gen_chain(loop_next, node_map, data_inputs, exec_outputs, builder)
			builder.dedent()
			var done_next := _get_exec_out(node_id, 1, exec_outputs)
			_gen_chain(done_next, node_map, data_inputs, exec_outputs, builder)
			return

		"flow/match":
			var val := get_input.call(1)
			var b0: String = props.get("branch_0", "0")
			var b1: String = props.get("branch_1", "1")
			var b2: String = props.get("branch_2", "2")
			builder.add("match %s:" % val)
			builder.indent()
			for bi in [[b0, 0], [b1, 1], [b2, 2]]:
				builder.add("%s:" % bi[0])
				builder.indent()
				var bn := _get_exec_out(node_id, bi[1], exec_outputs)
				if bn == -1:
					builder.add("pass")
				else:
					_gen_chain(bn, node_map, data_inputs, exec_outputs, builder)
				builder.dedent()
			builder.add("_:")
			builder.indent()
			var def_next := _get_exec_out(node_id, 3, exec_outputs)
			if def_next == -1:
				builder.add("pass")
			else:
				_gen_chain(def_next, node_map, data_inputs, exec_outputs, builder)
			builder.dedent()
			builder.dedent()
			return

		"flow/return":
			builder.add("return %s" % get_input.call(1))
			return

		"flow/return_void":
			builder.add("return")
			return

		"flow/break":
			builder.add("break")
			return

		"flow/continue":
			builder.add("continue")
			return

		"flow/pass":
			builder.add("pass")

		# ── Variables ─────────────────────────────────────────────────────────
		"variables/set_var":
			var vname: String = props.get("var_name", "my_var")
			builder.add("%s = %s" % [vname, get_input.call(1)])

		"variables/declare_var":
			var vname: String = props.get("var_name", "my_var")
			var vtype: String = props.get("var_type", "var")
			if vtype == "var":
				builder.add("var %s = %s" % [vname, get_input.call(1)])
			else:
				builder.add("var %s: %s = %s" % [vname, vtype, get_input.call(1)])

		"variables/set_property":
			var obj := get_input.call(1)
			var pname: String = props.get("property_name", "position")
			builder.add("%s.%s = %s" % [obj, pname, get_input.call(2)])

		# ── Functions ─────────────────────────────────────────────────────────
		"functions/print_node":
			builder.add("print(%s)" % get_input.call(1))

		"functions/printerr_node":
			builder.add("printerr(%s)" % get_input.call(1))

		"functions/call_method":
			var obj := get_input.call(1)
			var mname: String = props.get("method_name", "method")
			var a0 := get_input.call(2)
			var a1 := get_input.call(3)
			var args := _build_args([a0, a1])
			builder.add("%s.%s(%s)" % [obj, mname, args])

		"functions/call_self":
			var mname: String = props.get("method_name", "method")
			var a0 := get_input.call(1)
			var a1 := get_input.call(2)
			var args := _build_args([a0, a1])
			builder.add("%s(%s)" % [mname, args])

		"functions/instantiate":
			var scene := get_input.call(1)
			builder.add("var _inst = %s.instantiate()" % scene)

		"functions/add_child":
			var parent := get_input.call(1)
			var child := get_input.call(2)
			builder.add("%s.add_child(%s)" % [parent, child])

		"functions/queue_free":
			builder.add("%s.queue_free()" % get_input.call(1))

		# ── Arrays ────────────────────────────────────────────────────────────
		"arrays/array_set":
			var arr := get_input.call(1)
			var idx := get_input.call(2)
			var val := get_input.call(3)
			builder.add("%s[%s] = %s" % [arr, idx, val])

		"arrays/array_append":
			builder.add("%s.append(%s)" % [get_input.call(1), get_input.call(2)])

		"arrays/array_remove":
			builder.add("%s.remove_at(%s)" % [get_input.call(1), get_input.call(2)])

		# ── Dictionaries ──────────────────────────────────────────────────────
		"dicts/dict_set":
			var d := get_input.call(1)
			var k := get_input.call(2)
			var v := get_input.call(3)
			builder.add("%s[%s] = %s" % [d, k, v])

		# ── Signals ───────────────────────────────────────────────────────────
		"signals/emit":
			var sname: String = props.get("signal_name", "my_signal")
			var arg := get_input.call(1)
			if arg != "null":
				builder.add("%s.emit(%s)" % [sname, arg])
			else:
				builder.add("%s.emit()" % sname)

		"signals/connect_signal":
			var src := get_input.call(1)
			var sname: String = props.get("signal_name", "my_signal")
			var target: String = props.get("target_method", "on_signal")
			builder.add("%s.%s.connect(%s)" % [src, sname, target])

		"signals/disconnect_signal":
			var src := get_input.call(1)
			var sname: String = props.get("signal_name", "my_signal")
			var target: String = props.get("target_method", "on_signal")
			builder.add("%s.%s.disconnect(%s)" % [src, sname, target])

		# ── Utilities ─────────────────────────────────────────────────────────
		"utils/assert_node":
			var msg: String = props.get("message", "Assertion failed")
			builder.add('assert(%s, "%s")' % [get_input.call(1), msg])

		"utils/comment":
			var txt: String = props.get("text", "")
			for line in txt.split("\n"):
				builder.add("# %s" % line)
			# comments have no exec out → return immediately
			return

		"utils/raw_code":
			var code_str: String = props.get("code", "pass")
			for line in code_str.split("\n"):
				builder.add(line)

		_:
			builder.add("# TODO: unimplemented node type: %s" % t)

	# Continue to next exec node (port 0 by default for most statement nodes)
	var next_id := _get_exec_out(node_id, 0, exec_outputs)
	_gen_chain(next_id, node_map, data_inputs, exec_outputs, builder)

# ── Data expression generation (returns an expression string) ─────────────────

func _resolve_data(node_id: int, port: int, node_map: Dictionary,
		data_inputs: Dictionary) -> String:
	if node_id in data_inputs and port in data_inputs[node_id]:
		var src := data_inputs[node_id][port]
		return _eval_output(src["from_node"], src["from_port"], node_map, data_inputs)
	# Return default from definition
	var node: Dictionary = node_map.get(node_id, {})
	var def: Dictionary = _get_def(node)
	var inputs: Array = def.get("inputs", [])
	if port < inputs.size():
		var default_val = inputs[port].get("default", null)
		if default_val != null:
			return _val(default_val)
	return "null"

func _eval_output(node_id: int, port: int, node_map: Dictionary,
		data_inputs: Dictionary) -> String:
	var node: Dictionary = node_map.get(node_id, {})
	var t: String = node.get("type", "")
	var props: Dictionary = node.get("properties", {})

	var get_in := func(p: int) -> String:
		return _resolve_data(node_id, p, node_map, data_inputs)

	match t:
		# Literals
		"literals/bool_literal": return str(props.get("value", false)).to_lower()
		"literals/int_literal":  return str(int(props.get("value", 0)))
		"literals/float_literal":
			var fv: float = props.get("value", 0.0)
			return "%s" % fv
		"literals/string_literal":
			return '"%s"' % str(props.get("value", "")).replace('"', '\\"')
		"literals/vector2_literal":
			return "Vector2(%s, %s)" % [props.get("x", 0.0), props.get("y", 0.0)]
		"literals/vector3_literal":
			return "Vector3(%s, %s, %s)" % [props.get("x", 0.0), props.get("y", 0.0), props.get("z", 0.0)]
		"literals/color_literal":
			return "Color(%s, %s, %s, %s)" % [props.get("r", 1.0), props.get("g", 1.0), props.get("b", 1.0), props.get("a", 1.0)]
		"literals/null_literal": return "null"
		"literals/self_ref": return "self"

		# Variables
		"variables/get_var":
			return str(props.get("var_name", "my_var"))
		"variables/get_property":
			return "%s.%s" % [get_in.call(0), props.get("property_name", "position")]

		# Math
		"math/add":      return "(%s + %s)" % [get_in.call(0), get_in.call(1)]
		"math/subtract": return "(%s - %s)" % [get_in.call(0), get_in.call(1)]
		"math/multiply": return "(%s * %s)" % [get_in.call(0), get_in.call(1)]
		"math/divide":   return "(%s / %s)" % [get_in.call(0), get_in.call(1)]
		"math/modulo":   return "(%s %% %s)" % [get_in.call(0), get_in.call(1)]
		"math/power":    return "pow(%s, %s)" % [get_in.call(0), get_in.call(1)]
		"math/negate":   return "(-%s)" % get_in.call(0)
		"math/abs_val":  return "abs(%s)" % get_in.call(0)
		"math/sqrt":     return "sqrt(%s)" % get_in.call(0)
		"math/clamp":    return "clamp(%s, %s, %s)" % [get_in.call(0), get_in.call(1), get_in.call(2)]
		"math/lerp":     return "lerp(%s, %s, %s)" % [get_in.call(0), get_in.call(1), get_in.call(2)]
		"math/round":    return "round(%s)" % get_in.call(0)
		"math/floor_fn": return "floor(%s)" % get_in.call(0)
		"math/ceil_fn":  return "ceil(%s)" % get_in.call(0)
		"math/sin_fn":   return "sin(%s)" % get_in.call(0)
		"math/cos_fn":   return "cos(%s)" % get_in.call(0)
		"math/random":   return "randf()"
		"math/randi_range": return "randi_range(%s, %s)" % [get_in.call(0), get_in.call(1)]

		# Logic
		"logic/and":           return "(%s and %s)" % [get_in.call(0), get_in.call(1)]
		"logic/or":            return "(%s or %s)" % [get_in.call(0), get_in.call(1)]
		"logic/not":           return "(not %s)" % get_in.call(0)
		"logic/equal":         return "(%s == %s)" % [get_in.call(0), get_in.call(1)]
		"logic/not_equal":     return "(%s != %s)" % [get_in.call(0), get_in.call(1)]
		"logic/greater":       return "(%s > %s)" % [get_in.call(0), get_in.call(1)]
		"logic/greater_equal": return "(%s >= %s)" % [get_in.call(0), get_in.call(1)]
		"logic/less":          return "(%s < %s)" % [get_in.call(0), get_in.call(1)]
		"logic/less_equal":    return "(%s <= %s)" % [get_in.call(0), get_in.call(1)]
		"logic/ternary":       return "(%s if %s else %s)" % [get_in.call(1), get_in.call(0), get_in.call(2)]

		# Strings
		"strings/concat":    return "(%s + %s)" % [get_in.call(0), get_in.call(1)]
		"strings/format":    return '(%s %% %s)' % [get_in.call(0), get_in.call(1)]
		"strings/to_int":    return "int(%s)" % get_in.call(0)
		"strings/to_float":  return "float(%s)" % get_in.call(0)
		"strings/str_convert": return "str(%s)" % get_in.call(0)
		"strings/length":    return "len(%s)" % get_in.call(0)
		"strings/substr":    return "%s.substr(%s, %s)" % [get_in.call(0), get_in.call(1), get_in.call(2)]
		"strings/split":     return "%s.split(%s)" % [get_in.call(0), get_in.call(1)]

		# Arrays
		"arrays/make_array":  return "[%s, %s, %s]" % [get_in.call(0), get_in.call(1), get_in.call(2)]
		"arrays/array_size":  return "len(%s)" % get_in.call(0)
		"arrays/array_get":   return "%s[%s]" % [get_in.call(0), get_in.call(1)]
		"arrays/array_has":   return "%s.has(%s)" % [get_in.call(0), get_in.call(1)]

		# Dictionaries
		"dicts/make_dict":    return "{%s: %s}" % [get_in.call(0), get_in.call(1)]
		"dicts/dict_get":     return "%s[%s]" % [get_in.call(0), get_in.call(1)]
		"dicts/dict_has":     return "%s.has(%s)" % [get_in.call(0), get_in.call(1)]
		"dicts/dict_keys":    return "%s.keys()" % get_in.call(0)
		"dicts/dict_values":  return "%s.values()" % get_in.call(0)

		# Functions returning value
		"functions/call_method":
			var obj := get_in.call(1)
			var mname: String = props.get("method_name", "method")
			var a0 := get_in.call(2)
			var a1 := get_in.call(3)
			return "%s.%s(%s)" % [obj, mname, _build_args([a0, a1])]
		"functions/call_self":
			var mname: String = props.get("method_name", "method")
			var a0 := get_in.call(1)
			var a1 := get_in.call(2)
			return "%s(%s)" % [mname, _build_args([a0, a1])]
		"functions/get_node":
			return 'get_node("%s")' % props.get("path", "")
		"functions/instantiate":
			return "%s.instantiate()" % get_in.call(1)

		# Signals
		"signals/is_connected":
			var src := get_in.call(0)
			var sname: String = props.get("signal_name", "my_signal")
			var target: String = props.get("target_method", "on_signal")
			return "%s.%s.is_connected(%s)" % [src, sname, target]

		# Utilities
		"utils/type_cast":
			return "(%s as %s)" % [get_in.call(0), props.get("type_name", "Node")]
		"utils/typeof_node":
			return "typeof(%s)" % get_in.call(0)
		"utils/is_instance":
			return "(%s is %s)" % [get_in.call(0), props.get("class_name_str", "Node")]

		# for_range gives index on output port 1
		"flow/for_range": return "_i"
		# for_array gives item on output port 1
		"flow/for_array":
			return props.get("var_name", "item")

		_:
			# Try addons
			var addon_expr := AddonRegistry.instance().generate_node_code(
				node, get_in, func(_p): return "", 0)
			if addon_expr != "":
				return addon_expr
			return "null"

# ── Helpers ───────────────────────────────────────────────────────────────────

func _get_exec_out(node_id: int, port: int, exec_outputs: Dictionary) -> int:
	if node_id in exec_outputs and port in exec_outputs[node_id]:
		return exec_outputs[node_id][port]
	return -1

func _get_def(node: Dictionary) -> Dictionary:
	return NodeDefinitions.get_by_type(node.get("type", ""))

func _val(v) -> String:
	if v is bool:
		return "true" if v else "false"
	if v is int:
		return str(v)
	if v is float:
		return str(v)
	if v is String:
		return '"%s"' % str(v).replace('"', '\\"')
	return str(v)

func _build_args(args: Array) -> String:
	var filtered: Array[String] = []
	for a in args:
		var s := str(a)
		if s != "null" and s != "":
			filtered.append(s)
	return ", ".join(filtered)

# ── Inner class: code builder with indentation ────────────────────────────────

class _CodeBuilder:
	var _lines: PackedStringArray = []
	var _indent: int = 0

	func add(line: String) -> void:
		_lines.append("\t".repeat(_indent) + line)

	func raw(text: String) -> void:
		for line in text.split("\n"):
			if line != "":
				_lines.append(line)

	func indent() -> void:
		_indent += 1

	func dedent() -> void:
		_indent = max(0, _indent - 1)

	func build() -> String:
		return "\n".join(_lines)
