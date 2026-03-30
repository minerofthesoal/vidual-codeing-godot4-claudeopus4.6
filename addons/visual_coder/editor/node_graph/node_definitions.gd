@tool
## NodeDefinitions – catalog of every built-in node type for the graph editor.
##
## A node definition is a Dictionary with the keys:
##   type       : String   – unique identifier, e.g. "events/on_ready"
##   title      : String   – displayed in the node header
##   category   : String   – palette grouping
##   color      : Color    – header background color
##   inputs     : Array    – [{name, type, color, default?}]  data + exec ports
##   outputs    : Array    – [{name, type, color}]
##   properties : Dictionary – editable properties keyed by name → default value
##   code_fn    : String   – name of static method in NodeCodeGenerator to call
##
## Port type constants are defined below.
class_name NodeDefinitions
extends RefCounted

# ── Port type IDs ─────────────────────────────────────────────────────────────
const T_EXEC    := 0
const T_BOOL    := 1
const T_INT     := 2
const T_FLOAT   := 3
const T_STRING  := 4
const T_VARIANT := 5
const T_VECTOR2 := 6
const T_VECTOR3 := 7
const T_ARRAY   := 8
const T_DICT    := 9
const T_OBJECT  := 10
const T_COLOR   := 11

# Port colors keyed by type id
static func port_color(t: int) -> Color:
	match t:
		T_EXEC:    return Color(1.0, 1.0, 1.0)
		T_BOOL:    return Color(0.35, 0.55, 1.0)
		T_INT:     return Color(0.25, 0.85, 0.35)
		T_FLOAT:   return Color(1.0,  0.85, 0.25)
		T_STRING:  return Color(1.0,  0.45, 0.65)
		T_VARIANT: return Color(0.7,  0.7,  0.7 )
		T_VECTOR2: return Color(0.5,  0.8,  1.0 )
		T_VECTOR3: return Color(0.3,  0.9,  0.9 )
		T_ARRAY:   return Color(1.0,  0.6,  0.2 )
		T_DICT:    return Color(0.9,  0.5,  0.1 )
		T_OBJECT:  return Color(0.7,  0.3,  0.9 )
		T_COLOR:   return Color(0.9,  0.9,  0.3 )
	return Color(0.7, 0.7, 0.7)

static func port_name(t: int) -> String:
	match t:
		T_EXEC:    return "Exec"
		T_BOOL:    return "Bool"
		T_INT:     return "Int"
		T_FLOAT:   return "Float"
		T_STRING:  return "String"
		T_VARIANT: return "Variant"
		T_VECTOR2: return "Vector2"
		T_VECTOR3: return "Vector3"
		T_ARRAY:   return "Array"
		T_DICT:    return "Dictionary"
		T_OBJECT:  return "Object"
		T_COLOR:   return "Color"
	return "?"

# ── Helper ────────────────────────────────────────────────────────────────────

static func _p(name: String, type: int, default = null) -> Dictionary:
	var d := {"name": name, "type": type, "color": port_color(type)}
	if default != null:
		d["default"] = default
	return d

static func _exec() -> Dictionary:
	return _p("▶", T_EXEC)

static func make_def(type: String, title: String, category: String, color: Color,
		inputs: Array, outputs: Array, properties: Dictionary = {},
		code_fn: String = "") -> Dictionary:
	return {
		"type": type,
		"title": title,
		"category": category,
		"color": color,
		"inputs": inputs,
		"outputs": outputs,
		"properties": properties,
		"code_fn": code_fn
	}

# ── All built-in node definitions ─────────────────────────────────────────────

