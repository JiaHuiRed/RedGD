# get_editor_logs 增强计划 — 捕获 Godot 输出面板日志

**日期**: 2026-05-14
**状态**: 方案A已实现
**目标**: 让 `get_editor_logs` 工具能够获取 Godot 编辑器输出面板上的 `print()` 输出和编译报错

---

## 1. 问题分析

当前 `get_editor_logs` 支持两个 source：

| source | 数据来源 | 覆盖范围 |
|--------|---------|---------|
| `"mcp"` (默认) | `_log_buffer` 内存缓存 | 仅 MCP 服务器自身工具调用日志 |
| `"runtime"` | `user://logs/godot.log` 文件 | 仅运行时日志（全量读取，无类型区分） |

**缺失的关键场景**：
- 编辑器静默状态下的 `print()` 输出
- 脚本解析/编译错误
- 资源加载警告
- `push_error()`/`push_warning()` 输出

---

## 2. 已有基础设施

### 2.1 输出面板定位代码（已有）

`clear_output` 工具（`debug_tools_native.gd` 行 3326-3336）已实现面板定位：

```gdscript
var editor_interface = _get_editor_interface()
var base_control = editor_interface.get_base_control()
var log_panel = base_control.find_child("*Output*", true, false)
var rich_text = _find_rich_text_label(log_panel)
```

### 2.2 EngineDebugger Capture（已有）

`MCPDebuggerBridge._capture_prefixes` 已包含 `"output"` 和 `"error"`，调试运行时 stdout/stderr 会被缓存到 `_captured_messages`。

### 2.3 ScriptEditorDebugger.output 信号（已有）

Bridge 已连接 `debugger.output` 信号，将运行时输出缓存到 `_output_events`（含 stdout/stderr/stdout_rich 分类）。

---

## 3. 增强方案

### 方案A：EditorInterface 面板读取（首选）

**新增 source**: `"editor_panel"`

**原理**: 复用 `clear_output` 的面板定位逻辑，通过 `RichTextLabel.get_text()` 获取输出面板内容。

**实现步骤**:
1. 在 `_tool_get_editor_logs` 中新增 `"editor_panel"` source 分支
2. 实现 `_get_editor_panel_logs(types, count, offset, order)` 方法
3. 复用面板定位代码找到 `RichTextLabel`
4. 调用 `get_text()` 获取富文本
5. 解析 BBCode 标签提取纯文本
6. 根据颜色标签推断日志级别（Error/Warning/Info）
7. 按行分割、分页、排序返回

**优点**:
- 唯一能获取编辑器静默状态下所有输出的方案
- 项目已有面板定位代码可复用
- 与用户在输出面板中看到的内容完全一致

**缺点**:
- 依赖内部控件结构（`find_child("*Output*")` 是启发式方法）
- `get_text()` 返回 BBCode 富文本需解析
- 全量读取，面板内容很大时有性能风险
- 非线程安全，必须主线程访问

**实现复杂度**: 中（约 80-120 行改动）

### 方案B：EngineDebugger Capture 补充（次选）

**新增 source**: `"debugger_output"`

**原理**: 直接复用 `bridge.get_output_events()` 中的已缓存数据。

**实现步骤**:
1. 在 `_tool_get_editor_logs` 中新增 `"debugger_output"` source 分支
2. 调用 `bridge.get_output_events(count, offset, order, category)`

**优点**: 数据已在 bridge 缓存，零新增捕获逻辑；输出已分类为 stdout/stderr

**缺点**: 仅在有调试会话运行时才有数据；与 `get_debug_output` 工具功能部分重复

**实现复杂度**: 极低（约 10-15 行改动）

### 方案C：runtime source 增强（未来优化）

**原理**: 改进现有 `"runtime"` source，从全量读取改为增量文件监听。

**改进点**:
- 增量读取 `godot.log`（记录文件偏移量，只读新增部分）
- 解析日志行识别 Error/Warning 级别（匹配 `ERROR:`、`WARNING:` 前缀）
- Timer 定期轮询文件变化

**实现复杂度**: 中高（约 120-180 行改动）

