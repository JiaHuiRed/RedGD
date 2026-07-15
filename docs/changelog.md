# Changelog

All notable user-facing changes are tracked here.

## [RedGD v0.0.6] - 2026-07-15

> 中优先级性能修复第一批（共两批）：消灭剩余的字符串逐字符 `+=` 拼接（O(n²)），改成 `PackedStringArray` 累积 + 一次性 `join`。均为纯机械改写，控制流与逐字符输出顺序不变，只换了累加器类型。

### 性能
- `utils/script_sandbox.gd` `_strip_strings_and_comments`：三引号/单双引号字符串字面量内部的缓冲区（`buf3`/`buf`）此前仍是逐字符 `+=`，是上一轮 O(n) 优化漏掉的角落——外层代码剥离已经是 `PackedStringArray+join`，字符串内容缓冲却没跟着改。
- `tools/project_tools_native.gd` `_sanitize_cli_output`（`run_project_test` 等工具用来清洗测试运行 stdout）：两趟扫描（ANSI 转义过滤 + 残留 CSI 片段清理）都改成缓冲区累积。
- `tools/project_tools_native.gd` `_i18n_unescape`：`manage_localization` 提取阶段对每条可翻译文本做转义还原，大项目可能有上千条文本触发。
- `tools/editor_tools_native.gd` `_sanitize_cli_output`（导出/冒烟测试日志清洗，与 project_tools_native.gd 同名但各自独立的一份）。
- `tools/script_tools_native.gd` `_strip_shader_comments`：每次 `validate_shader` 都会对整份 shader 源码剥离注释一遍。

## [RedGD v0.0.5] - 2026-07-15

> 这一批收尾本次性能审查里议定的 8 项高优先级修复（v0.0.2 起共 4 个批次）。

### 性能
- `project_tools_native.gd` 的 `audit_project_health`：此前内部依次调用 `scan_missing_resource_dependencies` 和 `scan_cyclic_resource_dependencies` 两个独立工具函数，二者各自对整个 `search_path` 做一次资源树扫描，并各自对每个资源重新调用 `ResourceLoader.get_dependencies` 解析依赖——一次"体检"实际上把资源树连带每个资源的依赖解析都重复了一遍。新增共享的 `_scan_resource_dependency_data` 一次性完成资源收集与依赖解析，`audit_project_health` 算一份共享结果传给两个子扫描；两个工具单独调用时（不经 audit）行为不变，各自仍独立重新扫描。
- `mcp_panel_native.gd` 工具搜索框：此前每次按键都立即触发对全部 215 个工具的过滤与统计（`_apply_view` → `_apply_category_view`/`_apply_search_view` + `_update_detail_count` + `_ensure_tool_selection`），打字快时是连续多趟全量扫描。新增独立的 150ms 防抖 Timer（与设置保存复用的 `_debounce_timer` 分开，避免互相触发无关的 `save_tool_states`），停止输入后才真正应用过滤。

## [RedGD v0.0.4] - 2026-07-15

### 性能
- `mcp_debugger_bridge.gd` 的 `_refresh_script_debugger_connections`：此前被 `get_sessions_info`/`send_debugger_message`/`request_stack_dump`/`request_stack_frame_vars`/`request_evaluate`/`get_captured_messages` 等几乎所有对外方法无条件调用，对整个编辑器 UI 树做一次全量 DFS 找 `ScriptEditorDebugger` 节点；`wait_for_probe_ready` 的逐帧轮询循环因此在一次等待里可能触发上百次全树扫描。现在加了 250ms 节流（`force=true` 保留给新会话建立时的即时刷新），非强制调用在节流窗口内直接跳过扫描。
- `task_plan_store.gd`：`_find_index`/`has_task`/`get_task` 从线性扫描任务数组改为懒重建的 id→索引 Dictionary 缓存（结构变化时打版本号，下次查询才重建，避免逐次增删都要патch索引)。`next_actionable()` 对每个任务的每个依赖调 `get_task()`，密集依赖图下从 O(n²) 降到 O(n)；`_next_auto_id()` 批量建任务时的重复 `has_task` 检查同样受益。这次**没有**改动 `manage_task_plan` 工具层每次调用整文件读写 JSON 的部分——task plan 文件通常很小（几十个任务量级），单次调用的全量读写本身不是热点，跨调用缓存反而会引入陈旧数据风险（比如用户手动编辑了 `task_plan.json`），权衡后判断不值得做。

## [RedGD v0.0.3] - 2026-07-15

