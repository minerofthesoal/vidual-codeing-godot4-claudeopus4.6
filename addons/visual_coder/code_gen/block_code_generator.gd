@tool
## BlockCodeGenerator – converts block-script data into GDScript source.
##
## Usage:
##   var gen := BlockCodeGenerator.new()
##   var code := gen.generate(block_data)
class_name BlockCodeGenerator
extends RefCounted

func generate(block_data: Dictionary) -> String:
	if block_data.is_empty():
		return "# Empty block script\nextends Node\n"

	var stacks: Array = block_data.get("stacks", [])
	var variables: Array = block_data.get("variables", [])

	var builder := _CodeBuilder.new()
	builder.add("extends Node")
	builder.add("")

	# Class-level variable declarations
	for v in variables:
		var vname: String = v.get("name", "my_var")
		var vtype: String = v.get("type", "")
		var vdefault = v.get("default", null)
		if vtype != "" and vdefault != null:
			builder.add("var %s: %s = %s" % [vname, vtype, _val(vdefault)])
		elif vdefault != null:
			builder.add("var %s = %s" % [vname, _val(vdefault)])
		else:
			builder.add("var %s" % vname)
	if variables.size() > 0:
		builder.add("")

	for stack in stacks:
		var blocks: Array = stack.get("blocks", [])
		if blocks.is_empty():
			continue
		_gen_stack(blocks, builder)
		builder.add("")

	return builder.build()

# ── Stack / chain generation ──────────────────────────────────────────────────

func _gen_stack(blocks: Array, builder: _CodeBuilder, depth: int = 0) -> void:
	if blocks.is_empty():
		return
	var first: Dictionary = blocks[0]
	var t: String = first.get("type", "")

	if t.begins_with("events/"):
		_gen_event_header(first, builder)
		builder.indent()
		_gen_block_list(blocks.slice(1), builder)
		builder.dedent()
	else:
		_gen_block_list(blocks, builder)

func _gen_event_header(block: Dictionary, builder: _CodeBuilder) -> void:
	var t: String = block.get("type", "")
	var props: Dictionary = block.get("properties", {})
	match t:
		"events/on_ready":           builder.add("func _ready() -> void:")
		"events/on_process":         builder.add("func _process(delta: float) -> void:")
		"events/on_physics_process": builder.add("func _physics_process(delta: float) -> void:")
		"events/on_input":           builder.add("func _input(event: InputEvent) -> void:")
		"events/on_enter_tree":      builder.add("func _enter_tree() -> void:")
		"events/on_exit_tree":       builder.add("func _exit_tree() -> void:")
		"events/on_signal":
			builder.add("func _on_%s() -> void:" % props.get("signal_name", "my_signal"))
		"events/custom_function":
			builder.add("func %s() -> void:" % props.get("func_name", "my_function"))
		_:
			builder.add("func _unknown() -> void:")

func _gen_block_list(blocks: Array, builder: _CodeBuilder) -> void:
	if blocks.is_empty():
		builder.add("pass")
		return
	for block in blocks:
		_gen_block(block, builder)

