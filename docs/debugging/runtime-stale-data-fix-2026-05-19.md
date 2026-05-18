# Runtime Stale Data Fix Report (2026-05-19)

## Problem (a): `get_editor_screenshot` returns stale viewport after `open_scene`

### Symptom

After calling `open_scene` to switch scenes, `get_editor_screenshot` returns a screenshot of the previous scene. When the editor window is in the background or on the Script tab, the tool times out or returns stale content.

### Root Cause

Two issues compound:

1. **Wrong SceneTree access**: The original code used `get_tree().process_frame` to await one frame. `EditorToolsNative` extends `RefCounted`, which has no `get_tree()` method, causing a parse error.

2. **Viewport not rendering in background**: The editor's `SubViewport` uses `render_target_update_mode = UPDATE_WHEN_VISIBLE` by default. When the editor is minimized, in the background, or showing a different main screen (e.g., Script editor), the viewport does not render, so `force_draw()` flushes stale content.

### Fix

File: `addons/godot_mcp/tools/editor_tools_native.gd` (lines 1208-1230)

1. **Switch main screen editor** before capturing: call `editor_interface.set_main_screen_editor(viewport_type.to_upper())` to activate the target viewport (e.g., "3D" or "2D").

2. **Temporarily force UPDATE_ALWAYS**: set `viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS` so the viewport renders even in the background.

3. **Use `Engine.get_main_loop()` instead of `get_tree()`**: proper way to access SceneTree from a RefCounted object.

4. **Await one process_frame then force_draw**: wait for the SubViewport to render the current scene, then flush.

5. **Restore original update mode** after capturing to avoid unnecessary rendering overhead.

```gdscript
# Switch main screen to target viewport type
editor_interface.set_main_screen_editor(viewport_type.to_upper())

# Temporarily force UPDATE_ALWAYS for background rendering
var original_update_mode: int = viewport.render_target_update_mode
viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS

# Wait one frame and flush
var tree: SceneTree = Engine.get_main_loop() as SceneTree
if tree:
    await tree.process_frame
RenderingServer.force_draw()

var texture: ViewportTexture = viewport.get_texture()
# Restore original mode
viewport.render_target_update_mode = original_update_mode
```

### Verification

- Opened TestScene.tscn (contains Cube) → screenshot A
- Switched to CoreToolTestScene.tscn (empty) → screenshot B
- Compared: 48985 differing pixels (11%), screenshots are different
- Tested from Script tab: auto-switches to 3D viewport and captures correctly

---

## Problem (b): `get_runtime_info` / `get_runtime_scene_tree` return stale data after scene change

### Symptom

After calling `evaluate_runtime_expression` to change the running scene, the first call to `get_runtime_info` or `get_runtime_scene_tree` returns data from the previous scene. Requires a second call to get the new scene's data.

### Root Cause

Two issues in `_request_runtime_probe_poll`:

1. **Fallback silently returns stale data**: `_extract_pending_runtime_probe_response` marks fallback cache data as `status: "stale"` with `stale: true`, but the poll loop entry condition only checked for `status == "pending"`. When the initial call returns `stale`, the poll loop is never entered, and stale data is returned immediately.

2. **Poll loop only entered on "pending"**: The condition `if result.get("status") == "pending"` meant that a first-call `stale` result bypassed the poll loop entirely.

### Fix

File: `addons/godot_mcp/tools/debug_tools_native.gd`

**Fix 1** — `_extract_pending_runtime_probe_response` (already applied): fallback data marked as `"stale": true` instead of `"success"`.

**Fix 2** — `_request_runtime_probe_poll` (line 2814): change entry condition from `== "pending"` to `in ["pending", "stale"]`:

```gdscript
# Before:
if result.get("status") == "pending":

# After:
if result.get("status") in ["pending", "stale"]:
```

This ensures that when the first call returns stale cached data, the poll loop continues to retry until fresh data arrives or the timeout expires.

### Impact Analysis

`_request_runtime_probe_poll` is called by 35 runtime probe tools. The change is safe because:

- Tools with `match_fields`: `_payload_matches` strictly matches response fields, so first call typically returns `success` and never enters the poll loop. **No behavior change.**
- Tools without `match_fields` (e.g., `get_runtime_info`, `get_runtime_scene_tree`): previously returned stale data immediately; now polls for fresh data within the timeout window. **Improved behavior.**
- Timeout fallback unchanged: if polling times out, stale data is returned with `from_cache: true` as before.

### Verification

1. Ran `runtime_test_main_scene.tscn` → confirmed `current_scene: "/root/runtime_test_main_scene"`
2. Called `evaluate_runtime_expression` to switch to `runtime_test_sub_scene.tscn`
3. **Single call** to `get_runtime_info` → `current_scene: "/root/runtime_test_sub_scene"` (correct)
4. **Single call** to `get_runtime_scene_tree` → `name: "runtime_test_sub_scene"`, child `SubSceneMarker` (correct)

Previously required 2 calls; now works in 1 call.

---

## Test Scenes Created

- `res://screenshots/runtime_test_main_scene.tscn` — Node2D with MainSceneLabel + SwitchButton
- `res://screenshots/runtime_test_sub_scene.tscn` — Node2D with SubSceneMarker
- `res://screenshots/runtime_test_main_scene.gd` — button click triggers `change_scene_to_file`
- `res://screenshots/runtime_test_sub_scene.gd` — empty script

## Unit Test Updates

### `test/unit/tools/test_editor_tools.gd`

- `test_editor_screenshot_update_always_forced` — verifies UPDATE_ALWAYS + restore + force_draw
- `test_editor_screenshot_switches_main_screen` — verifies `set_main_screen_editor` + `viewport_type.to_upper()`
- `test_editor_screenshot_uses_engine_main_loop` — verifies `Engine.get_main_loop()` instead of `get_tree()`

### `test/unit/tools/test_debug_tools.gd`

- `test_extract_response_fallback_marks_stale` — verifies fallback marks `stale: true`
- `test_poll_loop_continues_on_stale` — verifies poll loop continues on stale inside while loop
- `test_poll_loop_enters_on_initial_stale` — verifies poll loop enters when initial result is stale (not just pending)
