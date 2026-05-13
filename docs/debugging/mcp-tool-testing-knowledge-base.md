# 154 工具 MCP 测试知识库

**最终更新：** 2026-05-13
**Godot 版本：** 4.6.1.stable
**项目：** Godot-MCP-Native
**最终结果：** 154/154 = 100% 通过

---

## 1. 测试环境要求

### 1.1 基础环境

| 依赖 | 版本/说明 |
|------|-----------|
| Godot Engine | 4.6.1.stable（**不支持 4.3 以下版本**，因 TileMap API 变更） |
| MCP 模式 | HTTP 模式（localhost:9080），非 STDIO |
| 编辑器 | 需在 Godot 编辑器中运行（非纯 headless），部分工具依赖 EditorInterface |
| 运行时 | 需启动游戏进程（F5），Debug-Advanced Runtime 工具依赖 MCPRuntimeProbe |

### 1.2 工具启用

MCP 工具分两类，默认只启用 core（30 个）：
- **core**：默认启用，基础操作
- **supplementary**：需手动在 Tool Manager 面板启用，或通过 `user://mcp_tool_state.cfg` 持久化

启用方式：在编辑器 MCP Panel → Tool Manager 标签页中勾选对应分组。

### 1.3 测试场景

| 场景文件 | 用途 | 内容 |
|---------|------|------|
| `res://TestScene.tscn` | 基础测试 | Node3D 根节点（Core + 补充工具） |
| `res://test/MCPComprehensiveTest.tscn` | 综合测试 | Node3D + AnimationPlayer + AnimationTree + Control + MeshInstance3D(Standard) + MeshInstance3D(Shader) + TileMap |

综合测试场景搭建代码（通过 `execute_editor_script`）：
```gdscript
# 创建 AnimationPlayer + AnimationLibrary
var ap = AnimationPlayer.new()
ap.name = "AnimPlayer"
var lib = AnimationLibrary.new()
lib.name = "test_lib"
var anim = Animation.new()
anim.length = 1.0
anim.track_insert_key(anim.add_track(Animation.TYPE_VALUE), 0.0, Vector3.ZERO)
lib.add_animation("test_anim", anim)
ap.add_animation_library("test_lib", lib)

# 创建 AnimationTree + AnimationNodeStateMachine
var at = AnimationTree.new()
at.name = "AnimTree"
at.anim_player = ap.get_path()
var sm = AnimationNodeStateMachine.new()
var idle = AnimationNodeAnimation.new()
idle.animation = "test_lib/test_anim"
sm.add_node("idle", idle)  # 第一个添加的节点自动成为 Start 节点
at.tree_root = sm
# 注意：tree_root 必须在编辑器上下文设置，脚本设置不会被持久化到 .tscn

# 创建 Control（Theme 工具）
var ctrl = Control.new()
ctrl.name = "ControlNode"
ctrl.size = Vector2(200, 200)

# 创建 MeshInstance3D + StandardMaterial3D
var mesh = MeshInstance3D.new()
mesh.name = "MeshInstance"
mesh.mesh = BoxMesh.new()
mesh.material_override = StandardMaterial3D.new()
mesh.material_override.albedo_color = Color.RED

# 创建 MeshInstance3D + ShaderMaterial
var shader_mesh = MeshInstance3D.new()
shader_mesh.name = "ShaderMesh"
shader_mesh.mesh = BoxMesh.new()
var shader_mat = ShaderMaterial.new()
# 需设置 shader 代码含 uniform vec4 albedo
shader_mesh.material_override = shader_mat

# 创建旧式 TileMap（不是 TileMapLayer！）
var tilemap = TileMap.new()  # Godot 4.0-4.2 旧式节点
tilemap.name = "TileMapNode"
var tileset = TileSet.new()
tileset.tile_size = Vector2i(16, 16)
# 添加 TileSetAtlasSource 并设置 cell
tilemap.tile_set = tileset
```

---

## 2. 工具分组与测试参数

### 2.1 Core（30 个）— 默认启用

#### Node-Write（6 个）