func _gen_block(block: Dictionary, builder: _CodeBuilder) -> void:
	var t: String = block.get("type", "")
	var props: Dictionary = block.get("properties", {})
	var inner: Array = block.get("inner", [])
	var inner_else: Array = block.get("inner_else", [])

	# Try addon generators first
	var addon_code := AddonRegistry.instance().generate_block_code(
		block,
		func(): var b2 := _CodeBuilder.new(); b2._indent = builder._indent + 1; _gen_block_list(inner, b2); return b2.build(),
		func(): var b2 := _CodeBuilder.new(); b2._indent = builder._indent; _gen_block_list(inner_else, b2); return b2.build(),
		builder._indent)
	if addon_code != "":
		builder.raw(addon_code)
		return

	match t:
		# ── Control ───────────────────────────────────────────────────────────
		"flow/if":
			var cond: String = props.get("condition", "true")
			builder.add("if %s:" % cond)
			builder.indent()
			_gen_block_list(inner, builder)
			builder.dedent()
			if inner_else.size() > 0:
				builder.add("else:")
				builder.indent()
				_gen_block_list(inner_else, builder)
				builder.dedent()

		"flow/for_range":
			var from_v: String = str(props.get("from", 0))
			var to_v: String = str(props.get("to", 10))
			var step_v: String = str(props.get("step", 1))
			builder.add("for _i in range(%s, %s, %s):" % [from_v, to_v, step_v])
			builder.indent()
			_gen_block_list(inner, builder)
			builder.dedent()

		"flow/for_array":
			var vname: String = props.get("var_name", "item")
			var arr: String = props.get("array_var", "my_array")
			builder.add("for %s in %s:" % [vname, arr])
			builder.indent()
			_gen_block_list(inner, builder)
			builder.dedent()

		"flow/while":
			var cond: String = props.get("condition", "true")
			builder.add("while %s:" % cond)
			builder.indent()
			_gen_block_list(inner, builder)
			builder.dedent()

		"flow/match":
			var val: String = props.get("value", "my_var")
			var b0: String = props.get("branch_0", "0")
			var b1: String = props.get("branch_1", "1")
			var b2_str: String = props.get("branch_2", "2")
			builder.add("match %s:" % val)
			builder.indent()
			builder.add("%s:" % b0)
			builder.indent()
			var inner0: Array = block.get("inner_0", [])
			_gen_block_list(inner0 if inner0.size() > 0 else [], builder)
			if inner0.is_empty():
				builder.add("pass")
			builder.dedent()
			builder.add("%s:" % b1)
			builder.indent()
			builder.add("pass")
			builder.dedent()
			builder.add("%s:" % b2_str)
			builder.indent()
			builder.add("pass")
			builder.dedent()
			builder.add("_:")
			builder.indent()
			_gen_block_list(inner, builder)
			builder.dedent()
			builder.dedent()

		"flow/break":    builder.add("break")
		"flow/continue": builder.add("continue")
		"flow/return":
			builder.add("return %s" % props.get("value", "null"))
		"flow/return_void": builder.add("return")
		"flow/pass":     builder.add("pass")

		# ── Variables ─────────────────────────────────────────────────────────
		"variables/set_var":
			var vname: String = props.get("var_name", "my_var")
			var val: String = props.get("value", "0")
			builder.add("%s = %s" % [vname, val])

		"variables/declare_var":
			var vname: String = props.get("var_name", "my_var")
			var vtype: String = props.get("var_type", "var")
			var val: String = props.get("value", "0")
			if vtype == "var":
				builder.add("var %s = %s" % [vname, val])
			else:
				builder.add("var %s: %s = %s" % [vname, vtype, val])

		"variables/set_property":
			var obj: String = props.get("object", "self")
			var pname: String = props.get("property_name", "position")
			var val: String = props.get("value", "Vector2.ZERO")
			builder.add("%s.%s = %s" % [obj, pname, val])

		# ── Functions ─────────────────────────────────────────────────────────
		"functions/print_node":
			builder.add("print(%s)" % props.get("value", '"Hello World"'))

		"functions/printerr_node":
			builder.add("printerr(%s)" % props.get("value", '"Error"'))

		"functions/call_self":
			var mname: String = props.get("method_name", "my_method")
			var a0: String = props.get("arg_0", "")
			var a1: String = props.get("arg_1", "")
			var args := _build_args([a0, a1])
			builder.add("%s(%s)" % [mname, args])

		"functions/call_method_block":
			var obj: String = props.get("object", "self")
			var mname: String = props.get("method_name", "my_method")
			var a0: String = props.get("arg_0", "")
			builder.add("%s.%s(%s)" % [obj, mname, a0])

		"functions/add_child":
			builder.add("%s.add_child(%s)" % [props.get("parent", "self"), props.get("child", "_inst")])

		"functions/queue_free":
			builder.add("%s.queue_free()" % props.get("node", "self"))

		"functions/instantiate":
			var sv: String = props.get("scene_var", "my_scene")
			var sa: String = props.get("store_as", "_inst")
			builder.add("var %s = %s.instantiate()" % [sa, sv])

		"functions/get_node_block":
			var path: String = props.get("path", "NodePath")
			var sa: String = props.get("store_as", "_node")
			builder.add('var %s = get_node("%s")' % [sa, path])

		# ── Math utility ──────────────────────────────────────────────────────
		"math/set_add":
			var vname: String = props.get("var_name", "my_var")
			var amount: String = props.get("amount", "1")
			builder.add("%s += %s" % [vname, amount])

		"math/randomize":
			builder.add("randomize()")

		# ── Signals ───────────────────────────────────────────────────────────
		"signals/emit":
			var sname: String = props.get("signal_name", "my_signal")
			var arg0: String = props.get("arg_0", "")
			if arg0 != "":
				builder.add("%s.emit(%s)" % [sname, arg0])
			else:
				builder.add("%s.emit()" % sname)

		"signals/connect_signal":
			var src: String = props.get("source", "self")
			var sname: String = props.get("signal_name", "my_signal")
			var target: String = props.get("target_method", "on_signal")
			builder.add("%s.%s.connect(%s)" % [src, sname, target])

		"signals/disconnect_signal":
			var src: String = props.get("source", "self")
			var sname: String = props.get("signal_name", "my_signal")
			var target: String = props.get("target_method", "on_signal")
			builder.add("%s.%s.disconnect(%s)" % [src, sname, target])

		# ── Utilities ─────────────────────────────────────────────────────────
		"utils/raw_code":
			var code_str: String = props.get("code", "pass")
			for line in code_str.split("\n"):
				builder.add(line)

		"utils/assert_node":
			var cond: String = props.get("condition", "true")
			var msg: String = props.get("message", "Assertion failed")
			builder.add('assert(%s, "%s")' % [cond, msg])

		"utils/comment":
			var txt: String = props.get("text", "")
			for line in txt.split("\n"):
				builder.add("# %s" % line)

		_:
			builder.add("# TODO: unknown block type: %s" % t)

# ── Helpers ───────────────────────────────────────────────────────────────────

func _val(v) -> String:
	if v is bool:  return "true" if v else "false"
	if v is int:   return str(v)
	if v is float: return str(v)
	if v is String: return '"%s"' % str(v).replace('"', '\\"')
	return str(v)

func _build_args(args: Array) -> String:
	var filtered: Array[String] = []
	for a in args:
		var s := str(a).strip_edges()
		if s != "" and s != "null":
			filtered.append(s)
	return ", ".join(filtered)

# ── Inner class ───────────────────────────────────────────────────────────────

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
