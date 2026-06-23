# Gameplay Spec Template: Turning Feel into Verifiable Metrics

Game-feel requests such as “make the jump snappy” are hard to validate unless they become measurable. Use this template before asking an AI assistant to implement or tune mechanics.

## How to use it

1. Define the mechanic in plain language.
2. Choose the metric that proves it works.
3. Add an acceptable range rather than one exact value.
4. Map the metric to `play_and_verify` or another runtime/debug tool.
5. Put the metric in the task's `done_when` block.

## Spec table

| Mechanic | Metric | Target range | Verification idea |
| --- | --- | --- | --- |
| Jump height | Apex delta in pixels/world units | 72–88 px | Hold jump for one deterministic input script and sample player Y each physics frame. |
| Time to apex | Seconds/frames until vertical velocity crosses zero | 0.28–0.36 s | Use frame-counted playback, not wall-clock sleeps. |
| Coyote time | Max delay after leaving ground where jump still works | 0.08–0.12 s | Walk off a ledge, wait within the window, press jump and assert upward velocity. |
| Jump buffer | Max early jump press accepted before landing | 0.08–0.12 s | Press jump before landing and assert jump starts on contact. |
| Max run speed | Steady-state horizontal speed | Design-specific | Hold move for fixed frames and sample velocity after acceleration settles. |
| Dash distance | Distance covered during dash | Design-specific | Trigger dash and compare position delta over the dash window. |
| Camera follow | Lag/settle time | Design-specific | Move player abruptly and sample camera-player offset over frames. |
| Runtime stability | Error count | 0 | Run `assert_no_runtime_errors` during the slice smoke test. |
| Performance | FPS/frame-time budget | Project-specific | Run `assert_performance_budget` after the scene is playable. |

## Mapping metrics to assertions

Example done criteria:

```text
Done when:
- A deterministic jump test reaches a 72–88 px apex.
- Time to apex is between 0.28 s and 0.36 s.
- Coyote jump succeeds when jump is pressed 0.10 s after leaving a ledge.
- The scene produces no runtime errors during a 10 s smoke test.
```

Example pseudocode for an assistant:

```text
1. Enable Debug-Advanced tools.
2. Run the scene.
3. Install the runtime probe.
4. Use play_and_verify with frame-stepped input.
5. Extract jump metrics from the report.
6. Fail the task if any metric falls outside the accepted range.
```

## Notes

- Prefer ranges over exact numbers; Godot physics settings and art scale can change exact values.
- Use deterministic frame counts whenever possible.
- Keep feel specs close to the task plan so implementation and verification stay aligned.
- If a metric cannot be measured yet, add a setup task to expose the needed runtime state.
