# Planner Playbook: GDD → Executable Task List

Use this playbook to turn a compact game idea into tasks that an MCP-enabled assistant can execute and verify.

## Step 1 — Write a one-page GDD

Keep the first version small enough to fit in a single prompt:

- Title and genre.
- Target platform and input method.
- Core loop.
- Player verbs.
- Win/lose conditions.
- Required scenes.
- Required assets.
- Feel targets that should be measured.
- Out-of-scope items for the first slice.

## Step 2 — Decompose into ordered tasks

Each task should have:

- A concrete output path or scene/resource/script target.
- Dependencies on earlier tasks.
- A short implementation note.
- A measurable `done_when` block.

Good task shape:

```json
{
  "id": "player-controller",
  "title": "Create responsive 2D player controller",
  "depends_on": ["input-map"],
  "outputs": ["res://scenes/player.tscn", "res://scripts/player_controller.gd"],
  "done_when": [
    "Player moves left/right with configured input actions",
    "Jump reaches 72-88 px apex in 0.28-0.36 seconds",
    "No runtime errors during deterministic smoke test"
  ]
}
```

## Step 3 — Attach gameplay metrics

Use [Gameplay Spec Template](gameplay-spec-template.md) for mechanics where subjective feel needs objective checks: jump height, coyote time, max speed, dash distance, camera lag, hit-stop duration or animation timing.

## Step 4 — Execute one vertical slice

For each task:

1. Inspect current project state.
2. Enable only the needed advanced tools.
3. Apply edits.
4. Run targeted verification.
5. Update the task plan with pass/fail evidence.
6. Fix failures before starting the next task.

## Worked example: 2D platformer vertical slice

| Order | Task | Verification |
| ---: | --- | --- |
| 1 | Create input actions: move left/right, jump, pause | `list_project_input_actions` shows all actions. |
| 2 | Build `player.tscn` with collision, sprite and controller script | Scene opens and node tree matches expected structure. |
| 3 | Create a simple level scene with floor and spawn point | Player starts above floor and can collide. |
| 4 | Implement movement and jump feel | `play_and_verify` reports target jump apex/time and max speed. |
| 5 | Add camera follow and UI placeholder | Runtime screenshot/scene tree shows camera and UI. |
| 6 | Run regression gates | No runtime errors, performance budget passes, optional visual baseline passes. |
