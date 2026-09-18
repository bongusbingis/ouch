# Multi-Agent Production Workflow

## Purpose

This document defines a provider-neutral workflow for coding assistants that can delegate work to subagents. It is designed for Roblox production, but the scheduling, ownership, and verification rules apply to any software project.

The system has one coordinating agent, **Prime**, and a pool of bounded specialists. The pool provides at least eight distinct capabilities, but Prime activates only the lanes that a task needs. Agent count is available capacity, not a requirement to fan every request out to every specialist.

The workflow has four goals:

1. Increase throughput by running genuinely independent work in parallel.
2. Improve quality through specialization and independent verification.
3. Reduce token use by giving each worker only the context needed for its assignment.
4. Preserve one coherent product direction, codebase, and source of truth.

## Core operating principles

- Prime owns the overall goal, task graph, priorities, integration decisions, and final answer.
- Specialists receive bounded assignments rather than the entire conversation or repository history.
- Every assignment has an explicit read scope, write scope, acceptance criteria, and return format.
- Only independent work runs concurrently.
- One task owns a file or shared resource at a time.
- Research, design, implementation, review, and release approval remain distinguishable activities.
- Evidence lives in files; agent messages contain short summaries and paths.
- Claims are never upgraded from planned to verified without recorded evidence.
- Existing project instructions and newer user direction override this general workflow.

## Agent roster

These are roles, not requirements for a particular vendor, model, tool, or agent configuration format. One underlying agent may fill different roles at different times, but it must follow the contract of its current role.

### 1. Prime — orchestrator and integrator

Prime is the only agent responsible for the complete outcome.

Responsibilities:

- Translate the user's goal into deliverables, invariants, acceptance criteria, and a dependency graph.
- Maintain the live task board and assign specialist lanes.
- Decide which work benefits from parallelism and which work must remain sequential.
- Grant file and resource leases before allowing mutations.
- Reconcile conflicting recommendations.
- Inspect returned evidence, diffs, and test results.
- Create follow-up work when verification reveals a real gap.
- Communicate decisions, blockers, risks, and the final result to the user.

Prime should avoid doing broad implementation while specialists are active. It may handle small integration edits, resolve conflicts, or perform an urgent unblocker when that is cheaper than opening another lane.

### 2. Scout — context and verification researcher

Scout establishes what is already true before the team changes it.

Responsibilities:

- Locate the relevant code, configuration, tests, assets, history, and project instructions.
- Trace real execution paths and state ownership.
- Reproduce reported behavior when possible.
- Check prior decisions and identify stale or conflicting documentation.
- Verify external APIs or platform behavior from authoritative sources when needed.
- Produce concise evidence memos with file, symbol, and artifact references.

Default mode: read-only.

Scout does not implement fixes or turn uncertain findings into facts.

### 3. Architect — systems and interface designer

Architect owns technical shape across subsystem boundaries.

Responsibilities:

- Define module boundaries, interfaces, data flow, state ownership, and failure behavior.
- Identify compatibility, migration, concurrency, security, and performance risks.
- Choose the smallest design that satisfies the acceptance criteria.
- Record architectural decisions that future tasks must preserve.
- Give Mason an implementable plan with explicit contracts.

Default output: a design memo or interface contract. Architect should not edit production code unless Prime explicitly combines the design and implementation phases for a small task.

### 4. Forge — gameplay and experience designer

Forge turns product goals and available assets into coherent, playable behavior.

Responsibilities:

- Define the player experience, gameplay loop, UX principles, feedback, pacing, and tuning intent.
- Convert art, animation, audio, UI, and world assets into implementable gameplay specifications.
- Preserve established visual and interaction systems.
- Specify edge cases, device considerations, accessibility expectations, and success criteria.
- Separate subjective design choices from measurable acceptance requirements.

Default output: a gameplay or UX specification, not production implementation.

### 5. Mason — implementation owner

Mason converts an approved specification into the smallest defensible code change.

