# Autonomous Iteration Harness

An autonomous harness is a repeatable loop that lets an AI assistant plan, edit, run, verify and fix a Godot game slice without losing context.

## Loop overview

```text
PLAN → EXECUTE → RUN → VERIFY → FIX → repeat until Definition of Done passes
```

Each phase should write evidence back to the task plan so the next iteration starts from facts rather than memory.

## Phase 1 — PLAN

Inputs:

- Current GDD or task brief.
- Existing project structure.
- Tool catalog and enabled presets.
- Previous iteration failures.

Outputs:

- Ordered task list.
- Files/scenes/resources expected to change.
- Verification commands and metrics.
- Hard stop conditions.

Useful tools: `manage_task_plan`, `get_project_info`, `get_project_structure`, `list_project_resources`.

## Phase 2 — EXECUTE

Apply the smallest coherent set of edits for the current task.

Guidelines:

- Read existing scenes/scripts before writing.
- Prefer existing project conventions.
- Enable only the advanced tool groups needed for the task.
- Record generated assets and resource paths in the task plan.

Useful tools: Node, Scene, Script and selected Project tools.

## Phase 3 — RUN

Start the project and ensure the target scene is live.

Useful tools:

- `run_project`
- `await_scene_ready`
- `install_runtime_probe`
- `get_runtime_scene_tree`
- `get_runtime_info`

## Phase 4 — VERIFY

Run objective checks instead of only visual inspection.

Examples:

- `play_and_verify` for deterministic input/game-feel checks.
- `assert_no_runtime_errors` for runtime stability.
- `assert_performance_budget` for frame-time/FPS budgets.
- `assert_visual_baseline` for screenshot regressions.
- `get_runtime_screenshot` for human review evidence.

## Phase 5 — FIX

If verification fails:

1. Capture the exact failure.
2. Identify the smallest likely cause.
3. Patch only the relevant files.
4. Re-run the failed check.
5. Update the task plan with the new result.

Do not continue to the next task while the current task's required gates are failing.

## Definition of Done

A slice is done when:

- Required scenes/scripts/resources exist.
- Acceptance metrics pass.
- No runtime errors are reported in the smoke test.
- Performance budget is within the chosen threshold.
- The task plan marks the task complete with evidence.

## Recovery rules

Continue autonomously when:

- A test fails with a clear local cause.
- A resource path is wrong but the intended file exists.
- A scene needs a straightforward import/refresh.
- A tool is disabled and can be enabled through `enable_tools`.

Stop and ask a human when:

- Required credentials, paid provider keys or licensed assets are missing.
- The GDD contradicts itself.
- The requested change would remove explicit safety/auth controls.
- A failing metric requires a design decision rather than an implementation fix.

## Pseudocode

```text
while task_plan.has_open_tasks():
    task = task_plan.next_ready_task()
    enable_tools(task.required_groups)
    inspect_current_state(task)
    implement(task)
    run_project()
    install_runtime_probe_if_needed()
    result = verify(task.done_when)
    if result.passed:
        task_plan.mark_done(task, evidence=result)
    else:
        fix(result.failure)
        task_plan.record_attempt(task, result)
```
