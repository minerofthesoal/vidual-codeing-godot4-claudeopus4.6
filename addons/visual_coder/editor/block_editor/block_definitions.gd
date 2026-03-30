@tool
## BlockDefinitions – catalog of all built-in block types for the block editor.
##
## A block definition Dictionary has the keys:
##   type        : String  – unique id, e.g. "events/on_ready"
##   label       : String  – text shown on the block
##   category    : String  – palette grouping
##   color       : Color
##   shape       : String  – "hat" | "statement" | "value" | "cap"
##   fields      : Array[Dictionary]  – inline editable fields
##                  Each field: {name, type, default}
##                  type = "string" | "int" | "float" | "bool" | "choice"
##                  for "choice" add: options = ["option1", ...]
##   has_inner   : bool    – true for control blocks with inner body
##   has_else    : bool    – true if also has an else body
class_name BlockDefinitions
extends RefCounted

# ── Field helper ──────────────────────────────────────────────────────────────

static func _f(name: String, type: String, default, options: Array = []) -> Dictionary:
	var d := {"name": name, "type": type, "default": default}
	if options.size() > 0:
		d["options"] = options
	return d

# ── Definition helper ─────────────────────────────────────────────────────────

static func make_def(type: String, label: String, category: String, color: Color,
		shape: String, fields: Array = [], has_inner: bool = false,
		has_else: bool = false) -> Dictionary:
	return {
		"type": type,
		"label": label,
		"category": category,
		"color": color,
		"shape": shape,
		"fields": fields,
		"has_inner": has_inner,
		"has_else": has_else
	}

# ── All built-in block definitions ───────────────────────────────────────────