### 性能
- `mcp_runtime_probe.gd` 的 `_get_runtime_info`/`_get_performance_snapshot`：`node_count` 不再手写递归遍历整棵场景树（`_count_nodes`，每次调用都是一次全树 DFS），改用引擎内置的 `Performance.OBJECT_NODE_COUNT` 监控值，`ping`/`get_runtime_info`/`get_performance_snapshot` 这类高频轮询调用不再自我扰动被测游戏的帧率。文件内已无调用方的 `_count_nodes` 一并移除。
- `debug_tools_native.gd` 的 `await_scene_ready`/`await_runtime_condition`：内部轮询循环此前不管声明的 `poll_interval_ms`（200ms/500ms）是多少，实际都靠 `await tree.process_frame` 按编辑器帧率（约 60Hz）轮询，向运行中的游戏发送 probe IPC 请求的频率比预期高一个数量级；改为 `await tree.create_timer(poll_interval_ms / 1000.0).timeout`，轮询间隔与声明值一致。

## [RedGD v0.0.2] - 2026-07-15

> upstream（xianyu0514/GodotMcp-XY）两周未更新，不排除停止维护；本 fork 起使用独立于 upstream 的版本号（`0.0.x`，记录在 `plugin.cfg` 的 `version` 字段），后续 fork 特有改动都会走这个版本序列。

### 性能
- `mcp_server_native.gd` 的 `_on_message_received`/`_on_response_sent`：日志级别低于 DEBUG 时不再无条件 `JSON.stringify` 整包消息，且面板日志与调试日志共用同一次序列化结果，而不是各序列化一次。这是每一次 MCP 请求/响应都会走的路径。
- `mcp_runtime_probe.gd` 的 `get_runtime_memory_trend`：采样间隔等待由 `OS.delay_msec()`（阻塞整个游戏主线程）改为 `await get_tree().create_timer(...).timeout`（协程等待），不再在采样期间冻结被测游戏本身。

## [RedGD Fork] - 2026-07-13

> 个人品牌化标注：fork 自 xianyu0514/GodotMcp-XY（upstream 保持同步），由 JiaHuiRed 维护，主要配合 RedMon 项目开发时驱动 Godot 编辑器使用。

### 说明
- 未改动插件功能/工具集，仅在 README.md / README.zh.md / AGENTS.md 增加 fork 归属说明
- 后续本 fork 特有改动将沿用 RedMon 的 changelog 格式（`## [x.y.z] - YYYY-MM-DD` + 中文分类小节）记录；upstream 原有条目保持不变
- 2026-07-15：`addons/godot_mcp/plugin.cfg` 的 `author` 字段追加 fork 标注，Godot 编辑器插件列表内可见
- 2026-07-15：README 主次调整 — 中文版转正为 `README.md`（原 `README.zh.md`），英文版改名为 `README.en.md`（根目录与 `addons/godot_mcp/` 下同步），互相跳转链接同步更新

## Unreleased