static func get_all() -> Array[Dictionary]:
	var defs: Array[Dictionary] = []

	# ── EVENTS ────────────────────────────────────────────────────────────────
	defs.append(make_def(
		"events/on_ready", "On Ready", "Events", Color(0.18, 0.6, 0.25),
		[],
		[_p("▶", T_EXEC)],
		{}, "gen_on_ready"
	))
	defs.append(make_def(
		"events/on_process", "On Process", "Events", Color(0.18, 0.6, 0.25),
		[],
		[_p("▶", T_EXEC), _p("delta", T_FLOAT)],
		{}, "gen_on_process"
	))
	defs.append(make_def(
		"events/on_physics_process", "On Physics Process", "Events", Color(0.18, 0.6, 0.25),
		[],
		[_p("▶", T_EXEC), _p("delta", T_FLOAT)],
		{}, "gen_on_physics_process"
	))
	defs.append(make_def(
		"events/on_input", "On Input", "Events", Color(0.18, 0.6, 0.25),
		[],
		[_p("▶", T_EXEC), _p("event", T_OBJECT)],
		{}, "gen_on_input"
	))
	defs.append(make_def(
		"events/on_signal", "On Signal", "Events", Color(0.18, 0.6, 0.25),
		[],
		[_p("▶", T_EXEC)],
		{"signal_name": "my_signal"}, "gen_on_signal"
	))
	defs.append(make_def(
		"events/on_enter_tree", "On Enter Tree", "Events", Color(0.18, 0.6, 0.25),
		[],
		[_p("▶", T_EXEC)],
		{}, "gen_on_enter_tree"
	))
	defs.append(make_def(
		"events/on_exit_tree", "On Exit Tree", "Events", Color(0.18, 0.6, 0.25),
		[],
		[_p("▶", T_EXEC)],
		{}, "gen_on_exit_tree"
	))
	defs.append(make_def(
		"events/custom_function", "Custom Function", "Events", Color(0.18, 0.6, 0.25),
		[],
		[_p("▶", T_EXEC)],
		{"func_name": "my_function"}, "gen_custom_function"
	))

	# ── FLOW CONTROL ──────────────────────────────────────────────────────────
	defs.append(make_def(
		"flow/if", "If", "Flow Control", Color(0.8, 0.55, 0.1),
		[_exec(), _p("condition", T_BOOL)],
		[_p("▶ true", T_EXEC), _p("▶ false", T_EXEC)],
		{}, "gen_if"
	))
	defs.append(make_def(
		"flow/for_range", "For Range", "Flow Control", Color(0.8, 0.55, 0.1),
		[_exec(), _p("from", T_INT, 0), _p("to", T_INT, 10), _p("step", T_INT, 1)],
		[_p("▶ loop", T_EXEC), _p("index", T_INT), _p("▶ done", T_EXEC)],
		{}, "gen_for_range"
	))
	defs.append(make_def(
		"flow/for_array", "For Array", "Flow Control", Color(0.8, 0.55, 0.1),
		[_exec(), _p("array", T_ARRAY)],
		[_p("▶ loop", T_EXEC), _p("item", T_VARIANT), _p("▶ done", T_EXEC)],
		{"var_name": "item"}, "gen_for_array"
	))
	defs.append(make_def(
		"flow/while", "While", "Flow Control", Color(0.8, 0.55, 0.1),
		[_exec(), _p("condition", T_BOOL)],
		[_p("▶ loop", T_EXEC), _p("▶ done", T_EXEC)],
		{}, "gen_while"
	))
	defs.append(make_def(
		"flow/match", "Match", "Flow Control", Color(0.8, 0.55, 0.1),
		[_exec(), _p("value", T_VARIANT)],
		[_p("▶ branch 0", T_EXEC), _p("▶ branch 1", T_EXEC),
		 _p("▶ branch 2", T_EXEC), _p("▶ default", T_EXEC)],
		{"branch_0": "0", "branch_1": "1", "branch_2": "2"}, "gen_match"
	))
	defs.append(make_def(
		"flow/branch", "Branch (Switch)", "Flow Control", Color(0.8, 0.55, 0.1),
		[_exec(), _p("value", T_BOOL)],
		[_p("▶ true", T_EXEC), _p("▶ false", T_EXEC)],
		{}, "gen_if"
	))
	defs.append(make_def(
		"flow/return", "Return", "Flow Control", Color(0.8, 0.55, 0.1),
		[_exec(), _p("value", T_VARIANT)],
		[],
		{}, "gen_return"
	))
	defs.append(make_def(
		"flow/return_void", "Return (void)", "Flow Control", Color(0.8, 0.55, 0.1),
		[_exec()],
		[],
		{}, "gen_return_void"
	))
	defs.append(make_def(
		"flow/break", "Break", "Flow Control", Color(0.8, 0.55, 0.1),
		[_exec()],
		[],
		{}, "gen_break"
	))
	defs.append(make_def(
		"flow/continue", "Continue", "Flow Control", Color(0.8, 0.55, 0.1),
		[_exec()],
		[],
		{}, "gen_continue"
	))
	defs.append(make_def(
		"flow/pass", "Pass", "Flow Control", Color(0.8, 0.55, 0.1),
		[_exec()],
		[_p("▶", T_EXEC)],
		{}, "gen_pass"
	))

	# ── VARIABLES ─────────────────────────────────────────────────────────────
	defs.append(make_def(
		"variables/get_var", "Get Variable", "Variables", Color(0.2, 0.45, 0.85),
		[],
		[_p("value", T_VARIANT)],
		{"var_name": "my_var"}, "gen_get_var"
	))
	defs.append(make_def(
		"variables/set_var", "Set Variable", "Variables", Color(0.2, 0.45, 0.85),
		[_exec(), _p("value", T_VARIANT)],
		[_p("▶", T_EXEC), _p("value", T_VARIANT)],
		{"var_name": "my_var"}, "gen_set_var"
	))
	defs.append(make_def(
		"variables/declare_var", "Declare Variable", "Variables", Color(0.2, 0.45, 0.85),
		[_exec(), _p("value", T_VARIANT)],
		[_p("▶", T_EXEC)],
		{"var_name": "my_var", "var_type": "var"}, "gen_declare_var"
	))
	defs.append(make_def(
		"variables/get_property", "Get Property", "Variables", Color(0.2, 0.45, 0.85),
		[_p("object", T_OBJECT)],
		[_p("value", T_VARIANT)],
		{"property_name": "position"}, "gen_get_property"
	))
	defs.append(make_def(
		"variables/set_property", "Set Property", "Variables", Color(0.2, 0.45, 0.85),
		[_exec(), _p("object", T_OBJECT), _p("value", T_VARIANT)],
		[_p("▶", T_EXEC)],
		{"property_name": "position"}, "gen_set_property"
	))

	# ── LITERALS ──────────────────────────────────────────────────────────────
	defs.append(make_def(
		"literals/bool_literal", "Bool", "Literals", Color(0.35, 0.35, 0.65),
		[],
		[_p("value", T_BOOL)],
		{"value": false}, "gen_bool_literal"
	))
	defs.append(make_def(
		"literals/int_literal", "Integer", "Literals", Color(0.35, 0.35, 0.65),
		[],
		[_p("value", T_INT)],
		{"value": 0}, "gen_int_literal"
	))
	defs.append(make_def(
		"literals/float_literal", "Float", "Literals", Color(0.35, 0.35, 0.65),
		[],
		[_p("value", T_FLOAT)],
		{"value": 0.0}, "gen_float_literal"
	))
	defs.append(make_def(
		"literals/string_literal", "String", "Literals", Color(0.35, 0.35, 0.65),
		[],
		[_p("value", T_STRING)],
		{"value": "Hello"}, "gen_string_literal"
	))
	defs.append(make_def(
		"literals/vector2_literal", "Vector2", "Literals", Color(0.35, 0.35, 0.65),
		[],
		[_p("value", T_VECTOR2)],
		{"x": 0.0, "y": 0.0}, "gen_vector2_literal"
	))
	defs.append(make_def(
		"literals/vector3_literal", "Vector3", "Literals", Color(0.35, 0.35, 0.65),
		[],
		[_p("value", T_VECTOR3)],
		{"x": 0.0, "y": 0.0, "z": 0.0}, "gen_vector3_literal"
	))
	defs.append(make_def(
		"literals/color_literal", "Color", "Literals", Color(0.35, 0.35, 0.65),
		[],
		[_p("value", T_COLOR)],
		{"r": 1.0, "g": 1.0, "b": 1.0, "a": 1.0}, "gen_color_literal"
	))
	defs.append(make_def(
		"literals/null_literal", "Null", "Literals", Color(0.35, 0.35, 0.65),
		[],
		[_p("value", T_VARIANT)],
		{}, "gen_null_literal"
	))
	defs.append(make_def(
		"literals/self_ref", "Self", "Literals", Color(0.35, 0.35, 0.65),
		[],
		[_p("self", T_OBJECT)],
		{}, "gen_self"
	))

	# ── MATH ──────────────────────────────────────────────────────────────────
	defs.append(make_def(
		"math/add", "Add  (+)", "Math", Color(0.6, 0.2, 0.7),
		[_p("A", T_VARIANT), _p("B", T_VARIANT)],
		[_p("result", T_VARIANT)],
		{}, "gen_add"
	))
	defs.append(make_def(
		"math/subtract", "Subtract  (−)", "Math", Color(0.6, 0.2, 0.7),
		[_p("A", T_VARIANT), _p("B", T_VARIANT)],
		[_p("result", T_VARIANT)],
		{}, "gen_subtract"
	))
	defs.append(make_def(
		"math/multiply", "Multiply  (×)", "Math", Color(0.6, 0.2, 0.7),
		[_p("A", T_VARIANT), _p("B", T_VARIANT)],
		[_p("result", T_VARIANT)],
		{}, "gen_multiply"
	))
	defs.append(make_def(
		"math/divide", "Divide  (÷)", "Math", Color(0.6, 0.2, 0.7),
		[_p("A", T_VARIANT), _p("B", T_VARIANT)],
		[_p("result", T_VARIANT)],
		{}, "gen_divide"
	))
	defs.append(make_def(
		"math/modulo", "Modulo  (%)", "Math", Color(0.6, 0.2, 0.7),
		[_p("A", T_VARIANT), _p("B", T_VARIANT)],
		[_p("result", T_VARIANT)],
		{}, "gen_modulo"
	))
	defs.append(make_def(
		"math/power", "Power  (^)", "Math", Color(0.6, 0.2, 0.7),
		[_p("base", T_FLOAT), _p("exp", T_FLOAT)],
		[_p("result", T_FLOAT)],
		{}, "gen_power"
	))
	defs.append(make_def(
		"math/negate", "Negate  (−x)", "Math", Color(0.6, 0.2, 0.7),
		[_p("A", T_VARIANT)],
		[_p("result", T_VARIANT)],
		{}, "gen_negate"
	))
	defs.append(make_def(
		"math/abs_val", "Abs", "Math", Color(0.6, 0.2, 0.7),
		[_p("x", T_FLOAT)],
		[_p("result", T_FLOAT)],
		{}, "gen_abs"
	))
	defs.append(make_def(
		"math/sqrt", "Sqrt", "Math", Color(0.6, 0.2, 0.7),
		[_p("x", T_FLOAT)],
		[_p("result", T_FLOAT)],
		{}, "gen_sqrt"
	))
	defs.append(make_def(
		"math/clamp", "Clamp", "Math", Color(0.6, 0.2, 0.7),
		[_p("value", T_FLOAT), _p("min", T_FLOAT), _p("max", T_FLOAT)],
		[_p("result", T_FLOAT)],
		{}, "gen_clamp"
	))
	defs.append(make_def(
		"math/lerp", "Lerp", "Math", Color(0.6, 0.2, 0.7),
		[_p("from", T_FLOAT), _p("to", T_FLOAT), _p("t", T_FLOAT)],
		[_p("result", T_FLOAT)],
		{}, "gen_lerp"
	))
	defs.append(make_def(
		"math/round", "Round", "Math", Color(0.6, 0.2, 0.7),
		[_p("x", T_FLOAT)],
		[_p("result", T_FLOAT)],
		{}, "gen_round"
	))
	defs.append(make_def(
		"math/floor_fn", "Floor", "Math", Color(0.6, 0.2, 0.7),
		[_p("x", T_FLOAT)],
		[_p("result", T_FLOAT)],
		{}, "gen_floor"
	))
	defs.append(make_def(
		"math/ceil_fn", "Ceil", "Math", Color(0.6, 0.2, 0.7),
		[_p("x", T_FLOAT)],
		[_p("result", T_FLOAT)],
		{}, "gen_ceil"
	))
	defs.append(make_def(
		"math/sin_fn", "Sin", "Math", Color(0.6, 0.2, 0.7),
		[_p("angle", T_FLOAT)],
		[_p("result", T_FLOAT)],
		{}, "gen_sin"
	))
	defs.append(make_def(
		"math/cos_fn", "Cos", "Math", Color(0.6, 0.2, 0.7),
		[_p("angle", T_FLOAT)],
		[_p("result", T_FLOAT)],
		{}, "gen_cos"
	))
	defs.append(make_def(
		"math/random", "Randomf", "Math", Color(0.6, 0.2, 0.7),
		[],
		[_p("value", T_FLOAT)],
		{}, "gen_randf"
	))
	defs.append(make_def(
		"math/randi_range", "Randi Range", "Math", Color(0.6, 0.2, 0.7),
		[_p("from", T_INT), _p("to", T_INT)],
		[_p("value", T_INT)],
		{}, "gen_randi_range"
	))

	# ── LOGIC ─────────────────────────────────────────────────────────────────
	defs.append(make_def(
		"logic/and", "And  (&&)", "Logic", Color(0.25, 0.55, 0.75),
		[_p("A", T_BOOL), _p("B", T_BOOL)],
		[_p("result", T_BOOL)],
		{}, "gen_and"
	))
	defs.append(make_def(
		"logic/or", "Or  (||)", "Logic", Color(0.25, 0.55, 0.75),
		[_p("A", T_BOOL), _p("B", T_BOOL)],
		[_p("result", T_BOOL)],
		{}, "gen_or"
	))
	defs.append(make_def(
		"logic/not", "Not  (!)", "Logic", Color(0.25, 0.55, 0.75),
		[_p("A", T_BOOL)],
		[_p("result", T_BOOL)],
		{}, "gen_not"
	))
	defs.append(make_def(
		"logic/equal", "Equal  (==)", "Logic", Color(0.25, 0.55, 0.75),
		[_p("A", T_VARIANT), _p("B", T_VARIANT)],
		[_p("result", T_BOOL)],
		{}, "gen_equal"
	))
	defs.append(make_def(
		"logic/not_equal", "Not Equal  (!=)", "Logic", Color(0.25, 0.55, 0.75),
		[_p("A", T_VARIANT), _p("B", T_VARIANT)],
		[_p("result", T_BOOL)],
		{}, "gen_not_equal"
	))
	defs.append(make_def(
		"logic/greater", "Greater  (>)", "Logic", Color(0.25, 0.55, 0.75),
		[_p("A", T_VARIANT), _p("B", T_VARIANT)],
		[_p("result", T_BOOL)],
		{}, "gen_greater"
	))
	defs.append(make_def(
		"logic/greater_equal", "Greater Equal  (>=)", "Logic", Color(0.25, 0.55, 0.75),
		[_p("A", T_VARIANT), _p("B", T_VARIANT)],
		[_p("result", T_BOOL)],
		{}, "gen_greater_equal"
	))
	defs.append(make_def(
		"logic/less", "Less  (<)", "Logic", Color(0.25, 0.55, 0.75),
		[_p("A", T_VARIANT), _p("B", T_VARIANT)],
		[_p("result", T_BOOL)],
		{}, "gen_less"
	))
	defs.append(make_def(
		"logic/less_equal", "Less Equal  (<=)", "Logic", Color(0.25, 0.55, 0.75),
		[_p("A", T_VARIANT), _p("B", T_VARIANT)],
		[_p("result", T_BOOL)],
		{}, "gen_less_equal"
	))
	defs.append(make_def(
		"logic/ternary", "Ternary  (a if c else b)", "Logic", Color(0.25, 0.55, 0.75),
		[_p("condition", T_BOOL), _p("true_val", T_VARIANT), _p("false_val", T_VARIANT)],
		[_p("result", T_VARIANT)],
		{}, "gen_ternary"
	))

	# ── STRINGS ───────────────────────────────────────────────────────────────
	defs.append(make_def(
		"strings/concat", "Concatenate", "Strings", Color(0.75, 0.35, 0.55),
		[_p("A", T_STRING), _p("B", T_STRING)],
		[_p("result", T_STRING)],
		{}, "gen_concat"
	))
	defs.append(make_def(
		"strings/format", "Format String", "Strings", Color(0.75, 0.35, 0.55),
		[_p("template", T_STRING), _p("value", T_VARIANT)],
		[_p("result", T_STRING)],
		{}, "gen_format"
	))
	defs.append(make_def(
		"strings/to_int", "To Int", "Strings", Color(0.75, 0.35, 0.55),
		[_p("text", T_STRING)],
		[_p("value", T_INT)],
		{}, "gen_to_int"
	))
	defs.append(make_def(
		"strings/to_float", "To Float", "Strings", Color(0.75, 0.35, 0.55),
		[_p("text", T_STRING)],
		[_p("value", T_FLOAT)],
		{}, "gen_to_float"
	))
	defs.append(make_def(
		"strings/str_convert", "To String", "Strings", Color(0.75, 0.35, 0.55),
		[_p("value", T_VARIANT)],
		[_p("text", T_STRING)],
		{}, "gen_str"
	))
	defs.append(make_def(
		"strings/length", "Length", "Strings", Color(0.75, 0.35, 0.55),
		[_p("text", T_STRING)],
		[_p("length", T_INT)],
		{}, "gen_string_length"
	))
	defs.append(make_def(
		"strings/substr", "Substring", "Strings", Color(0.75, 0.35, 0.55),
		[_p("text", T_STRING), _p("from", T_INT), _p("len", T_INT)],
		[_p("result", T_STRING)],
		{}, "gen_substr"
	))
	defs.append(make_def(
		"strings/split", "Split", "Strings", Color(0.75, 0.35, 0.55),
		[_p("text", T_STRING), _p("delimiter", T_STRING)],
		[_p("parts", T_ARRAY)],
		{}, "gen_split"
	))

	# ── ARRAYS ────────────────────────────────────────────────────────────────
	defs.append(make_def(
		"arrays/make_array", "Make Array", "Arrays", Color(0.75, 0.5, 0.15),
		[_p("item 0", T_VARIANT), _p("item 1", T_VARIANT), _p("item 2", T_VARIANT)],
		[_p("array", T_ARRAY)],
		{}, "gen_make_array"
	))
	defs.append(make_def(
		"arrays/array_size", "Array Size", "Arrays", Color(0.75, 0.5, 0.15),
		[_p("array", T_ARRAY)],
		[_p("size", T_INT)],
		{}, "gen_array_size"
	))
	defs.append(make_def(
		"arrays/array_get", "Array Get", "Arrays", Color(0.75, 0.5, 0.15),
		[_p("array", T_ARRAY), _p("index", T_INT)],
		[_p("value", T_VARIANT)],
		{}, "gen_array_get"
	))
	defs.append(make_def(
		"arrays/array_set", "Array Set", "Arrays", Color(0.75, 0.5, 0.15),
		[_exec(), _p("array", T_ARRAY), _p("index", T_INT), _p("value", T_VARIANT)],
		[_p("▶", T_EXEC)],
		{}, "gen_array_set"
	))
	defs.append(make_def(
		"arrays/array_append", "Array Append", "Arrays", Color(0.75, 0.5, 0.15),
		[_exec(), _p("array", T_ARRAY), _p("value", T_VARIANT)],
		[_p("▶", T_EXEC)],
		{}, "gen_array_append"
	))
	defs.append(make_def(
		"arrays/array_remove", "Array Remove At", "Arrays", Color(0.75, 0.5, 0.15),
		[_exec(), _p("array", T_ARRAY), _p("index", T_INT)],
		[_p("▶", T_EXEC)],
		{}, "gen_array_remove"
	))
	defs.append(make_def(
		"arrays/array_has", "Array Has", "Arrays", Color(0.75, 0.5, 0.15),
		[_p("array", T_ARRAY), _p("value", T_VARIANT)],
		[_p("result", T_BOOL)],
		{}, "gen_array_has"
	))

	# ── DICTIONARIES ──────────────────────────────────────────────────────────
	defs.append(make_def(
		"dicts/make_dict", "Make Dictionary", "Dictionaries", Color(0.6, 0.4, 0.1),
		[_p("key 0", T_VARIANT), _p("val 0", T_VARIANT)],
		[_p("dict", T_DICT)],
		{}, "gen_make_dict"
	))
	defs.append(make_def(
		"dicts/dict_get", "Dict Get", "Dictionaries", Color(0.6, 0.4, 0.1),
		[_p("dict", T_DICT), _p("key", T_VARIANT)],
		[_p("value", T_VARIANT)],
		{}, "gen_dict_get"
	))
	defs.append(make_def(
		"dicts/dict_set", "Dict Set", "Dictionaries", Color(0.6, 0.4, 0.1),
		[_exec(), _p("dict", T_DICT), _p("key", T_VARIANT), _p("value", T_VARIANT)],
		[_p("▶", T_EXEC)],
		{}, "gen_dict_set"
	))
	defs.append(make_def(
		"dicts/dict_has", "Dict Has Key", "Dictionaries", Color(0.6, 0.4, 0.1),
		[_p("dict", T_DICT), _p("key", T_VARIANT)],
		[_p("result", T_BOOL)],
		{}, "gen_dict_has"
	))
	defs.append(make_def(
		"dicts/dict_keys", "Dict Keys", "Dictionaries", Color(0.6, 0.4, 0.1),
		[_p("dict", T_DICT)],
		[_p("keys", T_ARRAY)],
		{}, "gen_dict_keys"
	))
	defs.append(make_def(
		"dicts/dict_values", "Dict Values", "Dictionaries", Color(0.6, 0.4, 0.1),
		[_p("dict", T_DICT)],
		[_p("values", T_ARRAY)],
		{}, "gen_dict_values"
	))

	# ── FUNCTIONS ─────────────────────────────────────────────────────────────
	defs.append(make_def(
		"functions/call_method", "Call Method", "Functions", Color(0.1, 0.55, 0.6),
		[_exec(), _p("object", T_OBJECT),
		 _p("arg 0", T_VARIANT), _p("arg 1", T_VARIANT)],
		[_p("▶", T_EXEC), _p("result", T_VARIANT)],
		{"method_name": "method_name"}, "gen_call_method"
	))
	defs.append(make_def(
		"functions/call_self", "Call Self Method", "Functions", Color(0.1, 0.55, 0.6),
		[_exec(), _p("arg 0", T_VARIANT), _p("arg 1", T_VARIANT)],
		[_p("▶", T_EXEC), _p("result", T_VARIANT)],
		{"method_name": "method_name"}, "gen_call_self"
	))
	defs.append(make_def(
		"functions/print_node", "Print", "Functions", Color(0.1, 0.55, 0.6),
		[_exec(), _p("value", T_VARIANT)],
		[_p("▶", T_EXEC)],
		{}, "gen_print"
	))
	defs.append(make_def(
		"functions/printerr_node", "Print Error", "Functions", Color(0.1, 0.55, 0.6),
		[_exec(), _p("value", T_VARIANT)],
		[_p("▶", T_EXEC)],
		{}, "gen_printerr"
	))
	defs.append(make_def(
		"functions/get_node", "Get Node", "Functions", Color(0.1, 0.55, 0.6),
		[],
		[_p("node", T_OBJECT)],
		{"path": "NodePath"}, "gen_get_node"
	))
	defs.append(make_def(
		"functions/instantiate", "Instantiate", "Functions", Color(0.1, 0.55, 0.6),
		[_exec(), _p("scene", T_OBJECT)],
		[_p("▶", T_EXEC), _p("instance", T_OBJECT)],
		{}, "gen_instantiate"
	))
	defs.append(make_def(
		"functions/add_child", "Add Child", "Functions", Color(0.1, 0.55, 0.6),
		[_exec(), _p("parent", T_OBJECT), _p("child", T_OBJECT)],
		[_p("▶", T_EXEC)],
		{}, "gen_add_child"
	))
	defs.append(make_def(
		"functions/queue_free", "Queue Free", "Functions", Color(0.1, 0.55, 0.6),
		[_exec(), _p("node", T_OBJECT)],
		[_p("▶", T_EXEC)],
		{}, "gen_queue_free"
	))

	# ── SIGNALS ───────────────────────────────────────────────────────────────
	defs.append(make_def(
		"signals/emit", "Emit Signal", "Signals", Color(0.7, 0.2, 0.5),
		[_exec(), _p("arg 0", T_VARIANT)],
		[_p("▶", T_EXEC)],
		{"signal_name": "my_signal"}, "gen_emit_signal"
	))
	defs.append(make_def(
		"signals/connect_signal", "Connect Signal", "Signals", Color(0.7, 0.2, 0.5),
		[_exec(), _p("source", T_OBJECT)],
		[_p("▶", T_EXEC)],
		{"signal_name": "my_signal", "target_method": "on_signal"}, "gen_connect_signal"
	))
	defs.append(make_def(
		"signals/disconnect_signal", "Disconnect Signal", "Signals", Color(0.7, 0.2, 0.5),
		[_exec(), _p("source", T_OBJECT)],
		[_p("▶", T_EXEC)],
		{"signal_name": "my_signal", "target_method": "on_signal"}, "gen_disconnect_signal"
	))
	defs.append(make_def(
		"signals/is_connected", "Is Connected", "Signals", Color(0.7, 0.2, 0.5),
		[_p("source", T_OBJECT)],
		[_p("connected", T_BOOL)],
		{"signal_name": "my_signal", "target_method": "on_signal"}, "gen_is_connected"
	))

	# ── UTILITIES ─────────────────────────────────────────────────────────────
	defs.append(make_def(
		"utils/comment", "Comment", "Utilities", Color(0.3, 0.3, 0.3),
		[], [],
		{"text": "Comment..."}, "gen_comment"
	))
	defs.append(make_def(
		"utils/assert_node", "Assert", "Utilities", Color(0.3, 0.3, 0.3),
		[_exec(), _p("condition", T_BOOL)],
		[_p("▶", T_EXEC)],
		{"message": "Assertion failed"}, "gen_assert"
	))
	defs.append(make_def(
		"utils/type_cast", "Type Cast (as)", "Utilities", Color(0.3, 0.3, 0.3),
		[_p("value", T_VARIANT)],
		[_p("casted", T_OBJECT)],
		{"type_name": "Node"}, "gen_cast"
	))
	defs.append(make_def(
		"utils/typeof_node", "Type Of", "Utilities", Color(0.3, 0.3, 0.3),
		[_p("value", T_VARIANT)],
		[_p("type_id", T_INT)],
		{}, "gen_typeof"
	))
	defs.append(make_def(
		"utils/is_instance", "Is Instance Of", "Utilities", Color(0.3, 0.3, 0.3),
		[_p("value", T_OBJECT)],
		[_p("result", T_BOOL)],
		{"class_name_str": "Node"}, "gen_is_instance"
	))
	defs.append(make_def(
		"utils/raw_code", "Raw GDScript", "Utilities", Color(0.3, 0.3, 0.3),
		[_exec()],
		[_p("▶", T_EXEC)],
		{"code": "pass"}, "gen_raw_code"
	))

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
