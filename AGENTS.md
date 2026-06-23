# AGENTS.md — Godot MCP Native 项目指南

## 项目概览

Godot MCP Native 是一个 Godot 4.7 `EditorPlugin`，位于 `addons/godot_mcp/`。插件在 Godot 编辑器内部实现 Model Context Protocol（MCP）服务器，让 AI 助手可以通过标准 MCP 工具读取、修改和验证项目。

- **插件入口：** `addons/godot_mcp/mcp_server_native.gd`
- **作者：** xianyu0514
- **版本：** 1.0.7-pre1
- **许可证：** MIT
- **渲染器：** GL Compatibility
- **工具数：** 212 = 30 core + 180 supplementary/advanced + 2 meta

## 代码语言策略

- 注释和用户可见文本可以使用中文或英文，以清晰为准。
- 标识符、文件名、函数名和类名保持 ASCII/English，保证 GDScript 工具链和跨平台兼容性。
- 同一文件内尽量保持语言风格一致，避免中英文无意义混排。

## 关键目录

```text
addons/godot_mcp/
├── mcp_server_native.gd        # EditorPlugin 入口和生命周期
├── native_mcp/                 # MCP 核心、传输、设置、鉴权、隧道、工具状态
├── runtime/mcp_runtime_probe.gd# 运行时 Autoload 探针
├── tools/                      # Node/Script/Scene/Editor/Debug/Project/Meta 工具实现
├── ui/                         # MCP 停靠面板和工具管理 UI
├── translations/               # 面板文本和工具描述
└── utils/                      # 路径、资源、脚本、节点、payload 等辅助工具

docs/                           # 用户和开发文档
test/unit/                      # GUT 单元测试
test/integration/               # Python HTTP MCP 集成测试
```

## 开发规范

### GDScript

- 变量、函数、方法使用 `snake_case`。
- `class_name` 类型使用 `PascalCase`。
- 尽量添加类型标注，例如 `var player: Player`、`func read() -> Dictionary:`。
- 编辑器插件脚本使用 `@tool`。
- 非节点工具类优先继承 `RefCounted`。
- GUT 测试文件使用 `extends "res://addons/gut/test.gd"`，不要声明 `class_name`。

### 错误处理

- 工具处理函数先校验参数，再执行副作用。
- 失败时返回 `{"error": "message"}` 形式的结构化错误。
- 生产路径不要使用 `assert()` 代替错误处理。
- 错误消息应包含用户修复调用所需的上下文。

### 新增或修改 MCP 工具

1. 在对应 `addons/godot_mcp/tools/*_tools_native.gd` 中实现处理函数。
2. 用 8 参数 `server_core.register_tool(...)` 注册工具。
3. 在 `native_mcp/mcp_tool_classifier.gd` 中加入分类：`core`、`supplementary` 或 `meta`，并指定 group。
4. 更新 `test/unit/` 或 `test/unit/tools/`，跨编辑器/运行时/传输的行为还要更新 `test/integration/`。
5. 更新 `addons/godot_mcp/translations/tool_descriptions.json` 和 `.csv`。
6. 更新 `docs/tools/` 以及受影响的使用文档。
7. 运行相关测试。

除非维护者明确要求调整默认面，否则新增工具应优先作为 `supplementary`，避免突破 30 个核心工具的默认上限。

## 常用命令

### 打开项目

使用 Godot 4.7.x，以 GL Compatibility 渲染器打开 `project.godot`。

### GUT 单元测试

```bash
godot --headless --path . -s addons/gut/gut_cmdln.gd -gdir=res://test/unit/ -ginclude_subdirs -gexit
```

### Python 集成测试

```bash
python test/integration/test_runtime_probe_flow.py
```

集成测试通常需要先启动带 MCP HTTP 服务器的 Godot 编辑器实例。

### HTTP MCP smoke test

```bash
curl -s \
  -H "Content-Type: application/json" \
  -X POST http://127.0.0.1:9080/mcp \
  -d '{"jsonrpc":"2.0","id":1,"method":"tools/list","params":{}}'
```

工具调用参数放在 `params.arguments` 中。

## 文档同步要求

- 新/改工具：更新 `docs/tools/<category>-tools.md`、`docs/tools/README.md` 和翻译描述。
- 新设置或 CLI 参数：更新 `docs/configuration.md` 和 README 中的速览信息。
- Runtime Probe 行为：更新 `docs/architecture.md`、`docs/tools/debug-tools.md` 和 `docs/testing.md`。
- 远程访问/隧道行为：更新 `docs/remote-access.md`。
- 测试流程变化：更新 `docs/testing.md` 和相关 skill 文档。

## Git 和 PR 约定

- 不直接推送到 `main`。
- 不使用破坏性 git 命令清理用户更改。
- 不提交本地 token、`user://` 配置、缓存或编辑器临时文件。
- 提交前确认 `git status` 只包含本任务相关文件。
- PR 描述需要包含变更摘要、测试结果和已知限制。

## Godot 4.7 注意事项

- 项目使用 GL Compatibility 渲染器。
- 文件导入、资源刷新和 FileSystem Dock 更新可能异步发生；测试中应等待可观察状态。
- 修改编辑器可见状态时优先使用 Godot EditorInterface/API，而不是只改磁盘文件。
- 不要手动编辑生成的 `.uid` / import 缓存文件，除非它们是插件分发内容的一部分。