---

## 4. 推荐实现顺序

| 阶段 | 方案 | 新增 source | 优先级 |
|------|------|------------|--------|
| P1 | 方案B：EngineDebugger Capture | `"debugger_output"` | 高（改动极小，立即可用） |
| P2 | 方案A：EditorInterface 面板 | `"editor_panel"` | 高（核心需求） |
| P3 | 方案C：runtime 增强 | 改进 `"runtime"` | 中（性能优化） |

---

## 5. 实现细节

### 5.1 方案B：debugger_output source

```gdscript
# 在 _tool_get_editor_logs 中新增分支
if source == "debugger_output":
    var bridge = _get_debugger_bridge()
    if not bridge:
        return {"error": "Debugger bridge is not available"}
    return bridge.get_output_events(count, offset, order, str(params.get("category", "")))
```

**输入 schema 新增**:
```json
{
  "source": {
    "type": "string",
    "enum": ["mcp", "runtime", "editor_panel", "debugger_output"],
    "default": "mcp"
  }
}
```

### 5.2 方案A：editor_panel source

```gdscript
func _get_editor_panel_logs(types: Array, count: int, offset: int, order: String) -> Dictionary:
    var editor_interface = _get_editor_interface()
    if not editor_interface:
        return {"error": "Editor interface not available"}
    var base_control = editor_interface.get_base_control()
    if not base_control:
        return {"error": "Could not get base control"}
    var log_panel = base_control.find_child("*Output*", true, false)
    if not log_panel:
        return {"error": "Output panel not found"}
    var rich_text = _find_rich_text_label(log_panel)
    if not rich_text:
        return {"error": "RichTextLabel not found in output panel"}
    var raw_text: String = rich_text.get_text()
    # 解析 BBCode → 纯文本行 + 级别推断
    var lines = _parse_editor_output(raw_text)
    # 分页、排序
    # ...
```

**BBCode 解析逻辑**:
- `[color=#ff]...[/color]` → 根据颜色推断级别（红色=Error，黄色=Warning，其他=Info）
- 移除所有 BBCode 标签得到纯文本
- 按换行符分割为日志行数组

**性能保护**:
- 限制最大读取行数（如 10000 行）
- 面板文本超过阈值时返回最新 N 行

### 5.3 方案C：runtime 增量读取

```gdscript
var _runtime_log_offset: int = 0
var _runtime_log_buffer: Array[Dictionary] = []

func _poll_runtime_log() -> void:
    var log_path = "user://logs/godot.log"
    if not FileAccess.file_exists(log_path):
        return
    var file = FileAccess.open(log_path, FileAccess.READ)
    if not file:
        return
    file.seek(_runtime_log_offset)
    while not file.eof_reached():
        var line = file.get_line()
        if not line.is_empty():
            _runtime_log_buffer.append(_parse_runtime_log_line(line))
    _runtime_log_offset = file.get_position()
    file.close()
```

---

## 6. 测试计划

| 测试项 | 方案 |
|--------|------|
| `get_editor_logs(source="editor_panel")` 基本功能 | 方案A |
| editor_panel 返回类型区分 Error/Warning/Info | 方案A |
| editor_panel 在无编辑器界面时的降级处理 | 方案A |
| `get_editor_logs(source="debugger_output")` 基本功能 | 方案B |
| debugger_output 在无调试会话时的空返回 | 方案B |
| debugger_output category 过滤 | 方案B |
| runtime 增量读取正确性 | 方案C |
| runtime 日志级别解析 | 方案C |

---

## 7. 风险评估

| 风险 | 影响 | 缓解措施 |
|------|------|----------|
| `find_child("*Output*")` 在 Godot 未来版本失效 | 方案A 失效 | 添加版本检测，降级返回错误信息 |
| `RichTextLabel.get_text()` 返回格式变化 | 解析失败 | 添加格式校验，降级返回原始文本 |
| 面板文本过大导致性能问题 | 读取延迟 | 限制最大读取行数 |
| 并发访问 UI 控件 | 崩溃 | 确保主线程访问（call_deferred） |