| 工具 | 必需参数 | 测试参数 | 注意 |
|------|---------|---------|------|
| create_node | parent_path, node_type, node_name | `/root/Node3D`, `Node3D`, `TestNode` | — |
| update_node_property | node_path, property_name, property_value | `/root/Node3D/TestNode`, `position`, `(1,2,3)` | value 类型需匹配属性 |
| duplicate_node | node_path | `/root/Node3D/TestNode` | new_name 可选 |
| move_node | node_path, new_parent_path | 同上 | keep_global_transform 可选 |
| rename_node | node_path, new_name | 同上 | — |
| delete_node | node_path | 同上 | **destructiveHint=true** |

#### Node-Read（3 个）

| 工具 | 必需参数 | 测试参数 | 注意 |
|------|---------|---------|------|
| get_inspector_properties | node_path 或 resource_path | `/root/Node3D` | 可选 property_filter |
| select_node | node_path | `/root/Node3D` | allow_ui_focus 可选 |
| get_scene_tree | 无 | — | — |

#### Script（7 个）

| 工具 | 必需参数 | 测试参数 | 注意 |
|------|---------|---------|------|
| list_project_scripts | 无 | — | — |
| read_script | script_path | `res://main.gd` | — |
| search_in_scripts | pattern | `func _ready` | 支持正则 |
| get_script_symbols | script_path | 同上 | — |
| get_script_references | script_path | 同上 | — |
| get_class_api_metadata | class_name | `Node3D` | filter 可选 |
| execute_script | code | `1 + 1` | 仅支持表达式，非多行脚本 |

#### Scene（4 个）

| 工具 | 必需参数 | 测试参数 | 注意 |
|------|---------|---------|------|
| open_scene | scene_path | `res://TestScene.tscn` | allow_ui_focus 可选（Vibe Coding 模式需 true） |
| save_scene | 无 | — | file_path 可选 |
| create_scene | scene_path | `res://test/New.tscn` | root_node_type 可选，默认 Node |
| get_selected_nodes | 无 | — | — |

#### Editor（5 个）

| 工具 | 必需参数 | 测试参数 | 注意 |
|------|---------|---------|------|
| get_editor_screenshot | 无 | — | viewport_type/format/save_path 可选 |
| set_editor_setting | setting_name, setting_value | `interface/theme/accent_color`, `#FF0000` | — |
| execute_editor_script | code | 多行 GDScript | extends RefCounted，用 `edited_scene` 访问场景，`_custom_print()` 输出 |
| get_signals | node_path | `/root/Node3D` | include_connections 可选 |
| reload_project | 无 | — | full_scan 可选 |

#### Project（5 个）

| 工具 | 必需参数 | 测试参数 | 注意 |
|------|---------|---------|------|
| get_resource_uid_info | resource_path 或 uid | `res://icon.png` | 二选一 |
| get_resource_dependencies | resource_path | 同上 | — |
| fix_resource_uid | resource_path | 同上 | — |
| reimport_resources | resource_paths | `["res://icon.png"]` | 数组参数 |
| get_import_metadata | resource_path | 同上 | — |

### 2.2 Node-Write-Advanced（5 个）

| 工具 | 必需参数 | 注意 |
|------|---------|------|
| batch_update_node_properties | updates（数组） | 批量更新多个节点属性 |
| batch_create_nodes | nodes（数组） | 批量创建节点 |
| create_runtime_node | parent_path, node_type, node_name | **需运行时** |
| delete_runtime_node | node_path | **需运行时**，保护根节点和 MCPRuntimeProbe |
| update_runtime_node_property | node_path, property_name, property_value | **需运行时** |

### 2.3 Node-Advanced（6 个）

| 工具 | 必需参数 | 注意 |
|------|---------|------|
| call_runtime_node_method | node_path, method_name | **需运行时**，arguments 可选 |
| get_inspector_properties | node_path/resource_path | 与 core 版相同，但支持 resource_path |
| select_file | file_path | 在 FileSystem dock 中选中文件 |
| get_performance_metrics | 无 | 编辑器端性能 |
| inspect_csharp_project_support | 无 | 检查 C#/Mono 支持 |
| get_project_structure | max_depth(可选) | 项目目录结构 |