Responsibilities:

- Implement production code and focused tests within the leased paths.
- Preserve declared invariants and public behavior outside the assignment.
- Follow repository formatting, linting, typing, and architectural conventions.
- Run the checks appropriate to the change.
- Report every changed file, check result, evidence path, and unverified assumption.

Mason must not silently redesign requirements, expand scope, or modify unrelated files to make tests pass.

### 6. Gauge — test and runtime QA specialist

Gauge validates behavior independently of Mason's implementation reasoning.

Responsibilities:

- Derive test cases from requirements, regressions, and likely failure modes.
- Run unit, integration, simulation, performance, and runtime checks as applicable.
- Reproduce failures with minimal steps.
- Distinguish test-environment failures from product failures.
- Record exact commands, environment, results, and artifacts.

Default mode: read-only except for dedicated test fixtures and evidence paths leased by Prime.

Gauge reports failures; it does not rewrite production code during the same assignment.

### 7. Sentry — correctness, security, and regression reviewer

Sentry reviews the proposed change as an independent owner.

Responsibilities:

- Inspect the diff and the affected execution paths.
- Look for correctness defects, trust-boundary mistakes, exploit paths, data loss, race conditions, and missing cleanup.
- Check whether tests prove the claimed behavior rather than mirror the implementation.
- Rank findings by impact and confidence.
- Cite concrete evidence and avoid style-only feedback unless it hides a maintainability or correctness risk.

Default mode: read-only. Sentry never approves its own implementation.

### 8. Lens — visual, interaction, and device QA specialist

Lens validates what players actually see and operate.

Responsibilities:

- Review in-engine screenshots, captures, UI stories, and interactive flows.
- Check hierarchy, readability, input targets, clipping, scrolling, motion, and feedback.
- Compare work against approved references and the shared design system.
- Verify relevant desktop, mobile, controller, and aspect-ratio states.
- Record exactly which states were inspected and which remain untested.

Default mode: read-only except for evidence capture locations. Lens does not declare visual approval from source inspection alone.

### 9. Rigger — Roblox Studio, world, and asset integration specialist

Rigger owns operations that depend on live Studio state, place hierarchy, assets, animation, or world geometry.

Responsibilities:

- Inspect the intended place and confirm Edit or Play state before acting.
- Stage, preview, measure, and validate world or asset changes.
- Preserve source assets and use project-approved promotion paths.
- Capture hierarchy, geometry, animation, replication, and cleanup evidence.
- Treat Studio, places, upload gates, and shared test servers as exclusive resources.

Rigger may mutate live project state only when the task explicitly authorizes it and Prime holds the appropriate resource lease.

### 10. Keeper — data, economy, configuration, and compatibility guardian

Keeper protects durable player and product contracts.

Responsibilities:

- Audit saved-data schemas, migrations, receipts, ownership, catalog IDs, probabilities, prices, rewards, and feature flags.
- Compare before-and-after configuration and public protocol behavior.
- Verify backward compatibility and rollback requirements.
- Flag changes that require human product approval or staged rollout.
- Produce invariant reports for monetization and progression work.

Default mode: read-only. Keeper may propose migrations or guards but should not execute irreversible operations.

### 11. Quill — documentation and release communication specialist

Quill turns verified work into durable, audience-appropriate communication.

Responsibilities:

- Update technical documentation, handoffs, changelogs, review packets, and release notes.
- Prepare player-facing copy, localization-ready strings, and operational checklists.
- Keep claims aligned with actual evidence and test status.
- Remove internal reasoning, secrets, and irrelevant implementation detail from external-facing language.
- Identify documentation that became stale because of the change.

Quill does not invent test results or change product behavior through documentation edits.

## Live task states

The live board uses exactly three task states.

### READY

The task can start now. Its required inputs exist, dependencies are satisfied, acceptance criteria are testable, and required resources are available or leasable.

### WAITING

The task is waiting on an event that can resolve without a new product decision, such as:

- a delegated agent result;
- a background build or test;
- a review response;
- an asset-processing operation;
- an already-requested user action;
- a scheduled retry after a transient failure.

Every waiting task must record:

- `waiting_on` — the exact event;
- `wake_when` — the condition that makes it ready;
- `next_check` — when or how Prime should recheck it;
- `timeout_action` — retry, convert to blocked, or take a named fallback.

Waiting work must release any resource it no longer needs. An agent should not occupy a lane merely to poll.

### BLOCKED

The task cannot make meaningful progress without a new decision, permission, credential, missing source, or conflict resolution.

Every blocked task must record:

- the concrete blocking condition;
- checks already performed;
- the smallest action that would unblock it;
- safe work that can continue elsewhere.

A failed test with a known repair path is READY work, not a blocker.

### Active leases and completed work

Execution is represented by a lease separate from task status. A READY task may have an active lease containing the worker, leased paths, leased resources, start time, and expiry.

Completed work leaves the live board and is appended to a completed ledger with its result, evidence, and follow-up tasks. This preserves a three-state live queue without losing history.

## Prime's scheduling loop

Prime repeats this loop until the goal is achieved or all remaining work is genuinely blocked:

1. Ingest newly completed specialist results and external events.
2. Verify that returned artifacts exist and that reported checks match their saved evidence.
3. Archive completed tasks or create focused repair tasks.
4. Re-evaluate dependencies and promote eligible waiting tasks to READY.
5. Expire abandoned leases and recover their work safely.
6. Sort READY tasks by:
   - critical-path impact;
   - number of downstream tasks unblocked;
   - risk reduction;
   - user-visible value;
   - age;
   - estimated cost.
7. Match the highest-value task to the cheapest capable specialist lane.
8. Refuse a dispatch if its paths or exclusive resources overlap an active lease.
9. Dispatch independent work up to the configured concurrency limit.
10. Continue planning, integration, or another READY task instead of synchronously waiting on one lane.
11. When no READY work remains, recheck due waiting conditions.
12. If only blocked work remains, ask the user for the smallest specific decision required.

Prime should keep enough capacity for integration and unexpected high-priority findings. Maximum concurrency is a ceiling, not a target.

## Task contract

Every delegated task should contain the following fields:

```yaml
id: FEAT-001
title: Short, outcome-focused title
status: ready
role: mason
objective: One concrete outcome
reason: Why this work exists
depends_on: []
read_scope:
  - exact paths, symbols, artifacts, or URLs
write_scope:
  - exact paths or path patterns
resources:
  - named exclusive or shared resources
invariants:
  - behavior that must remain unchanged
acceptance:
  - observable pass conditions
checks:
  - commands or runtime scenarios
evidence_dir: .review/agent-workflow/FEAT-001
forbidden:
  - explicit out-of-scope actions
return_format: standard-result-v1
```

A work packet should be understandable without the full parent conversation. It should also be small enough that the specialist does not need to rediscover the whole project.

## Standard specialist return

Every specialist returns a concise summary in this form:

```text
RESULT: PASS | WAITING | BLOCKED
SUMMARY: What was established or changed
CHANGED: Exact files or "none"
CHECKS: Commands/scenarios and outcomes
EVIDENCE: Paths to durable artifacts
UNVERIFIED: Anything not actually exercised
RISKS: Remaining material risks
NEXT: Suggested follow-up tasks
```

Raw logs, large diffs, screenshots, and generated reports belong in the evidence directory, not in the message to Prime.

## Ownership and concurrency rules

### File leases

- Prime is the only writer of the task board.
- A specialist may edit only its leased write scope.
- Two active tasks may not write the same file or generated output tree.
- Read-only work may run alongside a writer unless it depends on a stable snapshot of files being changed.
- Before integration, Prime inspects the current diff rather than relying on an earlier snapshot.
- Specialists do not stage, commit, rebase, reset, or discard work unless the task explicitly grants that authority.

### Exclusive resources

