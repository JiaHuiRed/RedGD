---
name: pr-review-merge
description: "审查、测试、修复并合并 Godot MCP Native PR 的流程。适用于 PR 质量检查、GUT/集成测试和 GitHub squash merge。"
---

# PR Review & Merge Workflow

Use this skill to review a Godot MCP Native pull request before merge.

## Preconditions

- You have the PR branch or ref locally.
- You can inspect the PR description and diff.
- Relevant Godot/GUT/Python tooling is available for the checks you plan to run.

## Step 1 — Create an integration branch

```bash
git checkout main
git pull origin main
git checkout -b integration/pr-review-<number>
```

Merge the PR branch into the integration branch and resolve conflicts intentionally.

## Step 2 — Review the diff

Check every changed file for:

- Functional completeness.
- Argument validation and structured errors.
- Tool registration/classification correctness.
- Translation updates for user-visible strings.
- Test coverage for changed behavior.
- Documentation updates for changed user-facing behavior.
- No committed secrets, local caches or generated editor noise.

## Step 3 — Tool-specific checklist

For new or changed MCP tools:

- Handler exists in the correct `addons/godot_mcp/tools/*_tools_native.gd` file.
- `server_core.register_tool(...)` includes accurate schemas, annotations, category and group.
- `mcp_tool_classifier.gd` includes the tool.
- Core count remains intentional; advanced tools are `supplementary` unless explicitly promoted.
- `tool_descriptions.json` and `.csv` are updated.
- `docs/tools/` includes the tool and description.
- Unit tests cover happy path, missing/invalid args and edge cases.

## Step 4 — Run tests

Run the closest targeted tests first, then broader tests when tooling is available.

GUT shape:

```bash
godot --headless --path . -s addons/gut/gut_cmdln.gd -gdir=res://test/unit/ -ginclude_subdirs -gexit
```

Integration shape:

```bash
python test/integration/test_runtime_probe_flow.py
```

For docs-only PRs, run link/JSON validation instead of Godot tests.

## Step 5 — Classify findings

- **Blocking:** incorrect behavior, failing relevant tests, security regression, missing required test/doc updates.
- **Fixable in review:** small translation/doc/test gaps, typo-level issues, missing edge-case assertions.
- **Follow-up:** non-blocking polish or broader refactors outside PR scope.

If a finding contradicts explicit user/maintainer instructions, escalate instead of silently reversing the requested behavior.

## Step 6 — Merge

Preferred merge method is GitHub squash merge after checks pass and review is complete.

```bash
gh pr merge <number> --squash --subject "<type>: <concise title>"
```

If `gh` is unavailable, use the repository's approved PR tooling or merge through the GitHub UI.

## Step 7 — Cleanup

After merge:

- Confirm `main` contains the merge commit.
- Delete local integration/fix branches.
- Record any follow-up tasks in issues or docs, not in untracked local files.