### 2.4 Script-Advanced（8 个）

| 工具 | 必需参数 | 注意 |
|------|---------|------|
| batch_search_in_scripts | searches（数组） | 批量搜索 |
| find_script_references | script_path | 反向引用 |
| rename_script_symbol | script_path, old_name, new_name | 重命名符号 |
| detect_broken_scripts | 无 | include_warnings/max_results/search_path 可选 |
| scan_missing_resource_dependencies | 无 | 检测缺失依赖 |
| scan_cyclic_resource_dependencies | 无 | 检测循环依赖 |
| audit_project_health | 无 | 综合项目健康检查 |
| get_project_global_classes | filter(可选) | 项目全局类列表 |

### 2.5 Scene-Advanced（4 个）

| 工具 | 必需参数 | 注意 |
|------|---------|------|
| list_project_input_actions | action_name(可选) | ProjectSettings InputMap |
| upsert_project_input_action | action_name | 创建/更新 InputMap action，会保存 project.godot |
| remove_project_input_action | action_name | 删除，会保存 project.godot |
| list_project_autoloads | filter(可选) | 项目 Autoload 列表 |

### 2.6 Editor-Advanced（12 个）

| 工具 | 必需参数 | 注意 |
|------|---------|------|
| compare_render_screenshots | baseline_path, candidate_path | 渲染回归比较 |
| inspect_tileset_resource | resource_path | TileSet 检查 |
| create_resource | resource_path, resource_type | 创建 .tres 资源 |
| list_export_presets | 无 | 导出预设列表 |
| inspect_export_templates | 无 | 导出模板检查 |
| validate_export_preset | preset | 预设验证 |
| run_export | preset | **同步阻塞**，mode/output_path 可选 |
| list_project_tests | search_path(可选) | 测试发现 |
| run_project_test | test_path | **同步阻塞**，执行单个测试 |
| run_project_tests | search_path(可选) | **同步阻塞**，批量执行测试 |
| add_debugger_capture_prefix | prefix | 添加 debugger 消息捕获前缀 |
| get_debug_output | count/offset/order/category | 读取调试输出 |

### 2.7 Project-Advanced（23 个）

与 Editor-Advanced 部分重叠，额外包含：
- 输入映射工具（list/upsert/remove_project_input_action）
- 项目元数据（list_project_autoloads, list_project_global_classes）
- 测试框架（list/run_project_test(s)）

### 2.8 Debug-Advanced（66 个）— 需运行时 + MCPRuntimeProbe

#### Debugger 会话管理（14 个）

| 工具 | 注意 |
|------|------|
| get_debugger_sessions | 返回会话列表 |
| get_debug_threads | DAP 风格线程 |
| set_debugger_breakpoint | path, line, enabled |
| send_debugger_message | 原始消息 |
| toggle_debugger_profiler | profiler, enabled |
| get_debugger_messages | 已捕获消息 |
| get_debug_state_events | break/resume/stop 状态 |
| get_debug_output | stdout/stderr |
| add_debugger_capture_prefix | 自定义前缀 |
| get_debug_stack_frames | 需 breaked 状态 |
| get_debug_stack_variables | 需 breaked 状态 |
| get_debug_scopes | 需 breaked 状态 |
| get_debug_variables | variables_reference > 0 |
| expand_debug_variable | scope + variable_path |

#### Debugger 执行控制（8 个）

| 工具 | 注意 |
|------|------|
| request_debug_break | 请求进入 break 循环 |
| send_debug_command | step/next/out/continue/get_stack_dump/get_stack_frame_vars |
| debug_step_into | 单步进入 |
| debug_step_over | 单步跳过 |
| debug_step_out | 跳出当前帧 |
| debug_continue | 继续执行 |
| debug_step_into_and_wait | 等待 breaked 状态 |
| await_debugger_state | 轮询目标状态 |

#### 运行时信息（3 个）