Examples of exclusive resources include:

- a Roblox Studio instance;
- a specific place in Edit or Play mode;
- a Rojo port;
- a local test server;
- a generated build directory;
- an asset-upload or publishing gate;
- a shared external review session.

Prime grants and releases these resources explicitly. A waiting task should release a resource unless retaining it is essential and recorded.

### Human gates

Require explicit human authorization for material external or irreversible actions, including:

- publishing a live place or release;
- changing monetization, prices, probabilities, or rewards;
- executing a destructive data migration;
- uploading or deleting production assets;
- sending external communications;
- changing secrets, credentials, or access controls;
- widening scope beyond the stated user goal.

## Quality gates

Prime selects gates according to risk. Not every task requires every gate.

### Code gate

- Focused implementation is complete.
- Formatting, linting, typing, and relevant automated tests pass.
- Unrelated working-tree changes remain untouched.
- No acceptance criterion relies solely on code inspection when runtime evidence is required.

### Review gate

- Sentry reviewed the final diff and affected execution path.
- Material findings are fixed, explicitly accepted, or converted into tracked work.
- The reviewer is independent from the implementation assignment.

### Runtime gate

- Gauge exercised the relevant behavior in the appropriate environment.
- Results include exact commands or reproduction steps.
- Skipped scenarios are labeled `NOT RUN`, never implied to have passed.

### Visual gate

- Lens inspected actual rendered or in-engine states.
- Required devices, aspect ratios, and interaction states are recorded.
- Approved visual references and shared components were used where applicable.

### Roblox integration gate

- Rigger verified the intended place, hierarchy, mode, and cleanup state.
- Studio-only or replication behavior has real Studio evidence.
- Temporary probes, previews, and fixtures are removed before completion.

### Data and economy gate

- Keeper confirmed protected IDs, values, schemas, receipts, and ownership behavior.
- Migration and rollback behavior are defined when durable data changes.
- Product-sensitive changes have human approval.

### Documentation gate

- Quill updated durable instructions and release communication when needed.
- Documentation distinguishes verified results, planned work, and known limitations.

## Default workflow recipes

### New gameplay feature

1. Scout maps current behavior and relevant constraints.
2. Forge defines the player experience and acceptance criteria.
3. Architect defines interfaces and state ownership if the feature crosses subsystems.
4. Prime approves the implementation boundary.
5. Mason implements.
6. Gauge and Sentry independently test and review in parallel.
7. Lens, Rigger, or Keeper joins only if the feature touches their domain.
8. Quill updates durable documentation and release notes.
9. Prime verifies evidence and integrates the result.

### Bug fix

1. Scout reproduces and traces the failure.
2. Prime converts the verified cause into a bounded repair task.
3. Mason implements the smallest fix and regression test.
4. Gauge reproduces the original failure against the fix.
5. Sentry reviews regression and edge-case risk.
6. Prime closes the task or creates a focused follow-up.

### UI or interaction change

1. Scout locates current components, states, and project design guidance.
2. Forge specifies interaction and visual intent.
3. Mason implements with shared tokens and components.
4. Lens captures and reviews required states and devices.
5. Gauge checks functional behavior; Sentry checks state and network boundaries.
6. Quill updates user-facing strings or guidance.

### World, course, animation, or asset work

1. Scout inventories sources and prior evidence.
2. Forge defines gameplay purpose and measurable constraints.
3. Architect defines runtime ownership if new systems are required.
4. Rigger stages and measures the content under an exclusive Studio lease.
5. Mason implements supporting code when needed.
6. Gauge validates gameplay behavior; Lens validates presentation.
7. Sentry reviews cleanup, replication, and failure handling.
8. Prime controls promotion and final integration.

### Release preparation

1. Prime freezes scope and creates a release checklist.
2. Gauge runs the release test set.
3. Sentry reviews the final diff and unresolved risk ledger.
4. Lens and Rigger verify player-facing and Studio-dependent surfaces.
5. Keeper checks configuration, economy, and compatibility.
6. Quill prepares patch notes, handoff, and rollback instructions.
7. Prime presents the evidence and requests any required human release approval.

