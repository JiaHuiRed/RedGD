---
name: testing-mcp-tools
description: "在 Godot 编辑器中通过 HTTP 端到端测试 MCP 工具。适用于验证新增/修改工具在真实编辑器和运行时环境中的行为。"
---

# End-to-End Testing of Godot MCP Tools

Use this skill when a change must be verified through a real Godot editor instance and the HTTP MCP endpoint.

## Environment assumptions

- Project root: `/home/ubuntu/repos/GodotMcp-XY` unless the current session says otherwise.
- Local MCP endpoint: `http://127.0.0.1:9080/mcp`.
- `res://` maps to the project root.
- Advanced tools are registered but disabled until enabled from the panel or `enable_tools`.

## Start the editor and server

Preferred startup when a Godot binary is available:

```bash
DISPLAY=:0 godot --editor --path /home/ubuntu/repos/GodotMcp-XY -- --mcp-server --mcp-port=9080
```

If the server is not auto-started, open the MCP panel and click **Start Server**.

## HTTP call pattern

List enabled tools:

```bash
curl -s \
  -H "Content-Type: application/json" \
  -X POST http://127.0.0.1:9080/mcp \
  -d '{"jsonrpc":"2.0","id":1,"method":"tools/list","params":{}}'
```

Call a tool. Tool arguments must be nested under `params.arguments`:

```bash
curl -s \
  -H "Content-Type: application/json" \
  -X POST http://127.0.0.1:9080/mcp \
  -d '{"jsonrpc":"2.0","id":2,"method":"tools/call","params":{"name":"get_project_info","arguments":{}}}'
```

## Enable advanced tools

Use `list_tool_catalog` to find tools without loading every schema, then enable only what is needed:

```json
{
  "name": "enable_tools",
  "arguments": {
    "groups": ["Debug-Advanced"],
    "enabled": true
  }
}
```

A disabled registered tool returns an error like `Tool is disabled: <name>`. An unregistered tool returns `Tool not found`.

## Standard verification flow

1. Confirm `tools/list` works.
2. Confirm the target tool is enabled.
3. Capture pre-state with read-only tools or filesystem inspection.
4. Call the target tool with minimal valid arguments.
5. Verify the structured response.
6. Verify side effects in Godot/project files/runtime state.
7. Run the closest unit or integration test.
8. Record exact commands and results in the PR.

## Scene-context caveat

Tools that rely on `EditorInterface.get_edited_scene_root()` operate on the currently edited scene, not necessarily the last `.tscn` written to disk. If a test creates a scene file and immediately calls node tools, open that scene first or target the actual edited scene root from `get_scene_tree`.

## Evidence to capture

- Enabled tool count or target group state.
- JSON-RPC request/response for the target tool.
- File/resource diff or runtime state proving the side effect.
- Test command output.

## Secrets

No secret is required for the default local HTTP server when auth is disabled. If auth is enabled, use a temporary local token and do not commit it.