| 工具 | 注意 |
|------|------|
| get_runtime_info | FPS、节点数等 |
| get_runtime_performance_snapshot | 帧时间、内存 |
| get_runtime_memory_trend | 多采样内存趋势 |

#### 运行时场景树（4 个）

| 工具 | 注意 |
|------|------|
| get_runtime_scene_tree | 运行时场景树 |
| inspect_runtime_node | 运行时节点属性 |
| create_runtime_node | 运行时创建节点 |
| delete_runtime_node | 运行时删除节点 |

#### 运行时节点操作（2 个）

| 工具 | 注意 |
|------|------|
| update_runtime_node_property | 修改运行时属性 |
| call_runtime_node_method | 调用运行时方法 |

#### 运行时表达式求值（1 个）

| 工具 | 注意 |
|------|------|
| evaluate_runtime_expression | expression + 可选 node_path |

#### 运行时输入（6 个）

| 工具 | 注意 |
|------|------|
| simulate_runtime_input_event | 结构化输入事件（key/mouse_button/mouse_motion/action） |
| simulate_runtime_input_action | InputEventAction |
| list_runtime_input_actions | 运行时 InputMap |
| upsert_runtime_input_action | 运行时创建/更新 action |
| remove_runtime_input_action | 运行时删除 action |
| install_runtime_probe | 安装 MCP 运行时探针（通常已自动安装） |

#### 运行时动画（7 个）

| 工具 | 必需参数 | 注意 |
|------|---------|------|
| list_runtime_animations | node_path | AnimationPlayer 节点路径 |
| play_runtime_animation | node_path, animation_name | 可选 custom_blend/speed/from_end |
| stop_runtime_animation | node_path | 可选 keep_state |
| get_runtime_animation_state | node_path | 返回当前播放状态 |
| get_runtime_animation_tree_state | node_path | **需 AnimTree 配置 tree_root** |
| set_runtime_animation_tree_active | node_path, active | 同上 |
| travel_runtime_animation_tree | node_path, state_name | 同上，travel 是异步的 |

#### 运行时视觉（9 个）

| 工具 | 必需参数 | 注意 |
|------|---------|------|
| get_runtime_material_state | node_path | material_target/surface_index 可选 |
| get_runtime_theme_item | node_path, item_type, item_name | item_type: color/constant/font/font_size/stylebox/icon |
| set_runtime_theme_override | node_path, item_type, item_name, value | — |
| clear_runtime_theme_override | node_path, item_type, item_name | — |
| get_runtime_shader_parameters | node_path | ShaderMaterial 专用 |
| set_runtime_shader_parameter | node_path, parameter_name, value | — |
| list_runtime_tilemap_layers | node_path | **需旧式 TileMap 节点** |
| get_runtime_tilemap_cell | node_path, layer, coords | 同上 |
| set_runtime_tilemap_cell | node_path, layer, coords | 同上，source_id/atlas_coords/alternative_tile 可选 |

#### 运行时音频（3 个）

| 工具 | 注意 |
|------|------|
| list_runtime_audio_buses | AudioServer 总线列表 |
| get_runtime_audio_bus | bus_name |
| update_runtime_audio_bus | bus_name, 可选 mute/volume_db |

#### 运行时截图（1 个）

| 工具 | 注意 |
|------|------|
| get_runtime_screenshot | save_path, format/viewport_path 可选 |

#### 运行时断言/等待（3 个）

| 工具 | 注意 |
|------|------|
| await_runtime_condition | expression, 轮询直到 truthy |
| assert_runtime_condition | expression, 超时则失败 |
| remove_runtime_probe | 移除 MCPRuntimeProbe |

#### 运行时 AnimationTree 等待（4 个）

| 工具 | 注意 |
|------|------|
| debug_step_over_and_wait | step_over + 等待 breaked |
| debug_step_out_and_wait | step_out + 等待 breaked |
| debug_continue_and_wait | continue + 等待 running |
| get_runtime_animation_tree_state | 同上动画部分 |

---

## 3. 遇到的问题与解决方案

### 3.1 Bug 修复

#### Bug 1：`float()` 构造函数不存在

