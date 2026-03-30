# Visual Coder — Godot 4.6 Visual Programming Plugin

A full-featured visual coding environment for Godot 4.6 that lets you write scripts **without touching a text editor**. Supports two complementary coding styles and covers the complete GDScript feature set.

---

## Features

### Two Visual Coding Modes

| Mode | Style | Best For |
|------|-------|----------|
| **Node Graph** | Blueprint / Flow-graph | Complex logic, data flow, visual thinkers |
| **Block Editor** | Scratch-style stacking blocks | Beginners, event-driven scripts, education |

Both modes generate identical, valid GDScript that can be applied to any node.

### Complete GDScript Coverage

| Category | Supported |
|----------|-----------|
| Events (_ready, _process, _input, custom functions…) | ✅ |
| Flow Control (if/else, for range, for array, while, match, break, continue, return) | ✅ |
| Variables (declare, get, set, get/set property) | ✅ |
| Literals (bool, int, float, String, Vector2, Vector3, Color, null, self) | ✅ |
| Math (add, subtract, multiply, divide, modulo, power, abs, sqrt, clamp, lerp, round, floor, ceil, sin, cos, randf, randi_range) | ✅ |
| Logic (and, or, not, ==, !=, >, >=, <, <=, ternary) | ✅ |
| Strings (concat, format %, to_int, to_float, str(), len, substr, split) | ✅ |
| Arrays (make, size, get, set, append, remove, has) | ✅ |
| Dictionaries (make, get, set, has, keys, values) | ✅ |
| Functions (call method on object, call self method, print, printerr, get_node, instantiate, add_child, queue_free) | ✅ |
| Signals (emit, connect, disconnect, is_connected) | ✅ |
| Utilities (assert, type cast, typeof, is instance, raw GDScript escape hatch, comment) | ✅ |

---

## Installation

### Method 1 — Copy into your project

1. Copy the `addons/visual_coder/` folder into your project's `addons/` directory.
2. Open Godot 4.6, go to **Project → Project Settings → Plugins**.
3. Find **Visual Coder** and set it to **Enabled**.
4. A new **VisualCoder** tab will appear in the main editor toolbar.

### Method 2 — AssetLib (when published)

Search for "Visual Coder" in the Godot Asset Library and click Install.

---

## Quick Start

### Node Graph Editor

1. Click the **VisualCoder** tab in the Godot editor.
2. Press **New Node Graph**.
3. **Right-click** the canvas to open the node browser, or double-click a palette item on the left.
4. Connect ports by dragging from an output port to an input port:
   - **White ports** are execution flow (▶)
   - **Coloured ports** carry data values
5. Click a node to edit its properties in the right panel.
6. Press **Generate Code** to preview the GDScript output.
7. Press **Apply to Script** to write the code directly to the open script in the Script Editor.

**Keyboard shortcuts on the canvas:**
- `Delete` / `Backspace` — delete selected nodes
- `Ctrl+Scroll` — zoom
- `Middle Mouse` / `Space+Drag` — pan

### Block Editor

1. Press **New Block Script**.
2. Browse blocks in the left palette by category.
3. Double-click a block to add it to the canvas, or drag it.
4. Drag blocks to reorder within a stack.
5. Control blocks (If, For, While) have **inner drop zones** — drag other blocks inside them.
6. Use the **right panel** to manage script-level variables.
7. Press **Generate Code** or **Apply to Script** as above.

### Saving & Loading

- **Save / Save As…** — saves the visual code as a `.vcr` (JSON) file.
- **Open…** — loads a previously saved `.vcr` file.
- The `.vcr` file is human-readable JSON and can be version-controlled.

---

## File Format

Visual Coder saves to JSON (`.vcr`) files. The format is stable and versioned:

### Node Graph format

```json
{
  "version": "1.0.0",
  "type": "node_graph",
  "variables": [
    { "name": "score", "type": "int", "default": 0 }
  ],
  "nodes": [
    {
      "id": 0,
      "type": "events/on_ready",
      "position": { "x": 100, "y": 100 },
      "properties": {}
    },
    {
      "id": 1,
      "type": "functions/print_node",
      "position": { "x": 400, "y": 100 },
      "properties": {}
    }
  ],
  "connections": [
    { "from_node": 0, "from_port": 0, "to_node": 1, "to_port": 0 }
  ]
}
```

### Block Script format

```json
{
  "version": "1.0.0",
  "type": "block_script",
  "variables": [],
  "stacks": [
    {
      "blocks": [
        { "id": 0, "type": "events/on_ready", "properties": {} },
        {
          "id": 1,
          "type": "functions/print_node",
          "properties": { "value": "\"Hello World\"" }
        }
      ]
    }
  ]
}
```

---

## Addon / Extension API

Visual Coder has a first-class addon system that lets you add **custom nodes**, **custom blocks**, and **custom code generators** from any other Godot plugin.

### Step 1 — Create your addon class