- `set_dod` now rejects whitespace-only criterion text on the single-criterion path (both creating a new criterion by text and renaming an existing one by index), returning an error instead of persisting an empty-text criterion. This matches the non-empty rule already enforced on the full-list / `add_task` path.
- Made DoD criterion text consistently trimmed on every storage path. `set_dod` now stores the trimmed `criterion` (matching how criteria are matched and created), and `_normalize_dod` (used by `add_task` and full-list `set_dod`) now trims string entries and rejects whitespace-only ones, the same as dict entries. Previously a `criterion` passed with surrounding whitespace (e.g. `"  fps ok  "`) could be persisted with padding yet matched trimmed, causing lookups to miss and duplicate entries to appear.
- Performance: cut redundant work on the per-request hot path without changing any behavior. The script sandbox (`execute_script` / `execute_editor_script` / `evaluate_*` guard) now compiles each denylist RegEx once and reuses it from a process-lifetime cache instead of recompiling ~26 patterns on every scan, and strips string/comment content with an O(n) buffer join instead of O(n²) per-character concatenation. The JSON-RPC server no longer builds full-request/response `JSON.stringify` strings for debug logging when the log level is above DEBUG (the default), so every `tools/list`, `tools/call`, `resources/list`, and incoming message skips that wasted serialization.
- Made `set_dod` single-criterion updates transactional: the new-criterion path validates all error conditions (invalid gate, `observed` without a gate, non-dict `observed`) before appending, and the existing-criterion path mutates a copy that is only committed once every check passes. A failed call no longer leaves a half-created criterion or a partially-modified one (e.g. a gate attached but the subsequent `observed` evaluation rejected) in the task's DoD.
- Hardened node-creation type validation in `create_node` and `batch_scene_node_edits` create ops: they now reject non-Node classes (e.g. `Resource`, `RefCounted`) and abstract Node classes (e.g. `CanvasItem`) up front with a clear, actionable error instead of letting `ClassDB.instantiate` return null and crashing on the subsequent property assignment. The check is a pure `ClassDB`-only helper (`class_exists` → Node-derived → instantiable), so it's deterministic and unit-tested. Concrete Node types are unaffected.
- Tightened `manage_task_plan` DoD gate evaluation: `set_dod` now evaluates `observed` against the gate even when it creates a brand-new criterion by `criterion` text (previously the metrics were silently ignored and `met` defaulted to false on that path), and an invalid gate no longer leaves a half-created criterion behind. A `no_runtime_errors` gate now requires an actual measurement — an empty `observed` is treated as "can't prove ⇒ not met" instead of passing on a default of 0, matching the other gate types. Also refreshed the `manage_task_plan` tool description in the translation files and documented the optional `gate`/`last_evaluation` DoD fields in the persisted schema.
- Closed a script-sandbox bypass and reduced false positives: `execute_script`'s single-line Expression path is now scanned by the same guard (previously only the multi-line/`execute_editor_script` path was), so a single-line `OS.execute(...)` can no longer slip through under STRICT security. The filesystem check no longer flags Godot scene-tree node paths (`/root/...`) and only treats `~`/`~/` as a home-dir path instead of matching any string containing a tilde (e.g. `"~5 enemies"`); out-of-project absolute and system paths (`/etc/`, `/var/`, drive letters, `~/...`) stay blocked.
- Hardened `manage_task_plan` Definition-of-Done with optional machine-checkable `gate`s so the VERIFY phase decides `met` objectively instead of self-asserting. A DoD criterion can declare a gate of type `performance_budget` (a `budget` of min_fps/max_frame_time_ms/max_physics_frame_time_ms/max_object_count/max_resource_count/max_rendered_objects/max_memory_mb/max_node_count, mirroring `assert_performance_budget`), `no_runtime_errors` (`max_errors`, default 0), or `visual_baseline` (`max_diff_pixels`/`max_diff_ratio`). On `set_dod`, passing `observed` measured metrics auto-computes `met` from the gate and records the verdict as evidence. No new MCP tool; this deepens an existing one and the catalog stays at 215 tools.
- Added a script sandbox guard for `execute_editor_script`, `evaluate_debug_expression` and `evaluate_runtime_expression`: under STRICT `security_level` (the default), scripts/expressions are scanned by a configurable capability denylist (OS process execution, out-of-project filesystem paths, networking, other dangerous APIs) and rejected with a structured `blocked` result before execution. PERMISSIVE mode keeps the previous unrestricted behavior. No new MCP tool is added; the guard hardens existing tools and the catalog stays at 215 tools.
- Expanded the MCP tool catalog to 215 tools by adding the ship-loop closure and localization tools.
- Added `smoke_test_export` (Editor-Advanced): post-export smoke test that resolves the artifact, optionally exports first, asserts the product file exists, and launches it to capture and check the exit code — an objective, runnable-build gate.
- Added `bump_version` (Project-Advanced): semantic version bump written back to project.godot plus an automatic dated changelog entry, with a `dry_run` mode.
- Added `manage_localization` (Project-Advanced): single action-based localization workflow — `list` registered `.translation` files, `extract` translatable keys from scenes/scripts into a Godot CSV (preserving existing translations), `import` that CSV into per-locale `.translation` files registered in ProjectSettings, and `export` registered translations back to CSV for round-trip checks. All write actions support `dry_run`.
- Added external-generation budget guards: `generate_asset` and `generate_3d_asset` external calls now honor a configurable call-count/limit window (`external_gen_budget`, `external_gen_budget_window_sec`) and reject calls over budget. Default 0 keeps it unlimited and backward-compatible.
- Added a minimal GitHub Actions CI workflow (headless import + GUT unit tests).
- Refined and normalized the documentation set: root README, Chinese README, addon README files, configuration, architecture, testing, contributing, remote access, industrialization guides and generated tool-reference pages.
- Repaired corrupted Chinese documentation text in repository-facing docs and agent skill guides.
- Clarified the 215-tool model: 30 core tools, 183 advanced tools and 2 always-on meta tools.

## 1.0.7-pre1 (current)

- Expanded the MCP tool catalog to 212 tools.
- Added `generate_3d_asset` (Project-Advanced): bring-your-own-key text-to-3D generation that submits a job to an external provider (meshy/tripo presets), polls until completion, downloads and validates the glTF/GLB into `res://`, and inspects the result by default.
- Added asset-closure workflows including sprite-sheet slicing and glTF/GLB inspection.
- Added deterministic `play_and_verify` workflows for frame-stepped playtesting and game-feel metrics.
- Added regression gates for visual baselines, performance budgets and runtime errors.
- Improved project-level automation around task plans, resource dependency checks, migration scans, TileSets, render output and generated assets.

## 1.0.6

- Improved runtime/debug tooling and project inspection workflows.
- Expanded integration coverage for runtime probe and editor automation flows.

## 1.0.3

- Stabilized the native Godot MCP server architecture.
- Added core scene, node, script, editor, debug and project tools.
- Added HTTP/SSE and stdio transports.