- **文件**：`addons/godot_mcp/runtime/mcp_runtime_probe.gd`
- **行号**：1037-1039, 1048, 1050（`_serialize_animation_tree_state` 函数）
- **问题**：`float(value)` 在 Godot 4.6 中报错 `Invalid call. Nonexistent 'float' constructor`
- **原因**：Godot 4.6 不支持 `float()` 作为类型转换构造函数
- **修复**：5 处 `float(...)` → `... as float`
- **影响**：AnimationTree 3 个工具（get/set/travel_runtime_animation_tree）全部返回 pending 或空数据
- **发现方式**：通过 `get_debug_state_events` 看到 `"Invalid call. Nonexistent 'float' constructor"` 错误

#### Bug 2：`travel_runtime_animation_tree` 的 match_fields 过滤

- **文件**：`addons/godot_mcp/tools/debug_tools_native.gd`
- **行号**：2215
- **问题**：`match_fields: {"node_path": node_path, "current_node": state_name}` 导致响应被跳过
- **原因**：travel 操作是异步的，响应中 `current_node` 可能尚未更新到目标状态（仍为 "Start" 或旧状态）
- **修复**：移除 `match_fields` 中的 `"current_node": state_name`，只保留 `{"node_path": node_path}`
- **影响**：`travel_runtime_animation_tree` 持续返回 pending

### 3.2 Godot 版本兼容性问题

#### TileMap vs TileMapLayer

| Godot 版本 | TileMap 节点 | 支持 |
|------------|-------------|------|
| 3.x | TileMap | ✅ 完全支持 |
| 4.0-4.2 | TileMap | ✅ 完全支持 |
| 4.3+ | TileMapLayer（新）+ TileMap（兼容） | ⚠️ Runtime Probe 只支持旧式 TileMap |

- **问题**：Runtime Probe 的 `_resolve_tilemap` 强制要求节点是 `TileMap` 类型
- **解决**：测试时使用旧式 `TileMap` 节点而非 `TileMapLayer`
- **影响工具**：list_runtime_tilemap_layers, get_runtime_tilemap_cell, set_runtime_tilemap_cell

#### AnimationNodeStateMachine API 变更

| 方法 | Godot 3.x | Godot 4.x |
|------|-----------|-----------|
| `set_start_node(name)` | ✅ 存在 | ❌ 不存在 |
| `add_node(name, node)` | ✅ | ✅ 第一个添加的节点自动成为 Start |

- **问题**：调用 `set_start_node()` 报错 `Invalid call. Nonexistent function 'set_start_node'`
- **解决**：使用 `add_node()` 添加节点，第一个节点自动成为起始节点
- **注意**：AnimationNodeStateMachine 自动添加 "Start" 和 "End" 节点

### 3.3 Runtime Probe 通信机制

#### 消息流

```
MCP 工具 → debug_tools_native._request_runtime_probe()
  → bridge.send_debugger_message("mcp:command", payload)
  → [运行时] MCPRuntimeProbe._capture_mcp_message()
  → [运行时] 处理命令，生成结果
  → [运行时] EngineDebugger.send_message("mcp:response", [result])
  → bridge._capture() 捕获响应
  → _extract_pending_runtime_probe_response() 提取结果
```

#### pending 机制

1. 首次调用：发送 debugger 消息，创建 pending 缓存条目，返回 `status: pending`
2. 后续调用：检查 pending 缓存是否过期，如未过期尝试从 bridge 提取已捕获的响应
3. 响应提取：`get_captured_message_after_sequence(baseline_sequence, response_messages, error_messages, match_fields)`
4. **关键**：`match_fields` 会过滤响应，字段必须与实际响应数据匹配

#### 首次调用 pending 的处理

多数 Runtime 工具首次调用返回 pending（因为响应还未到达 bridge），**第二次调用通常能提取到结果**。这是设计行为而非 bug。

### 3.4 execute_editor_script 限制