```gdscript
# my_vc_addon.gd
@tool
class_name MyVCAddon
extends VCAddonBase

func get_addon_name() -> String:
    return "My Addon"

func get_addon_description() -> String:
    return "Adds custom nodes for my game systems."

# ── Add custom graph nodes ────────────────────────────────────────────────────

func get_node_types() -> Array[Dictionary]:
    return [
        NodeDefinitions.make_def(
            "my_addon/spawn_enemy",        # unique type id
            "Spawn Enemy",                  # display title
            "My Addon",                     # palette category
            Color(0.8, 0.2, 0.2),           # header color
            # inputs: exec, position
            [
                {"name": "▶",        "type": NodeDefinitions.T_EXEC,    "color": Color.WHITE},
                {"name": "position", "type": NodeDefinitions.T_VECTOR2, "color": NodeDefinitions.port_color(NodeDefinitions.T_VECTOR2)}
            ],
            # outputs: exec
            [{"name": "▶", "type": NodeDefinitions.T_EXEC, "color": Color.WHITE}],
            # editable properties
            {"enemy_scene": "res://enemies/goblin.tscn"},
            # code generator id
            "my_addon_spawn_enemy"
        )
    ]

# ── Add custom block types ────────────────────────────────────────────────────

func get_block_types() -> Array[Dictionary]:
    return [
        BlockDefinitions.make_def(
            "my_addon/spawn_enemy_block",
            "Spawn Enemy at",
            "My Addon",
            Color(0.8, 0.2, 0.2),
            "statement",
            [
                BlockDefinitions._f("scene_var", "string", "enemy_scene"),
                BlockDefinitions._f("position",  "string", "Vector2.ZERO")
            ]
        )
    ]

# ── Custom code generation ────────────────────────────────────────────────────

func generate_node_code(node_data: Dictionary, get_input: Callable,
        _get_chain: Callable, _depth: int) -> String:
    if node_data.get("type") == "my_addon/spawn_enemy":
        var scene: String = node_data.get("properties", {}).get("enemy_scene", "")
        var pos: String = get_input.call(1)
        return (
            'var _enemy = load("%s").instantiate()\n'
            + '_enemy.position = %s\n'
            + 'add_child(_enemy)\n'
        ) % [scene, pos]
    return ""

func generate_block_code(block_data: Dictionary, _gi: Callable,
        _gn: Callable, _depth: int) -> String:
    if block_data.get("type") == "my_addon/spawn_enemy_block":
        var sv: String = block_data.get("properties", {}).get("scene_var", "enemy_scene")
        var pos: String = block_data.get("properties", {}).get("position", "Vector2.ZERO")
        return (
            'var _enemy = %s.instantiate()\n'
            + '_enemy.position = %s\n'
            + 'add_child(_enemy)\n'
        ) % [sv, pos]
    return ""
```

### Step 2 — Register in your plugin

```gdscript
# my_plugin.gd
@tool
extends EditorPlugin

var _vc_addon: MyVCAddon

func _enter_tree() -> void:
    _vc_addon = MyVCAddon.new()
    AddonRegistry.instance().register(_vc_addon)

func _exit_tree() -> void:
    AddonRegistry.instance().unregister(_vc_addon)
```

That's it! Your custom nodes and blocks will appear in the Visual Coder palette immediately (no restart required).

---

## Architecture Overview

```
addons/visual_coder/
├── plugin.gd                        Main EditorPlugin entry point
├── plugin.cfg                       Plugin metadata
│
├── editor/
│   ├── main_editor.gd               Top-level UI (toolbar, tabs, status bar)
│   ├── node_graph/
│   │   ├── node_graph_editor.gd     GraphEdit-based canvas + palette
│   │   ├── vc_graph_node.gd         Individual GraphNode implementation
│   │   └── node_definitions.gd      Catalog of all built-in node types
│   └── block_editor/
│       ├── block_editor.gd          Scratch-style canvas + palette
│       ├── block_item.gd            Individual block widget
│       └── block_definitions.gd     Catalog of all built-in block types
│
├── code_gen/
│   ├── node_code_generator.gd       Graph → GDScript compiler
│   └── block_code_generator.gd      Blocks → GDScript compiler
│
├── data/
│   └── vc_resource.gd               .vcr file serialization
│
├── addon_api/
│   ├── vc_addon_base.gd             Base class for all VC addons
│   └── addon_registry.gd            Runtime registry of active addons
│
└── examples/
    └── example_addon.gd             Annotated addon example
```

---

## Platform Support

Visual Coder is written entirely in GDScript and has no native binaries.
It works on any platform Godot 4.6 supports.
The plugin itself (editor tooling) runs on **Windows**, **Linux**, and **macOS**.
Generated scripts run on all Godot export targets including mobile and web.

---

## Limitations & Known Issues

- **Cyclic graphs** in the Node Graph editor are not detected — avoid connecting nodes in a loop as this will cause infinite recursion during code generation.
- The Block Editor does not support **drag-to-reorder** between stacks yet; use the delete button and re-add blocks.
- "Raw GDScript" nodes/blocks bypass type checking — use with care.
- Very large graphs (500+ nodes) may have performance implications in the editor; the canvas uses Godot's built-in `GraphEdit` which is not designed for massive graphs.

---

## Contributing & Extending

Contributions are welcome! To report a bug or request a feature, open an issue on the repository.

To create a distributable VC addon plugin:
1. Create a standard Godot 4 addon.
2. Depend on Visual Coder being installed.
3. Implement `VCAddonBase` and register with `AddonRegistry`.
4. Publish on the Godot Asset Library.

---

## License

MIT License — see `LICENSE` for details.
