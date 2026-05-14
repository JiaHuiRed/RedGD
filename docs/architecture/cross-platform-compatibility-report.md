# 跨平台兼容性检测报告

**项目**: Godot-MCP-Native
**检查范围**: `addons/godot_mcp/` 目录下所有 `.gd` 文件
**检查日期**: 2026-05-14
**修复状态**: ✅ 高风险和中风险已全部修复

---

## 一、高风险发现（3 个）

### 1.1 [高] Windows 特定 Shell 命令 — `netstat` + `tasklist`

**文件**: `addons/godot_mcp/native_mcp/mcp_http_server.gd`
**行号**: 127, 143

```gdscript
# 行 127
var exit_code: int = OS.execute("netstat", ["-ano"], output)
# 行 143
var proc_exit: int = OS.execute("tasklist", ["/FI", "PID eq " + pid, "/FO", "CSV", "/NH"], proc_output)
```

**风险**: `netstat -ano` 是 Windows 专有语法，`tasklist` 是 Windows 专有命令。Linux/macOS 上不存在或参数不同。

**适配方案**: 根据平台选择不同命令：
```gdscript
var os_name: String = OS.get_name()
if os_name == "Windows":
    OS.execute("netstat", ["-ano"], output)
    # 解析 "LISTENING" 关键字
elif os_name == "Linux" or os_name == "FreeBSD":
    OS.execute("ss", ["-tlnp"], output)
    # 解析 "LISTEN" 关键字
elif os_name == "macOS":
    OS.execute("lsof", ["-i", ":" + str(port)], output)
    # 解析 lsof 输出
```

### 1.2 [高] Windows 特定环境变量 — `APPDATA`

**文件**: `addons/godot_mcp/tools/editor_tools_native.gd`
**行号**: 979

```gdscript
var templates_root: String = OS.get_environment("APPDATA").path_join("Godot").path_join("export_templates")
```

**风险**: `APPDATA` 是 Windows 专有环境变量。Linux 上为 `~/.local/share/godot/export_templates/`，macOS 上为 `~/Library/Application Support/Godot/export_templates/`。

**适配方案**: 使用 Godot 内置 `EditorPaths` API：
```gdscript
var editor_interface = _get_editor_interface()
if editor_interface:
    var editor_paths = editor_interface.get_editor_paths()
    templates_root = editor_paths.get_export_templates_dir()
else:
    # 回退：按平台手动构建路径
    var os_name = OS.get_name()
    if os_name == "Windows":
        templates_root = OS.get_environment("APPDATA").path_join("Godot").path_join("export_templates")
    elif os_name == "Linux" or os_name == "FreeBSD":
        templates_root = OS.get_environment("HOME").path_join(".local/share/godot/export_templates")
    elif os_name == "macOS":
        templates_root = OS.get_environment("HOME").path_join("Library/Application Support/Godot/export_templates")
```

### 1.3 [高] `python` 命令名 — Linux/macOS 通常为 `python3`

**文件**: `addons/godot_mcp/tools/project_tools_native.gd`
**行号**: 840

```gdscript
var exit_code: int = OS.execute("python", [absolute_test_path], logs, true)
```

**风险**: 许多 Linux 发行版默认不提供 `python` 命令，仅有 `python3`。

**适配方案**: 优先尝试 `python3`，回退到 `python`：
```gdscript
var python_cmd: String = "python3"
var test_output: Array = []
var test_exit: int = OS.execute(python_cmd, ["--version"], test_output, true)
if test_exit != 0:
    python_cmd = "python"
var exit_code: int = OS.execute(python_cmd, [absolute_test_path], logs, true)
```

---

## 二、中风险发现（4 个）

### 2.1 [中] 路径拼接使用 `+` 而非 `path_join()`

**文件 1**: `addons/godot_mcp/mcp_server_native.gd` 行 722, 726, 728
**文件 2**: `addons/godot_mcp/tools/resource_tools_native.gd` 行 222, 225, 227

```gdscript
var full_path: String = base_path + file_name
var sub_dir: DirAccess = DirAccess.open(full_path + "/")
_find_files_recursive(sub_dir, extension, result, full_path + "/")
```

**风险**: Godot 内部统一使用 `/`，在 `res://`/`user://` 虚拟路径中通常能工作，但不是最佳实践。

**适配方案**: 使用 `path_join()` 替代字符串拼接：
```gdscript
var full_path: String = base_path.path_join(file_name)
var sub_dir: DirAccess = DirAccess.open(full_path + "/")
_find_files_recursive(sub_dir, extension, result, full_path + "/")
```
> 注意：递归调用中尾部 `/` 需保留，以确保子目录路径拼接正确。

### 2.2 [中] path_validator 中硬编码 Windows 盘符