- 脚本被包裹在 `extends RefCounted` 类中，**不是** Node 或 EditorScript
- **不能**使用 `get_tree()`（RefCounted 无此方法）
- 用 `edited_scene` 变量访问当前编辑场景根节点
- 用 `_custom_print(msg)` 代替 `print()` 输出（print 不会被捕获）
- 代码中的 `if/for/while` 块必须使用 **tab 缩进**
- 不支持 `class_name`、`@tool`、`await`

### 3.5 AnimationTree.tree_root 持久化

- **问题**：通过 `execute_editor_script` 设置 `AnimationTree.tree_root = AnimationNodeStateMachine.new()` 不会被 Godot 保存到 .tscn 文件
- **原因**：Godot 引擎的序列化机制——通过脚本设置的 Resource 子对象需要正确的 owner/路径才能持久化
- **解决**：在 `execute_editor_script` 中设置 tree_root 后调用 `save_scene()`，Godot 4.6 能正确保存
- **替代**：在编辑器 Inspector 中手动配置 AnimationNodeStateMachine

### 3.6 同步阻塞工具

| 工具 | 阻塞时间 | 原因 |
|------|---------|------|
| run_project_test | ~10-30秒（GUT）/ ~200ms（Python） | `OS.execute()` 同步执行子进程 |
| run_project_tests | 同上 | 批量执行 |
| run_export | ~5-30秒 | 同步执行导出 |

- MCP 客户端需设置较长超时（≥60秒）
- 执行期间编辑器主线程冻结，无法响应其他 MCP 请求

---

## 4. 测试所需前置条件

### 4.1 按工具类别

| 工具类别 | 前置条件 | 搭建方式 |
|---------|---------|---------|
| Core (30) | 打开任意场景 | open_scene |
| Supplementary 非运行时 (35) | 打开任意场景 | open_scene |
| Debug-Advanced Editor-Only (14) | 无需运行时 | — |
| Debug-Advanced Runtime (49) | **运行游戏 + MCPRuntimeProbe** | F5 启动游戏 |
| AnimationPlayer (4) | 场景含 AnimationPlayer + AnimationLibrary | execute_editor_script |
| AnimationTree (3) | 场景含 AnimationTree + 配置 tree_root | execute_editor_script（见 3.5） |
| Material/Theme (4) | 场景含 Control + MeshInstance3D | execute_editor_script |
| Shader (2) | 场景含 ShaderMaterial + shader 代码含 uniform | execute_editor_script |
| TileMap (3) | 场景含**旧式 TileMap** + TileSet | execute_editor_script（不可用 TileMapLayer） |
| evaluate_debug_expression | **debugger 处于 breaked 状态** | request_debug_break 或设断点 |

### 4.2 MCPRuntimeProbe 安装

```gdscript
# 通过 MCP 工具安装
install_runtime_probe()

# 或手动添加
var probe = MCPRuntimeProbe.new()
probe.name = "MCPRuntimeProbe"
scene_root.add_child(probe)
probe.owner = scene_root  # 使其随场景保存
```

---

## 5. _request_runtime_probe 详解

### 5.1 参数

| 参数 | 说明 |
|------|------|
| command | Runtime Probe 命令名（如 "get_animation_tree_state"） |
| payload | 命令参数数组（如 [node_path]） |
| response_messages | 期望的响应消息名（如 ["mcp:animation_tree_state"]） |
| params | MCP 工具原始参数（含 session_id, timeout_ms） |
| match_fields | 响应过滤字段（如 {"node_path": "/root/Scene/Node"}） |

### 5.2 match_fields 使用规则

- **必须**包含 `node_path`（确保响应来自目标节点）
- **不要**包含可能在响应时还未更新的字段（如 travel 后的 `current_node`）
- 常见 match_fields：
  - 动画工具：`{"node_path": node_path}`
  - TileMap 工具：`{"node_path": node_path}`
  - Audio 工具：无 match_fields

### 5.3 常见 pending 原因

| 原因 | 解决 |
|------|------|
| 首次调用（响应未到达） | 再次调用同一工具 |
| match_fields 不匹配 | 检查响应数据，调整 match_fields |
| Runtime Probe 未安装 | install_runtime_probe() |
| 游戏未运行 | F5 启动游戏 |
| float() 构造函数错误 | 改为 `as float`（已修复） |
| AnimationTree 未配置 tree_root | 通过 execute_editor_script 设置 |

