---
name: ty-coordinator
description: Runs the main session (Opus/Fable) as a coordinator that decomposes a multi-part, token-heavy task into briefs, executes them via parallel ty-worker (sonnet) subagents, gates state-changing results with a ty-verifier (haiku) check, and synthesizes the outcome. User-invoked only, via /ty-coordinator [task].
disable-model-invocation: true
argument-hint: "[task]"
---

<skill name="ty-coordinator">

  <overview>
    The frontier session plans, delegates, verifies, and advises — cheap subagents do all token-heavy reading and editing.
    Raw file contents, logs, and diffs stay in worker contexts; only distilled reports cross back to the coordinator.
    If $ARGUMENTS is empty and the conversation doesn't state the task, ask.
  </overview>

  <steps>

    <step id="1" name="verify coordinator model">
      <description>
        Read the session's model from the system prompt line "You are powered by the model named ..." — Opus and Fable qualify; anything else does not.
        If it does not qualify, stop: run no later steps, tell the user to switch with `/model opus` or `/model fable` and rerun.
        Also confirm the worker and verifier agents appear in the available agent types — `ty:ty-worker` and `ty:ty-verifier` (plain `ty-worker`/`ty-verifier` if the namespaced forms are not listed); if missing, stop and tell the user to reinstall the ty plugin — never substitute general-purpose agents.
      </description>
    </step>

    <step id="2" name="resolve the task">
      <description>
        $ARGUMENTS plus conversation context is the task.
        If a step of the task names a user-only skill (the Skill tool rejects it with disable-model-invocation), Read its SKILL.md from the plugin cache (`~/.claude/plugins/cache/<marketplace>/<plugin>/skills/<name>/SKILL.md`) and execute its steps — as the coordinator directly, or by putting the SKILL.md path and its steps into a worker brief when the skill's work is token-heavy.
        This applies only to skills the user explicitly mentioned, never to ones you or a subagent chose yourselves.
      </description>
    </step>

    <step id="3" name="decompose into briefs">
      <description>
        Explore only at structure level (directory listings, symbol search) — delegate any bulk reading to a scout brief.
        If the decomposition rests on an unverified premise ("the config lives in X", "all callers use Y"), spend one worker verifying it before dispatching briefs that depend on it.
        Brief sizing: each brief completable by one sonnet worker alone; prefer fewer, fuller briefs — every spawn has a fixed floor cost.
        Decline check, before any dispatch: coordination pays when workers absorb token-heavy reading and editing the coordinator would otherwise do — parallelism is a bonus, not the gate; a serial chain of token-heavy briefs still qualifies. If the whole task fits in one brief, or the work workers would absorb is small enough to do directly, tell the user coordination won't pay for this task and offer to do it directly instead.
        Every brief contains: goal, exact file scope, constraints, acceptance criteria, and a verification command the verifier or the coordinator's spot-check can re-run.
        When the task is executing an authoritative self-contained spec (a plan file, a design doc): briefs are pointers plus deltas — spec path + task IDs, file scope, overrides, verification command — never restated spec content; the worker reads the spec itself, and a verifier prompt for such a brief must carry the spec path too.
        If the spec content you already hold shows judgment calls the user may want to override (optional behaviors, naming, instrumentation detail), surface them in one AskUserQuestion round before dispatching state-changing briefs — mid-run overrides kill in-flight workers; never deep-read the spec just to hunt for these.
        State-changing briefs tell the worker: run the brief's verification command once when done, scoped to its own changes — no repo- or system-wide validation loops; whole-deliverable validation belongs to step 6.
        Classify each brief as read-only (research or investigation: no file edits, no external writes) or state-changing, and state the classification in the brief.
        Read-only briefs must require inline evidence for every load-bearing claim: verbatim file:line quotes for code claims; the exact query plus a result snippet (or a saved raw-output file path) for external data.
        Briefs that query external data systems (metrics, logs, APIs) must state the query constraints the worker needs — accepted time formats, required aggregations — and demand bounded queries: one aggregated query instead of per-label repeats, never an unaggregated raw-series pull.
        Research briefs additionally get an enumerated deliverable list and an explicit tool-call/query budget sized to it — an open-ended "measure X" or "investigate Y" goal invites unbounded fan-out; prefer one query that returns several statistics over one query per statistic, and require the worker to report calls used against the budget.
        Ask only for distilled evidence in reports — never demand full diffs or raw dumps the worker contract forbids returning.
        Close decomposition with a pre-dispatch checklist in your reply, before any Agent call: the decline-check outcome, and per brief its classification, its step-5 verification mode with a one-line justification, and whether it dispatches now or waits on a dependency.
      </description>
    </step>

    <step id="4" name="dispatch workers">
      <description>
        Spawn independent briefs as Agent calls with the worker agent type from step 1, all in a single message so they run in parallel; hold dependent briefs until their dependencies PASS in step 5.
        Max 4 workers in flight. Record each worker's agentId from the spawn result for follow-ups.
        Each prompt is only BRIEF plus the CONTEXT that worker needs (paths, distilled outcomes of prior briefs) — the report contract is baked into the agent definition.
        If a worker reports blocked or a wrong premise, adjust the brief and SendMessage the correction to that worker rather than respawning.
        If the user stops a worker or overrides its brief mid-run, SendMessage the delta to that same stopped worker — it resumes from its transcript with context intact; respawn fresh only when the override invalidates most of its completed work, and then declare the prior worker's working-tree changes in the replacement's brief.
        Follow-up and resume messages carry only the delta (what changed, what remains) — never restate a brief the worker already holds.
        Completion notifications are not reasoning cues: while other dispatched work is in flight, note the report and act only when a step-5 gate or a dependent dispatch is actually due — batch verdicts and dispatches instead of running a full think-and-report cycle per notification.
      </description>
    </step>

    <step id="5" name="verify each brief">
      <description>
        Pick the verification mode per brief — a spawned verifier is not the default:
        - Read-only briefs: no verifier — spot-check the load-bearing claims the plan will pivot on with a grep or a single re-run query done inline, never a spawned agent.
        - Mechanical state-changing briefs — every acceptance criterion checkable by a grep or by re-running the brief's verification command, no semantic judgment needed (doc edits, config values, dictated-fact transcription, and "implement the spec tasks exactly as written" when every criterion is grep-able or covered by the verification command — mechanical despite sounding semantic) — verify inline yourself: run the combined grep plus the verification command and the scope `git status --porcelain`, and record the outputs as the verdict; spawning a verifier here costs a whole agent for what two commands cover.
        - Semantic state-changing briefs (behavioral, structural, or judgment-requiring criteria): spawn one verifier (agent type from step 1), prompt = the brief + the worker's report; independent verifications go in a single message.
        Keep verifier prompts to at most ~5 criteria: one combined-grep criterion covering ALL verbatim facts and existence checks, the brief's verification commands, and the scope check — criteria sprawl multiplies verifier tool calls and rounds.
        When a passing test or verification command already proves a behavior, the criterion is "the test exists and passes" — never ask the verifier to re-derive that behavior from the code.
        In every verifier prompt, list the paths changed by previously accepted briefs as expected working-tree changes — the verifier treats the brief's declarations as authoritative and will false-FAIL scope without them.
        If a spot-check contradicts the report or required evidence is missing, SendMessage the worker for the evidence; a second miss counts as FAIL under the fix-up rules below.
        FAIL (from a verifier or an inline check) → SendMessage a fix-up to the same worker (its context is intact), quoting only the failing criteria, then re-verify in the same mode, narrowed to the failed criteria plus the scope check. Max 2 fix-up rounds per brief; after that report the brief as failed with the evidence and ask the user — never silently finish it in the main context.
        Overrule a FAIL only when the verifier demonstrably misapplied the criteria, and say so in the final report.
      </description>
    </step>

    <step id="6" name="synthesize">
      <description>
        Whole-task verification first: per-brief passes don't prove the pieces compose, so run one check that exercises the deliverable as a whole (derive it from the original task's acceptance, not from the briefs). Failures here become fix-up briefs (step 5 rules apply).
        Then report per brief: outcome, files changed, verification evidence — followed by unresolved items and deviations.
      </description>
    </step>

  </steps>

  <guardrails>
    - The coordinator never does the token-heavy leg itself: no bulk file reads, no producing the deliverable in the main context — briefs, verdict arbitration, and the final report are its only products. (Exception: the decline-check case in step 3 where it declines to coordinate.)
    - Never accept a state-changing brief unverified: semantic briefs need a verifier verdict, mechanical briefs need the coordinator's own inline grep + verification-command run with recorded output, and re-verification after a fix-up is never skipped; accept a read-only brief only when every load-bearing claim carries inline evidence and the spot-check passed.
    - Never restate the worker or verifier report contracts in spawn prompts — they live in the agent definitions.
    - Never commit or push unless the user asked.
  </guardrails>

</skill>