**文件**: `addons/godot_mcp/utils/path_validator.gd` 行 19-29

```gdscript
const DANGEROUS_PATTERNS := [
    "~", "\\\\", "C:\\", "/etc/", "/var/", "/tmp/",
    "D:\\", "E:\\", "F:\\"
]
```

**风险**: 缺少 macOS 特定路径（`/Users/`、`/Library/`、`/Applications/`），且缺少 A-Z 全盘符通用匹配。

**适配方案**: 补量添加更多模式：
```gdscript
const DANGEROUS_PATTERNS := [
    "~", "\\\\", "/etc/", "/var/", "/tmp/",
    "/Users/", "/Library/", "/Applications/",
    # Windows 盘符 A-Z（正则方式或逐个列举常用）
    "C:\\", "D:\\", "E:\\", "F:\\"
]
```

### 2.3 [中] 测试数据中的 Windows 路径

**文件**: `addons/godot_mcp/utils/path_validator.gd` 行 237

```gdscript
var test_paths: Array[String] = [
    "C:\\Windows\\System32",  # 行 237
]
```

**风险**: 这是安全测试用例（验证危险路径被拒绝），逻辑正确，无需修复。

### 2.4 [中] 日志文件轮转路径拼接

**文件**: `addons/godot_mcp/ui/mcp_panel_native.gd` 行 883-886

**风险**: 使用 `ProjectSettings.globalize_path()` 是正确的跨平台做法，低风险，无需修复。

---

## 三、低风险发现（6 个）

| # | 类别 | 文件 | 说明 |
|---|------|------|------|
| 1 | `OS.execute()` + `OS.get_executable_path()` | `editor_tools_native.gd` 行 915, `project_tools_native.gd` 行 871 | ✅ 使用 `OS.get_executable_path()` 获取 Godot 路径，跨平台兼容 |
| 2 | `DirAccess` / `FileAccess` | 多文件（60+ 处） | ✅ Godot 内置跨平台文件系统 API |
| 3 | `EngineDebugger` | `mcp_runtime_probe.gd`（80+ 处） | ✅ Godot 内置调试器 API，跨平台可用 |
| 4 | `EditorPlugin` / `EditorInterface` | 多文件 | ✅ Godot 编辑器插件标准 API，所有桌面平台可用 |
| 5 | `TCPServer` / `StreamPeerTCP` | `mcp_http_server.gd`（30+ 处） | ✅ Godot 内置网络 API，跨平台可用 |
| 6 | `OS.get_environment()` | 仅 APPDATA 一处（已归入高风险 1.2） | — |

---

## 四、安全项（未发现问题的模式）

| 检查项 | 结果 |
|--------|------|
| `OS.get_name()` 平台判断 | ❌ 未使用（应在 `_check_port_conflict` 中添加） |
| `OS.has_feature()` | ❌ 未使用 |
| `.replace("\\", "/")` 路径标准化 | ✅ 未发现 |
| `.exe` / `.bat` / `.cmd` / `.sh` / `.app` 硬编码 | ✅ 未发现 |
| `Godot_v` 硬编码路径 | ✅ 未发现 |
| `bash` / `sh` / `cmd` / `powershell` 调用 | ✅ 未发现 |
| `project.godot` 平台特定配置 | ✅ 未发现 |
| Windows 盘符路径直接使用 | ✅ 未发现（仅在安全验证列表中作为拒绝模式） |

---

## 五、汇总

| 风险等级 | 数量 | 关键问题 |
|----------|------|----------|
| **高** | 3 | `netstat`/`tasklist` Windows 专有命令、`APPDATA` 环境变量、`python` 命令名 |
| **中** | 4 | 路径拼接用 `+`、path_validator 硬编码模式、测试路径、日志轮转 |
| **低** | 6 | Godot 内置 API 均跨平台兼容 |

### 优先修复建议（按重要性排序）

| 优先级 | 文件 | 行号 | 问题 | 适配方案 |
|--------|------|------|------|----------|
| P0 | `mcp_http_server.gd` | 127, 143 | `netstat` + `tasklist` | 按平台分支：Windows→netstat/tasklist，Linux→ss/lsof，macOS→lsof |
| P0 | `editor_tools_native.gd` | 979 | `APPDATA` | 替换为 `EditorPaths.get_export_templates_dir()` 或按平台构建路径 |
| P1 | `project_tools_native.gd` | 840 | `"python"` | 优先 `python3`，回退 `python` |
| P2 | `mcp_server_native.gd` + `resource_tools_native.gd` | 722/222 等 | 路径拼接 `+` | 改为 `path_join()` |
| P2 | `path_validator.gd` | 19-29 | 缺 macOS 路径模式 | 补量添加 `/Users/`、`/Library/` 等 |