---

## 6. Godot 版本兼容性矩阵

| 特性 | Godot 3.x | Godot 4.0-4.2 | Godot 4.3 | Godot 4.4-4.6 |
|------|-----------|---------------|-----------|---------------|
| TileMap 节点 | TileMap | TileMap | TileMap + TileMapLayer | TileMap + TileMapLayer |
| Runtime Probe TileMap | ✅ | ✅ | ✅ (旧式) | ✅ (旧式) |
| Runtime Probe TileMapLayer | ❌ | ❌ | ❌ | ❌ |
| AnimationNodeStateMachine | ✅ | ✅ | ✅ | ✅ |
| set_start_node() | ✅ | ❌ | ❌ | ❌ |
| add_node() | ✅ | ✅ | ✅ | ✅ |
| float() 构造函数 | ✅ | ✅ | ✅ | ❌ (4.6 起) |
| `as float` 类型转换 | ❌ | ✅ | ✅ | ✅ |
| AnimationLibrary | ❌ | ✅ | ✅ | ✅ |
| EngineDebugger | ❌ | ✅ | ✅ | ✅ |

---

## 7. 测试技巧

### 7.1 验证 Runtime 工具的步骤

1. 确保游戏正在运行（`get_runtime_info` 返回 success）
2. 确保场景包含所需节点类型
3. 首次调用可能返回 pending，**再调用一次**
4. 如果持续 pending：
   - 检查 `get_debug_state_events` 是否有错误
   - 检查 `get_debugger_messages` 是否捕获到了响应
   - 检查响应数据是否与 match_fields 匹配

### 7.2 排查 AnimationTree 问题

1. 确认 AnimTree 的 tree_root 不为 null（`get_inspector_properties`）
2. 确认 playback 可用（`anim_tree.get("parameters/playback")` 不为 null）
3. 确认无 float() 构造函数错误（`get_debug_state_events`）
4. 如 tree_root 为 null，通过 `execute_editor_script` 设置：
   ```gdscript
   var sm = AnimationNodeStateMachine.new()
   var idle = AnimationNodeAnimation.new()
   idle.animation = "your_animation_name"
   sm.add_node("idle", idle)
   at.tree_root = sm
   at.active = true
   ```

### 7.3 排查 TileMap 问题

1. 确认节点类型是 `TileMap`（不是 `TileMapLayer`）
2. 确认 TileMap 有 TileSet（`tile_set` 不为 null）
3. 确认 TileSet 有至少一个 source
4. 如需创建旧式 TileMap：
   ```gdscript
   var tilemap = TileMap.new()  # 不是 TileMapLayer.new()！
   tilemap.tile_set = TileSet.new()
   ```

### 7.4 清理临时文件

CodeArts diff 会在 `.codeartsdoer/temp/` 生成 `.gd` 备份文件，被 Godot LSP 误扫描导致 `Class "XXX" hides a global script class` 错误。

- 项目已在三级目录放置 `.gdignore` 根治
- 手动清理：删除 `.codeartsdoer/temp/` 下所有 `.gd` 文件
- Python 集成测试会创建 `.tmp_*` 临时目录，测试后需清理

---

## 8. 参考文档

| 文档 | 路径 | 内容 |
|------|------|------|
| Core + 补充验证 | `docs/debugging/core-tools-mcp-verification-2026-05-12.md` | 30 核心 + 35 补充工具详细验证 |
| Project-Advanced 验证 | `docs/debugging/project-advanced-mcp-verification-2026-05-13.md` | 23 Project-Advanced 工具验证 |
| Debug-Advanced 验证 | `docs/debugging/debug-advanced-mcp-verification-2026-05-13.md` | 67 Debug-Advanced 工具验证 |
| 补充验证 | `docs/debugging/full-verification-supplement-2026-05-13.md` | 综合测试场景 + 最终汇总 |
| 本文档 | `docs/debugging/mcp-tool-testing-knowledge-base.md` | 测试知识库（本文档） |