static func get_all() -> Array[Dictionary]:
	var defs: Array[Dictionary] = []

	# ── EVENTS ────────────────────────────────────────────────────────────────
	var ev := Color(0.18, 0.62, 0.28)
	defs.append(make_def("events/on_ready",            "When Ready",           "Events", ev, "hat"))
	defs.append(make_def("events/on_process",          "When Process (delta)", "Events", ev, "hat"))
	defs.append(make_def("events/on_physics_process",  "When Physics Process", "Events", ev, "hat"))
	defs.append(make_def("events/on_input",            "When Input (event)",   "Events", ev, "hat"))
	defs.append(make_def("events/on_enter_tree",       "When Enter Tree",      "Events", ev, "hat"))
	defs.append(make_def("events/on_exit_tree",        "When Exit Tree",       "Events", ev, "hat"))
	defs.append(make_def("events/on_signal",           "When Signal", "Events", ev, "hat",
		[_f("signal_name", "string", "my_signal")]))
	defs.append(make_def("events/custom_function",     "Define Function", "Events", ev, "hat",
		[_f("func_name", "string", "my_function")]))

	# ── CONTROL ───────────────────────────────────────────────────────────────
	var cf := Color(0.80, 0.55, 0.10)
	defs.append(make_def("flow/if",         "If",      "Control", cf, "statement",
		[_f("condition", "string", "true")], true, true))
	defs.append(make_def("flow/for_range",  "Repeat",  "Control", cf, "statement",
		[_f("from", "int", 0), _f("to", "int", 10), _f("step", "int", 1)], true))
	defs.append(make_def("flow/for_array",  "For Each in", "Control", cf, "statement",
		[_f("var_name", "string", "item"), _f("array_var", "string", "my_array")], true))
	defs.append(make_def("flow/while",      "While",   "Control", cf, "statement",
		[_f("condition", "string", "true")], true))
	defs.append(make_def("flow/break",      "Break",   "Control", cf, "cap"))
	defs.append(make_def("flow/continue",   "Continue","Control", cf, "cap"))
	defs.append(make_def("flow/return",     "Return",  "Control", cf, "cap",
		[_f("value", "string", "null")]))
	defs.append(make_def("flow/return_void","Return (void)", "Control", cf, "cap"))
	defs.append(make_def("flow/pass",       "Pass",    "Control", cf, "statement"))
	defs.append(make_def("flow/match",      "Match",   "Control", cf, "statement",
		[_f("value", "string", "my_var"),
		 _f("branch_0", "string", "0"),
		 _f("branch_1", "string", "1"),
		 _f("branch_2", "string", "2")],
		true))

	# ── VARIABLES ─────────────────────────────────────────────────────────────
	var va := Color(0.20, 0.45, 0.85)
	defs.append(make_def("variables/set_var",    "Set",     "Variables", va, "statement",
		[_f("var_name", "string", "my_var"), _f("value", "string", "0")]))
	defs.append(make_def("variables/declare_var","Declare", "Variables", va, "statement",
		[_f("var_name", "string", "my_var"),
		 _f("var_type", "choice", "var", ["var","int","float","String","bool","Vector2","Vector3","Array","Dictionary"]),
		 _f("value", "string", "0")]))
	defs.append(make_def("variables/set_property","Set Property", "Variables", va, "statement",
		[_f("object", "string", "self"), _f("property_name", "string", "position"),
		 _f("value", "string", "Vector2.ZERO")]))

	# ── FUNCTIONS ─────────────────────────────────────────────────────────────
	var fn_c := Color(0.10, 0.55, 0.60)
	defs.append(make_def("functions/print_node", "Print", "Functions", fn_c, "statement",
		[_f("value", "string", '"Hello World"')]))
	defs.append(make_def("functions/printerr_node", "Print Error", "Functions", fn_c, "statement",
		[_f("value", "string", '"Error"')]))
	defs.append(make_def("functions/call_self", "Call Method", "Functions", fn_c, "statement",
		[_f("method_name", "string", "my_method"),
		 _f("arg_0", "string", ""),
		 _f("arg_1", "string", "")]))
	defs.append(make_def("functions/call_method_block", "Call Method On", "Functions", fn_c, "statement",
		[_f("object", "string", "self"),
		 _f("method_name", "string", "my_method"),
		 _f("arg_0", "string", "")]))
	defs.append(make_def("functions/add_child", "Add Child", "Functions", fn_c, "statement",
		[_f("parent", "string", "self"), _f("child", "string", "_inst")]))
	defs.append(make_def("functions/queue_free", "Queue Free", "Functions", fn_c, "statement",
		[_f("node", "string", "self")]))
	defs.append(make_def("functions/instantiate", "Instantiate", "Functions", fn_c, "statement",
		[_f("scene_var", "string", "my_scene"), _f("store_as", "string", "_inst")]))
	defs.append(make_def("functions/get_node_block", "Get Node (store)", "Functions", fn_c, "statement",
		[_f("path", "string", "NodePath"), _f("store_as", "string", "_node")]))

	# ── MATH ──────────────────────────────────────────────────────────────────
	var ma := Color(0.60, 0.20, 0.70)
	defs.append(make_def("math/set_add",   "Change by",       "Math", ma, "statement",
		[_f("var_name", "string", "my_var"), _f("amount", "string", "1")]))
	defs.append(make_def("math/randomize", "Randomize Seed",  "Math", ma, "statement"))
	defs.append(make_def("utils/raw_code", "Raw GDScript",    "Math", Color(0.3, 0.3, 0.3), "statement",
		[_f("code", "string", "pass")]))
	defs.append(make_def("utils/assert_node", "Assert",       "Math", Color(0.3, 0.3, 0.3), "statement",
		[_f("condition", "string", "true"), _f("message", "string", "Assertion failed")]))
	defs.append(make_def("utils/comment",  "Comment",         "Math", Color(0.25, 0.25, 0.25), "statement",
		[_f("text", "string", "Add comment here...")]))

	# ── SIGNALS ───────────────────────────────────────────────────────────────
	var si := Color(0.70, 0.20, 0.50)
	defs.append(make_def("signals/emit",    "Emit Signal",    "Signals", si, "statement",
		[_f("signal_name", "string", "my_signal"), _f("arg_0", "string", "")]))
	defs.append(make_def("signals/connect_signal", "Connect Signal", "Signals", si, "statement",
		[_f("source", "string", "self"), _f("signal_name", "string", "my_signal"),
		 _f("target_method", "string", "on_signal")]))
	defs.append(make_def("signals/disconnect_signal", "Disconnect Signal", "Signals", si, "statement",
		[_f("source", "string", "self"), _f("signal_name", "string", "my_signal"),
		 _f("target_method", "string", "on_signal")]))

	return defs

# ── Lookup ────────────────────────────────────────────────────────────────────

static func get_by_type(type: String) -> Dictionary:
	for d in get_all():
		if d["type"] == type:
			return d
	return {}

static func get_categories() -> Array[String]:
	var cats: Array[String] = []
	for d in get_all():
		if not d["category"] in cats:
			cats.append(d["category"])
	return cats

static func get_by_category(cat: String) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for d in get_all():
		if d["category"] == cat:
			result.append(d)
	return result
