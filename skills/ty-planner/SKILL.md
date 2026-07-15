---
name: ty-planner
description: Writes a standalone implementation plan to ./.claude/plans/<date>-<feature>.md that any agent, weaker model, or human can execute cold with zero conversation context. User-invoked only, via /ty-planner [what to plan].
disable-model-invocation: true
argument-hint: "[what to plan]"
---

<skill name="ty-planner">
  <overview>
    Produces one self-contained plan file at `./.claude/plans/YYYY-MM-DD-<feature>.md`.
    The plan is the deliverable — this skill never implements.
    The file must be executable cold: the reader has basic programming ability and the codebase at its current state, but no conversation history and no way to ask questions. Everything they need is inline.
    If $ARGUMENTS is empty and the conversation doesn't state what to build, ask.
  </overview>

  <steps>
    <step id="1" name="verify planning model">
      <description>
        This skill's own reasoning (surveying, drafting, self-review) must run on Opus or Fable — never on a weaker model.
        Read the session's model from the system prompt line "You are powered by the model named ..." — Opus and Fable qualify; Sonnet, Haiku, and anything else do not.
        If the session qualifies, continue with step 2.
        If it does not, stop immediately: run none of the later steps and write no plan file.
        Tell the user this skill requires Opus or Fable, and ask them to switch with `/model opus` or `/model fable` and rerun `/ty-planner`.
      </description>
    </step>
    <step id="2" name="survey the site">
      <description>
        Read the codebase directly before writing anything: entry points, directory structure, existing patterns, dependency versions, test infrastructure, build/run commands, constraints (env vars, config, external services).
        Actively search for existing functions and utilities the plan should reuse — never propose new code where a suitable implementation exists.
      </description>
    </step>
    <step id="3" name="confirm understanding">
      <description>
        State in one sentence what will be built.
        Use AskUserQuestion to resolve ambiguities in requirements or to choose between approaches — do not make large assumptions about intent.
        Do not draft the plan until the goal is confirmed.
      </description>
    </step>
    <step id="4" name="draft the plan">
      <description>
        Write the plan following <plan_format>. Tasks in dependency order; steps within a task in execution order; number everything so a reader can say "Task 2, Step 3".
        Detail level: concise but executable — exact file paths for every create/modify, references to reusable existing functions with their paths, and for a pattern repeated across many files describe it once with 2-3 representative paths instead of enumerating all of them.
      </description>
    </step>
    <step id="5" name="self-review">
      <checks>
        - Placeholder scan: no TBD, TODO, or vague steps anywhere.
        - Path consistency: file paths match across all tasks.
        - Name consistency: function/variable names match across all tasks.
        - Coverage: every requirement from the request has a task.
        - Dependency order: nothing is used before a prior step creates it.
        - Shared files: when two tasks modify the same file, the plan states which goes first.
        - Cold-reader test: no sentence depends on this conversation or on documents the reader can't see.
      </checks>
      <on_failure>Fix the plan and re-run the full checklist — never ship on a partial pass.</on_failure>
    </step>
    <step id="6" name="save and report">
      <description>
        Save to `./.claude/plans/YYYY-MM-DD-<feature>.md` (create the directory if missing) and report the path to the user.
      </description>
    </step>
  </steps>

<plan_format>

```markdown
# [Feature Name] — Implementation Plan

> **For any agent or human:** This plan is self-contained; execute tasks in order.

**Goal:** [One sentence — what does this build?]

**Context:** [Why this change is being made — the problem or need, what prompted it, the intended outcome.]

**Site conditions:** [What exists today: entry points, patterns, framework versions, constraints the executor must know.]

**Output:** [What exists when the plan is complete — files, features, behaviors.]

## Task 1: [Component Name]

**Files:**

- Create: `exact/path/to/file.ext`
- Modify: `exact/path/to/existing.ext`

**Reuses:** [`existingFunction` in `exact/path.ext` — what it provides]

**Precondition:** [What must be true before starting this task.]

1. [One concrete action. Name the edge cases and error handling explicitly.]
2. [Next action. Exact command with expected outcome wherever a step runs one.]

## Task 2: [Next Component]

...

## Verification

[End-to-end: exact commands to run the code and tests, with expected outcomes.]

## Punch List (Out of Scope)

- [Deliberately deferred work, and why.]
```

</plan_format>

  <guardrails>
    - Never draft or self-review the plan on a model weaker than Opus or Fable — stop per step 1 if the current session isn't one of those.
    - Never implement, edit code, or run state-changing commands — the plan file is the only file this skill writes.
    - Never write placeholders: no "TBD", "TODO", "implement later", "add appropriate error handling", "handle edge cases" (name them), or verification that says "check it works" instead of a command.
    - Never write "similar to Task N" or point at another task's content — repeat it in full; tasks are read independently.
    - Never reference the conversation ("as discussed", "the spec above") or external docs — inline everything the executor needs.
    - Never use line-number references — identify locations by exact file path plus function/symbol name.
  </guardrails>
</skill>