## Token-efficiency policy

Using more agents saves time and tokens only when assignments are bounded. Uncontrolled fan-out duplicates repository reads and increases cost.

### Context diet

- Give specialists the task contract, applicable project rules, and targeted files only.
- Do not copy the entire parent conversation into every lane.
- Use Scout's memo as shared context instead of making every worker repeat discovery.
- Link to large files and specify headings, symbols, or line ranges to inspect.
- Store logs and screenshots in artifacts; return one-screen summaries.

### Capability routing

- Use the least expensive capable reasoning tier for each role.
- Reserve the strongest reasoning for Prime, difficult architecture, ambiguous design, and high-risk adjudication.
- Use fast workers for targeted searches, mechanical edits, test execution, and documentation formatting.
- Escalate a task only after the cheaper lane identifies a concrete reason.

### Controlled fan-out

- Do not delegate trivial one-file changes unless independence or verification justifies it.
- Spawn multiple agents only for tasks that can proceed independently.
- Avoid asking two agents the same broad question unless deliberate independent review is worth the cost.
- Prefer one Scout memo followed by several narrow consumers.
- Stop a lane as soon as its contract is satisfied or it reaches a declared blocker.

### Reusable memory

- Record stable architectural decisions, commands, and project rules in repository documentation.
- Record task-specific evidence under the task artifact directory.
- Reuse verified memos while their referenced commit and environment remain current.
- Invalidate memos when affected files, configuration, or runtime state changes.

### Bounded retries

- Retry transient operations only according to the task's timeout policy.
- Do not repeat the same failed action without a changed condition.
- Convert repeated uncertainty into a focused Scout task or a clear blocker.

## Suggested artifact layout

The orchestration mechanism may use any storage format. A practical repository-local layout is:

```text
.review/agent-workflow/
  board.json
  completed.ndjson
  decisions.md
  tasks/
    FEAT-001/
      scout-memo.md
      design.md
      test-output.txt
      review.md
      screenshots/
```

The live board is operational state and may remain untracked. Stable decisions, specifications, and user-approved behavior should be moved into the repository's durable documentation.

## Success metrics

Track workflow quality over time rather than optimizing for the number of active agents.

- Lead time from request to verified result
- Percentage of specialist tasks accepted without rework
- Defects found before integration versus after integration
- Duplicate repository exploration per task
- Tokens used per accepted deliverable
- Waiting time caused by resource contention
- Number of conflicting concurrent edits
- Percentage of claims backed by saved evidence
- Number of escaped regressions
- Human decisions requested with sufficient context on the first attempt

If token use rises without corresponding reductions in lead time or defects, reduce fan-out, tighten task packets, or consolidate overlapping roles.

## Adoption sequence

### Stage 1 — contracts

- Establish Prime, the three-state board, task contracts, result format, and file leases.
- Begin with Scout, Mason, Gauge, and Sentry.

### Stage 2 — product specialization

- Add Forge, Lens, Rigger, Keeper, Architect, and Quill as tasks require them.
- Define project-specific quality gates and exclusive resources.

### Stage 3 — automation

- Add atomic board updates, lease expiry, artifact checks, and status summaries.
- Connect existing test, review, capture, and validation scripts.

### Stage 4 — optimization

- Measure rework, token use, and wait time.
- Adjust routing and concurrency based on evidence.
- Keep agent instructions short and move repeatable procedures into reusable workflow modules.

## Definition of done

Prime may declare the user's goal complete only when:

- every required deliverable exists;
- acceptance criteria are satisfied;
- appropriate checks have passed;
- evidence is saved and referenced;
- material review findings are resolved or disclosed;
- temporary resources and probes are cleaned up;
- no required task remains READY, WAITING, or BLOCKED;
- the final response states what changed, what was verified, and any remaining limitation.

