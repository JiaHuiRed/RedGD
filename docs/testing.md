# Testing

Use the lightest test that proves the change, then run broader suites before merging code changes.

## Unit tests (GUT)

Unit tests live under `test/unit/`. Tool-specific tests usually live under `test/unit/tools/`.

Typical command shape:

```bash
godot --headless --path . -s addons/gut/gut_cmdln.gd -gdir=res://test/unit/ -ginclude_subdirs -gexit
```

Notes:

- GUT is required for this command.
- Test files should extend `res://addons/gut/test.gd` and should not declare `class_name`.
- Cover happy paths, invalid arguments, edge cases and changed error behavior.

## Integration tests (Python)

Integration tests live under `test/integration/` and exercise the HTTP MCP server against a running/editor Godot instance.

Typical flow:

1. Start Godot with the MCP server enabled.
2. Ensure the server listens on `http://127.0.0.1:9080/mcp`.
3. Run the target Python test:

```bash
python test/integration/test_runtime_probe_flow.py
```

Integration tests are useful for transport behavior, runtime probe workflows, editor automation, imports/exports and project-level side effects.

## Static checks

The repository includes focused static checks such as:

```bash
python test/quiet_mode_static_check.py
```

Use them when the touched code path is relevant.

## Manual MCP smoke test

For local diagnosis, call the HTTP endpoint directly:

```bash
curl -s \
  -H "Content-Type: application/json" \
  -X POST http://127.0.0.1:9080/mcp \
  -d '{"jsonrpc":"2.0","id":1,"method":"tools/list","params":{}}'
```

Tool call payloads use `params.arguments`:

```bash
curl -s \
  -H "Content-Type: application/json" \
  -X POST http://127.0.0.1:9080/mcp \
  -d '{"jsonrpc":"2.0","id":2,"method":"tools/call","params":{"name":"get_project_info","arguments":{}}}'
```

## What to run by change type

| Change | Minimum validation |
| --- | --- |
| Documentation only | Markdown/link checks and JSON example validation. |
| Tool schema or handler | Targeted unit tests plus tool registration/classification checks. |
| Runtime probe | Relevant runtime integration test plus unit tests for payload parsing. |
| UI/panel behavior | Targeted unit tests plus manual editor smoke test. |
| Transport/auth | HTTP/stdio/auth tests and direct curl smoke test. |
| Export/import/project resources | Targeted integration test and filesystem side-effect inspection. |

## Test data hygiene

- Prefer writing temporary resources under test-specific paths.
- Clean up generated files or keep them in ignored test output directories.
- Do not commit local `user://` settings, tokens or editor cache files.
- Avoid modifying generated `.uid` files by hand.
