# Agent Authoring Best Practices

A tool-agnostic reference for building **skills, agents, hooks, and plugins** for Claude Code and other Agent Skills–compatible harnesses. Every rule here is testable: given a file, you can decide whether it complies.

The document assumes nothing about a particular repository. Where a rule depends on verified platform behaviour, that behaviour is stated explicitly so you can re-verify it against current docs.

**Sources**

- [Agent Skills specification](https://agentskills.io/specification) — directory structure, frontmatter, progressive disclosure, validation.
- [Best practices for skill creators](https://agentskills.io/skill-creation/best-practices), [Optimizing skill descriptions](https://agentskills.io/skill-creation/optimizing-descriptions), [Evaluating skill output quality](https://agentskills.io/skill-creation/evaluating-skills), [Using scripts in skills](https://agentskills.io/skill-creation/using-scripts).
- [The new rules of context engineering for Claude 5 generation models](https://claude.com/blog/the-new-rules-of-context-engineering-for-claude-5-generation-models) and [Building verification loops in Claude Code with skills](https://claude.com/blog/building-verification-loops-in-claude-code-with-skills) (Anthropic).
- Claude Code platform docs: [skills](https://code.claude.com/docs/en/skills), [hooks](https://code.claude.com/docs/en/hooks), [sub-agents](https://code.claude.com/docs/en/sub-agents), [plugins reference](https://code.claude.com/docs/en/plugins-reference).
- Convergent patterns across widely-used `.claude` repositories (§12).

---

## 1. Principles

Seven rules that govern everything below. Each corrects a specific, common failure mode; the failure is named so you can recognise it, not so you can dwell on it.

### P1 — Judgement over rules

> **Rule:** State the goal, the genuinely non-obvious constraints, and the output contract. Nothing else.

Do not write a "Rules" section that restates the workflow phases already in the body, and do not write imperative micro-rules the model can infer from the goal (*"do not skip steps"*, *"always read the file first"*, *"be thorough"*). Modern models follow purpose better than they follow instruction lists, and every unnecessary directive competes for attention with the ones that matter.

A constraint survives P1 if a competent engineer would not guess it — a project-specific opinion, an irreversible-operation guard, an append-only invariant.

### P2 — Interfaces over examples

> **Rule:** Communicate output shape by pointing at a schema or template file, not by embedding a filled-in sample run.

Verbatim worked examples and console transcripts are the largest single source of dead weight in skill bodies. A named template with named sections and field constraints carries the same information in a fraction of the tokens and cannot drift from the real contract, because it *is* the contract.

Two exceptions, both narrow: a short output template inline is the most reliable way to pin a format (§3.5), and an example is load-bearing when the syntax itself is the hard part (diagram grammars, unusual file formats). Load-bearing examples belong in a `references/` file read on demand, not in the always-loaded body.

### P3 — Progressive disclosure

> **Rule:** Keep `SKILL.md` under ~500 lines and ~5,000 tokens. Detail beyond that moves to `references/`, `scripts/`, or `assets/`, loaded only when the relevant step runs.

The body keeps: frontmatter, the workflow skeleton, gotchas, the output contract, and pointers. See §2.4 for the loading model and §3.6 for how to split.

### P4 — Single source of truth

> **Rule:** Any instruction block that appears in two or more skills or agents is extracted to exactly one file and referenced from both.

Duplication is not merely a token cost. Every copy is a divergence waiting to happen, and the divergence usually surfaces as a broken handoff — one skill suggesting a command the other's own validation rejects.

### P5 — Schemas over prose specs

> **Rule:** Every artifact a skill produces or consumes has a named schema file, and skills reference it by path rather than describing the format in prose.

When a contract changes, the schema changes and no skill body needs editing. This applies to *every* handoff artifact, including the machine-readable frontmatter that hooks and scripts parse.

### P6 — Verify, don't trust

> **Rule:** Every skill that produces an artifact validates that artifact before reporting success. Every skill that executes a plan runs the plan's own validation commands.

A verification loop is a repeating cycle where the agent checks its own work — tests, linters, custom checks — and fixes what fails before moving on. A "done" claim with no executed check is a defect, not a status. §6 gives the placement rules.

### P7 — Add what the agent lacks; omit what it knows

> **Rule:** For each piece of content, ask "would the agent get this wrong without this instruction?" If no, cut it. If unsure, test it.

Skills should carry project conventions, domain procedures, non-obvious edge cases, and the specific tools to use. They should not explain what a PDF is, how HTTP works, or what a database migration does. If the agent already handles the whole task well without the skill, the skill is not adding value — measure this (§10) rather than assuming it.

---

## 2. Skill anatomy and specification conformance

### 2.1 Directory structure

A skill is a directory containing at minimum a `SKILL.md`:

```
skill-name/
├── SKILL.md          # Required: frontmatter + instructions
├── scripts/          # Optional: executable code the agent runs
├── references/       # Optional: documentation the agent reads on demand
├── assets/           # Optional: templates, images, data files
└── evals/            # Optional: test cases for iteration (§10)
```

The optional directories are conventions with distinct purposes, and mixing them up defeats progressive disclosure:

| Directory | Contains | Loaded |
|---|---|---|
| `scripts/` | Executable code — self-contained or with documented dependencies, helpful error messages, graceful edge-case handling | Executed, not read into context |
| `references/` | Detailed technical reference, format specs, domain-specific files (`api-errors.md`, `schema.md`) | Read on demand, when the body says to |
| `assets/` | Templates, diagrams, lookup tables, schemas — static resources | Read or copied when needed |

> **Rule 2.1:** Keep individual reference files focused and small; the agent loads a whole file, so a 900-line `REFERENCE.md` defeats the purpose of having moved it out of the body.

### 2.2 Frontmatter

Specification fields:

| Field | Required | Constraints |
|---|---|---|
| `name` | Yes | 1–64 chars; lowercase `a-z`, `0-9`, hyphens only; no leading/trailing hyphen; no consecutive hyphens; must match the parent directory name |
| `description` | Yes | 1–1024 chars, non-empty; states what the skill does **and** when to use it |
| `license` | No | License name or reference to a bundled license file; keep it short |
| `compatibility` | No | ≤500 chars; environment requirements (intended product, system packages, network access). Most skills do not need it |
| `metadata` | No | Arbitrary string→string map for client-specific properties; use reasonably unique key names |
| `allowed-tools` | No | Space-separated pre-approved tools, e.g. `Bash(git:*) Bash(jq:*) Read`. Experimental; support varies by implementation |

Claude Code adds harness-specific keys on top of the spec — invocation control (`disable-model-invocation`, `user-invocable`), execution mode (`context: fork`, `agent:`, `background:`), `argument-hint`, and skill-scoped `hooks:`. These are covered in §4.3, §5.1, and §8.5.

> **Rule 2.2:** Frontmatter states identity and triggering only. It never restates body instructions and never lobbies for invocation ("this is the best skill for…").

### 2.3 `name` and `description`

`name` must match its directory. `PDF-Processing`, `-pdf`, and `pdf--processing` are all invalid.

`description` carries the entire triggering burden (§4). A good one names both function and trigger conditions:

```yaml
# Poor
description: Helps with PDFs.

# Good
description: >
  Extracts text and tables from PDF files, fills PDF forms, and merges
  multiple PDFs. Use when working with PDF documents or when the user
  mentions PDFs, forms, or document extraction.
```

### 2.4 Progressive disclosure: the three loading levels

Agents pull in detail only as the task calls for it:

| Level | What loads | Budget |
|---|---|---|
| 1. Metadata | `name` + `description` for **every** installed skill, at startup | ~100 tokens per skill |
| 2. Instructions | The full `SKILL.md` body, once the skill activates | <5,000 tokens, <500 lines recommended |
| 3. Resources | Files in `references/`, `scripts/`, `assets/` | Only when the body directs the agent to them |

> **Rule 2.3:** Level 1 is multiplied across every installed skill; treat description length as a shared budget, not a private one.

> **Rule 2.4:** Tell the agent *when* to load each level-3 file, not merely that it exists. "Read `references/api-errors.md` if the API returns a non-200 status" is actionable; "see `references/` for details" is not, and the agent will either ignore it or load everything.

### 2.5 File references

> **Rule 2.5:** Reference bundled files by **relative path from the skill root** (`references/schema.md`, `scripts/validate.py`), never by absolute path. Keep references one level deep — the body points at a reference; a reference should not point at a chain of further references.

Script invocations in code blocks are also relative to the skill root, including inside `references/*.md`, because the agent runs commands from there.

### 2.6 Validation

> **Rule 2.6:** Every skill passes a mechanical frontmatter/naming check before it ships. The reference implementation is `skills-ref validate ./my-skill` ([skills-ref](https://github.com/agentskills/agentskills/tree/main/skills-ref)); wire it into CI so a malformed skill cannot merge.

Mechanical validation covers frontmatter validity and naming conventions. It does **not** cover the things that actually break skills in practice, so pair it with these checks — all of them scriptable:

- Every path referenced in the body exists (`references/…`, `scripts/…`, `assets/…`).
- Every command shown in the body is runnable as written (no placeholder flags, no unpinned tool the environment lacks).
- Body length is within the P3 budget.
- No two skills in the plugin ship the same instruction block verbatim (P4).
- Any next-step command a skill suggests passes the *target's* own argument validation (§5.2).

---

## 3. Writing the body

### 3.1 Ground it in real expertise

The most common way to produce a useless skill is to ask a model to generate one from its general training knowledge. The result is vague procedure — "handle errors appropriately", "follow authentication best practices" — instead of the specific API patterns, edge cases, and conventions that make a skill worth loading.

Two reliable sources of real material:

**Extract from a hands-on task.** Complete a real task in conversation, then extract the reusable pattern. Pay attention to: the sequence that worked; the corrections you made mid-task ("use X not Y", "check for edge case Z"); the actual input/output formats; and the project facts you had to supply because the agent didn't know them. Those corrections are the skill.

**Synthesize from existing artifacts.** Internal runbooks and style guides, API specs and schemas, code-review comments and issue trackers (they capture recurring reviewer concerns), version-control history — especially patches and fixes, which reveal patterns through what actually changed — and real failure cases with their resolutions.

> **Rule 3.1:** A skill synthesized only from generic public material about its domain is a candidate for deletion. If you cannot point to the project-specific facts it encodes, it has none.

### 3.2 Design coherent units

Scoping a skill is like scoping a function: it should encapsulate a coherent unit of work that composes with other skills. Too narrow and several skills must load for one task, adding overhead and risking conflicting instructions. Too broad and it cannot be activated precisely.

> **Rule 3.2:** One skill, one coherent unit of work. "Query the database and format results" is plausibly one unit; adding database administration to it is not.

### 3.3 Aim for moderate detail

Exhaustive skills hurt: the agent struggles to extract what's relevant and pursues unproductive paths triggered by instructions that don't apply to the current task. Concise, stepwise guidance with one working example generally outperforms comprehensive documentation.

> **Rule 3.3:** When you find yourself covering every edge case, stop and ask which ones the agent's own judgement handles. Cover the ones it demonstrably gets wrong (§10), and let it judge the rest.

### 3.4 Calibrate control to fragility

Not every part of a skill needs the same prescriptiveness. Match specificity to how fragile the operation is, and calibrate each part independently.

**Give freedom** where multiple approaches are valid and the task tolerates variation. Here, explaining *why* beats rigid directives — an agent that understands the purpose makes better context-dependent decisions:

```markdown
## Code review process

1. Check all database queries for SQL injection (use parameterized queries)
2. Verify authentication checks on every endpoint
3. Look for race conditions in concurrent code paths
4. Confirm error messages don't leak internal details
```

**Be prescriptive** where operations are fragile, consistency matters, or sequence is load-bearing:

````markdown
## Database migration

Run exactly this sequence:

```bash
python scripts/migrate.py --verify --backup
```

Do not modify the command or add additional flags.
````

> **Rule 3.4a:** Provide defaults, not menus. When several tools would work, pick one and mention alternatives as escape hatches — "use `pdfplumber`; for scanned PDFs needing OCR, use `pdf2image` with `pytesseract`" — rather than listing four equal options and forcing the agent to choose on every run.

> **Rule 3.4b:** Favour procedures over declarations. A skill teaches how to approach a *class* of problems, not what to produce for one instance. "Join `orders` to `customers` on `customer_id`, filter `region = 'EMEA'`, sum `amount`" is a specific answer; "read the schema from `references/schema.yaml`, join on the `_id` foreign-key convention, apply the user's filters as WHERE clauses, aggregate and format as a markdown table" is a reusable method. Specific details are fine — output templates, hard constraints like "never output PII", tool-specific commands — as long as the *approach* generalises.

> **Rule 3.4c:** Prefer reasoning-based instructions to absolutes. "Do X, because Y tends to cause Z" is followed more reliably than "ALWAYS do X, NEVER do Y".

### 3.5 Patterns for effective instructions

Reusable structures for skill bodies. Use the ones that fit; no skill needs all of them.

**Gotchas.** Often the highest-value content in a skill: environment-specific facts that defy reasonable assumptions. Not general advice — concrete corrections to mistakes the agent *will* make without being told.

```markdown
## Gotchas

- The `users` table uses soft deletes. Queries must include
  `WHERE deleted_at IS NULL` or results include deactivated accounts.
- The user ID is `user_id` in the database, `uid` in the auth service,
  and `accountId` in the billing API. All three are the same value.
- `/health` returns 200 whenever the web server is up, even with the
  database down. Use `/ready` for full service health.
```

> **Rule 3.5a:** Gotchas live in `SKILL.md`, not in `references/`. The agent must read them *before* hitting the situation, and by definition it cannot recognise the trigger for a non-obvious issue.

> **Rule 3.5b:** Every time you correct an agent mid-task, that correction belongs in the gotchas section. This is the highest-yield form of iterative improvement.

**Output templates.** Agents pattern-match against concrete structures far better than against prose descriptions of a format. Short templates inline; longer or conditional ones in `assets/`, referenced from the body so they load only when needed. (This is P2's narrow exception — a *template* is an interface; a *filled-in sample run* is not.)

**Checklists** for multi-step workflows, especially with dependencies or validation gates:

```markdown
## Form processing workflow

Progress:
- [ ] Step 1: Analyze the form (run `scripts/analyze_form.py`)
- [ ] Step 2: Create field mapping (edit `fields.json`)
- [ ] Step 3: Validate mapping (run `scripts/validate_fields.py`)
- [ ] Step 4: Fill the form (run `scripts/fill_form.py`)
- [ ] Step 5: Verify output (run `scripts/verify_output.py`)
```

**Validation loops.** Do the work, run a validator, fix what fails, repeat until it passes. The validator can be a script, a reference checklist, or a self-check — but the loop must be written down, with an explicit "only proceed when validation passes".

**Plan-validate-execute.** For batch or destructive operations, have the agent emit an intermediate plan in a structured format, validate that plan against a source of truth, and only then execute:

```markdown
1. Extract form fields: `python scripts/analyze_form.py input.pdf` → `form_fields.json`
2. Create `field_values.json` mapping each field name to its intended value
3. Validate: `python scripts/validate_fields.py form_fields.json field_values.json`
4. If validation fails, revise `field_values.json` and re-validate
5. Fill the form: `python scripts/fill_form.py input.pdf field_values.json output.pdf`
```

Step 3 is the whole pattern. The validator compares the plan against the ground truth and emits errors specific enough to self-correct from: *"Field 'signature_date' not found — available fields: customer_name, order_total, signature_date_signed"*.

**Bundled scripts.** When execution traces show the agent independently reinventing the same logic every run — building the same chart, parsing the same format, validating the same output — write it once, test it, and ship it in `scripts/` (§9).

### 3.6 Splitting a large skill

> **Rule 3.6:** When the body exceeds the P3 budget after P1/P2 cleanup, split by *phase*, not by topic. Each extracted file should correspond to a point in the workflow where the agent can be told, in one clause, whether to load it.

Keep in the body: frontmatter, workflow skeleton, gotchas, output contract, pointers with load conditions. Move out: exhaustive format specs, per-error-code tables, rarely-hit edge-case procedures, long templates.

---

## 4. Descriptions and invocation control

### 4.1 How triggering works

At startup the agent loads only each skill's `name` and `description`. When a task matches, it reads the full `SKILL.md`. The description therefore carries the entire triggering burden: too narrow and the skill never fires; too broad and it fires on unrelated work.

One nuance worth designing around: agents typically consult skills for tasks needing knowledge or capability beyond what they can do unaided. A one-step request ("read this PDF") may not trigger a matching skill at all, because basic tools suffice. Descriptions earn their keep on specialised workflows, unfamiliar APIs, and uncommon formats.

### 4.2 Writing descriptions

> **Rule 4.1:** Use imperative phrasing — "Use when…", not "This skill does…". The agent is deciding whether to act.

> **Rule 4.2:** Describe user intent, not implementation. The agent matches against what the user asked for, not against your internals.

> **Rule 4.3:** Be explicit about contexts that don't name the domain: "…even if they don't explicitly mention 'CSV' or 'analysis'." Under-triggering is the more common failure.

> **Rule 4.4:** Stay well inside 1024 characters. Descriptions grow during optimisation; check the limit each time.

For skills with side effects, the description is also a safety surface — an eager description ("even if they don't say 'commit' explicitly") on a skill that performs git operations invites autonomous, unrequested side effects.

### 4.3 Invocation classes

Skills and slash commands are the same mechanism in Claude Code; *who may invoke them* defines the role. Two verified frontmatter switches:

- `disable-model-invocation: true` — user-only. Never auto-triggers, and its description stays out of the model's context entirely.
- `user-invocable: false` — agent/chain-only. Hidden from the `/` menu; invoked by the model via the Skill tool or preloaded into an agent.

| Class | Frontmatter | Invoked by | Typical members |
|---|---|---|---|
| **Command** | `disable-model-invocation: true` | A person, deliberately | Lifecycle steps; anything touching version control; anything expensive |
| **Chain/agent skill** | `user-invocable: false` | Another skill or an agent | Subroutines of a larger workflow |
| **Open skill** | neither (default) | Either | Skills whose whole point is natural-language triggering |

> **Rule 4.5:** Every skill declares its class explicitly. A skill whose invocation performs side effects the user did not just ask for — version-control operations, file deletion, bulk writes, anything outward-facing — is always a Command.

> **Rule 4.6:** A Chain/agent skill cannot set `disable-model-invocation: true`; that would block the Skill tool that chains it. Its only defence against spurious mid-conversation triggering is a narrowly scoped description, which makes description hygiene part of invocation-control design rather than a nicety.

### 4.4 Testing whether a description triggers

Descriptions are the one part of a skill you can test cheaply and objectively.

Build ~20 realistic eval queries, 8–10 `should_trigger: true` and 8–10 `false`:

```json
[
  { "query": "I've got a spreadsheet in ~/data/q4_results.xlsx with revenue in col C and expenses in col D — can you add a profit margin column and highlight anything under 10%?", "should_trigger": true },
  { "query": "whats the quickest way to convert this json file to yaml", "should_trigger": false }
]
```

Vary positives along phrasing (formal, casual, typo-laden), explicitness (naming the domain vs. describing the need), detail (terse vs. context-heavy), and complexity (single-step vs. the task buried in a longer chain). The most informative positives are those where the skill helps but the connection isn't obvious from the query — if the query already asks for exactly what the skill does, any description passes.

The most valuable negatives are **near-misses** that share keywords but need something else: for a CSV-analysis skill, *"update the formulas in my Excel budget spreadsheet"* (spreadsheet, but editing) and *"write a python script that reads a csv and uploads rows to postgres"* (CSV, but ETL). *"Write a fibonacci function"* tests nothing.

Add realism: file paths, personal context ("my manager asked me to…"), real column and company names, abbreviations, occasional typos.

> **Rule 4.7:** Model behaviour is nondeterministic. Run each query ~3 times and score a **trigger rate**; a positive passes above ~0.5, a negative below it. A single run is an anecdote.

> **Rule 4.8:** Split the query set ~60/40 into train and validation, keep the split fixed, and drive changes only from train failures. Select the final description by *validation* pass rate — the best iteration is often not the last one.

When revising: broaden if positives fail, add explicit boundaries if negatives fire. Do not paste keywords from failed queries into the description — that is overfitting; identify the general category those queries represent instead. If several incremental edits don't move the numbers, try a structurally different framing. Five iterations is usually enough; if nothing improves, suspect the queries rather than the description.

---

## 5. Composition

### 5.1 Choosing an execution mode

> **Rule 5.1:** Choose the lightest mode that satisfies the context constraint.

1. **Inline** (default) — intermediate output is small and the user should watch it unfold.
2. **`context: fork`** — run the skill in a subagent (`agent: <type>` picks the shell, `background: true` parallelises). Use when the work bloats context and only the *result* matters: reviews, debugging, doc scans, analysis sweeps. A forked skill receives only its `SKILL.md` as prompt, so it must be self-contained: everything it needs arrives via arguments or files it reads itself.
3. **Spawn an agent** — the work needs a *role* with its own tool restrictions, model choice, or memory, or several roles must run in parallel (§7).
4. **Chain skills** — sequential verified handoffs where each link is independently useful (§6).

> **Rule 5.2:** Skill-to-skill invocation via the Skill tool works but is an undocumented pattern; prefer `context: fork` where isolation is acceptable. Where a same-context chain is genuinely required — the caller must see the callee's working state — state the dependency in *both* skills' bodies so the coupling is visible to whoever edits either one.

### 5.2 Contracts, not prose

> **Rule 5.3:** Every handoff between steps is (a) an artifact file conforming to a named schema, plus (b) an explicit next-step contract: the exact command to run next, with arguments in the grammar that command actually validates.

Part (b) is where workflows quietly break. A step that ends with "next, run `/plan <slug>`" when `plan` validates a free-text description is a broken contract today and a broken pipe the moment an agent follows it unsupervised.

> **Rule 5.4:** Adopt one argument convention across a workflow and state it in `argument-hint`. Prefer passing a work-item identifier that each step resolves itself over passing different path shapes to different steps.

> **Rule 5.5:** Use the harness's path variables — the skill's own resource directory for bundled files, the project directory for project paths — rather than assuming the current working directory. A skill invoked from a subdirectory must still work.

### 5.3 Dynamic context injection

Claude Code skills can use `` !`command` `` preprocessing to inject live state (current branch, directory listing, task status) into the prompt at invocation time.

> **Rule 5.6:** State a skill always needs at startup is injected via preprocessing, not gathered by tool calls in the skill's first phase. It is cheaper, deterministic, and cannot be skipped.

---

## 6. Verification loops

Four placements. Which one a check gets is a design decision per check, not a style preference.

| Placement | Use when | Typical examples |
|---|---|---|
| **Standalone** | Cross-cutting, doesn't apply every time; each invocation is a turn someone must remember to take | Drift analysis, documentation audits |
| **Embedded** | The check belongs to exactly one producing workflow | Schema self-checks in the skill that writes the artifact; running a plan's own validation commands |
| **Chained** | Several verified handoffs run end-to-end; a habit becomes a contract | review → fix → re-review |
| **Hook** | The check is mechanical and must run outside model context every time | Lint/test on edit; completion gates (§8) |

Promote standalone → embedded/chained when you find yourself running it after every change. The cost of chaining is token spend, so test a chain before relying on it broadly.

> **Rule 6.1:** Every producing step ends with an embedded check of its own artifact — required sections present, referenced files exist, line ranges within file bounds, commands in validation fields actually runnable — written as a distinct final phase with a pass/fail report. Never leave it for the next step to discover.

> **Rule 6.2:** Build-class skills execute the plan's per-step validation commands after each step, and the acceptance criteria at the end. A build that completes without running the validations the plan wrote for it has not built anything; it has generated code.

> **Rule 6.3:** Chain routing reflects the verdict. If every verdict routes to the same next step, the verdict is decorative.

> **Rule 6.4:** Re-verification after a fix uses the *same* checker that produced the findings. A specialist's findings are not re-checked by a generalist.

> **Rule 6.5:** Deterministic checks — anything an exit code can decide — belong in hooks, not prose. Prose verification is reserved for judgement calls a script cannot make.

Rule 6.5 has teeth because of a specific platform capability: `SubagentStop` hooks can block an agent's completion with exit code 2. When an implementation agent reports done, a hook can run the project's tests and refuse the completion if they fail — verification the model cannot skip, hallucinate, or talk its way past.

---

## 7. Agents (subagents)

An agent is the right unit when the work needs a **role**: its own tool allowlist, its own model tier, its own isolated context, or parallel instances.

> **Rule 7.1:** An agent definition specifies a role, a tool allowlist, and an output contract. The tool allowlist is a safety boundary, not documentation — a review-only agent that can `Write` will eventually write.

> **Rule 7.2:** Assign model tiers deliberately: expensive models for architecture, review, and synthesis; cheap fast models for mechanical roles (formatting, extraction, single-file lookups). Record the reason in the agent file so the choice survives review.

> **Rule 7.3:** An agent receives everything it needs through its prompt and the files it reads. It cannot see the parent conversation, so any step that depends on ambient main-session context is not yet agent-ready.

> **Rule 7.4:** Two agents that must produce interchangeable output share one schema file (P5). "Maintains an identical output format" as a prose promise between two files is a divergence that has already happened.

> **Rule 7.5:** Fan out to parallel agents when subtasks are independent and each returns a small result. Fan-out is a context-management technique — if each agent returns a large payload, you have moved the bloat rather than removed it.

> **Rule 7.6:** Start every new capability as a skill — it is cheaper, visible, and user-invocable. Introduce an agent only when you can name which of the four pressures it relieves — context isolation, tool restriction, model tiering, or parallelism — and record that reason in the agent file. When a skill grows a phase that reads far more than it returns, that phase is the next agent: carve it out, give its return value a schema (Rule 7.4), and let the skill go back to being the thin thing that knows the order of operations.

---

## 8. Hooks

### 8.1 Distribution: plugin-registered, not copied

Plugin hooks auto-register via `hooks/hooks.json` (or a `hooks` key in the plugin manifest), with script paths resolved through the plugin-root variable.

> **Rule 8.1:** Hooks every consumer should have ship with the plugin and reference scripts via the plugin-root variable. Copy-and-merge installers fossilise scripts in consuming projects — installed copies never receive plugin updates — and usually assume the current working directory is the project root. Reserve installer flows for genuinely project-local opt-ins.

### 8.2 Output channels are per-event, and most are silent

| Event | How output reaches the model |
|---|---|
| `UserPromptSubmit`, `SessionStart` | plain stdout on exit 0 **is** injected as context |
| `PostToolUse` | plain stdout is transcript-only (user-visible, model-invisible); to reach the model, emit JSON `{"hookSpecificOutput": {"additionalContext": "..."}}`, capped at 10,000 chars |
| `PreToolUse` | exit 2 blocks the tool call; stderr goes to the model |
| `SubagentStop` | exit 2 blocks completion; stderr goes back to the agent |

> **Rule 8.2:** Every hook is written against the actual output channel of its event, and documents in-file which channel it uses and why. A `PostToolUse` linter printing plain stdout is a placebo: the model never sees the errors it found.

### 8.3 Deterministic context injection

A recurring high-value pattern: inject curated project knowledge into context at prompt time, without an LLM in the loop. A `UserPromptSubmit` command hook matches the prompt against an author-curated vocabulary declared in the knowledge base's frontmatter, extracts the matching sections by line range into a fixed character budget, and emits them as additional context.

Three properties make this safe:

- **Exact matching only.** Fuzzy matching fails toward *wrong* context; exact matching fails toward *silence*. Recall gaps become authoring bugs (a missing synonym in the curated vocabulary), which are auditable, rather than algorithm bugs, which are not.
- **Range validation at index-build time.** Verify end-of-range against file length and never extract from inside frontmatter. Stale ranges silently poison context, which makes the writing skills' own range verification (Rule 6.1) load-bearing.
- **Bounded and deduplicated.** A hard character cap, a ranked cutoff, and session-level dedupe so the same sections aren't re-injected every turn.

> **Rule 8.3:** Context-injection hooks are deterministic: no LLM calls, no fuzzy matching, silent when unsure. The knowledge base's frontmatter is the matching interface, and whatever writes that frontmatter verifies it at write time.

### 8.4 Abstract the project's commands

Hooks and gates need to run "the project's tests / lint / build" without knowing the stack.

> **Rule 8.4:** One resolution contract, used by every hook and gate: named environment variables if set; otherwise a documented project-config fallback; otherwise exit 0 silently. No hook hardcodes a package manager or test runner. Re-deriving these commands in each hook produces a plugin that only works on one ecosystem.

### 8.5 Where hooks may be attached

Verified platform behaviour: **`hooks`, `mcpServers`, and `permissionMode` in *agent* frontmatter are silently ignored for plugin-distributed agents** — a deliberate security measure.

> **Rule 8.5:** For plugins, verification hooks live at **plugin level** (`hooks/hooks.json`, matcher-scoped — e.g. `SubagentStop` matching a specific agent) or at **skill level** (`hooks:` in `SKILL.md` frontmatter, active for that skill's duration). Any design that depends on agent-frontmatter hooks will silently do nothing.

### 8.6 Scope hooks narrowly

> **Rule 8.6:** A hook's matcher is as narrow as its purpose. A hook that fires where it contradicts the target's own contract — injecting "consult the knowledge base" into an agent whose body forbids reading it — is mis-scoped by definition. Per-session behaviours key on the session, not on a once-ever flag file.

---

## 9. Scripts

Bundle a script when logic is reused, fragile to get right in one shot, or better verified than described. Reference an existing package directly (`uvx`, `npx`, `pipx`, `go run`) when it already does the job — with the version pinned and prerequisites stated in the body or in `compatibility`.

Prefer self-contained scripts that declare their own dependencies inline (PEP 723 for Python run under `uv run`; `npm:`/`jsr:` specifiers for Deno; pinned imports for Bun; `bundler/inline` for Ruby) so there is no separate install step.

The agent reads stdout and stderr to decide what to do next, which makes interface design the important part:

> **Rule 9.1:** Never prompt interactively. Agents run in non-interactive shells; a script that blocks on a TTY prompt hangs indefinitely. Take all input via flags, environment variables, or stdin, and fail with a message naming the missing flag and its valid values.

> **Rule 9.2:** Document the interface in `--help` — description, flags, and usage examples. That output *is* how the agent learns the script; keep it concise, because it lands in the context window.

> **Rule 9.3:** Write errors that shape the next attempt: what went wrong, what was expected, what to try. `Error: --format must be one of: json, csv, table. Received: "xml"` costs one turn; `Error: invalid input` costs several.

> **Rule 9.4:** Emit structured data (JSON/CSV/TSV) on stdout and diagnostics on stderr, so the agent gets clean parseable output and standard tools can consume it.

> **Rule 9.5:** Be idempotent ("create if not exists", since agents retry), support `--dry-run` for destructive operations, use distinct documented exit codes per failure type, and bound output size — many harnesses truncate beyond 10–30K characters. Default to a summary with `--offset`/`--limit`, or require `--output <file>` for large results.

> **Rule 9.6:** List available scripts in `SKILL.md` with a one-line purpose each, then show the exact invocation at the step that uses them.

---

## 10. Evaluating and iterating

Triggering evals (§4.4) tell you whether a skill fires. Output evals tell you whether it helps.

**Test cases.** A prompt (realistic, the kind someone would actually type), an expected output in plain language, and optional input files. Start with 2–3 — don't over-invest before the first results. Vary phrasing and detail, include at least one boundary condition, and use realistic context; "process this data" tests nothing.

**Run with and without.** Each case runs twice: once with the skill, once without it (or against the previous version, snapshotted before editing). Without a baseline you cannot tell whether the skill is contributing or the model was going to do that anyway. Start each run from a clean context — a fresh subagent or a separate session — so the skill's own instructions are the only thing steering it. Record tokens and duration per run.

**Assertions,** written *after* the first round of outputs, because you often don't know what good looks like until you've seen bad. Good ones are verifiable and specific: "the output file is valid JSON", "the chart has labeled axes", "the report includes at least 3 recommendations". Weak ones are vague ("the output is good") or brittle ("uses exactly the phrase 'Total Revenue: $X'"). Not everything needs an assertion — style, visual design, and whether the output "feels right" are for human review.

**Grading.** Record PASS/FAIL with concrete evidence quoting the output, never an opinion. Use scripts for mechanical checks (valid JSON, row counts, file exists) — more reliable than model judgement and reusable across iterations. Require evidence for a PASS: a section titled "Summary" containing one vague sentence is a FAIL.

**Aggregate into a delta.** Per configuration, report pass rate, time, and tokens; the delta between with-skill and without-skill is the decision. +50 points of pass rate for +13 seconds is worth it; +2 points for double the tokens is not.

**Read the patterns, not just the mean:**

- Assertions that pass in *both* configurations tell you nothing and inflate the with-skill number — remove or replace them.
- Assertions that fail in both mean the assertion is broken, the case is too hard, or you're checking the wrong thing.
- Assertions that pass only with the skill are where the value is — understand *which* instruction caused it.
- High variance across runs means the eval is flaky or the instructions are ambiguous enough to be read differently each time.
- Time/token outliers: read the transcript and find the bottleneck.

> **Rule 10.1:** Read execution traces, not just final outputs. Wasted agent effort has three usual causes, each with a different fix: instructions too vague (the agent tries several approaches before one works), instructions that don't apply to the current task (it follows them anyway), or too many options with no clear default.

> **Rule 10.2:** Generalise every fix. The skill runs on prompts you never tested; a patch aimed at one failed case is technical debt.

> **Rule 10.3:** Cutting can improve a skill. If pass rates plateau while rules accumulate, the skill is over-constrained — remove instructions and check whether results hold. If transcripts show unnecessary validation or unneeded intermediate outputs, delete the instructions that caused them.

Stop iterating when reviewer feedback is consistently empty or improvements stop being meaningful — typically after a handful of passes, though even a single execute-then-revise cycle noticeably improves quality.

---

## 11. Human-in-the-loop, and the path to autonomy

Most workflows start with a person at each stage: the human provides input, the model augments it, the human reviews the output. That contract is worth stating explicitly rather than leaving it implicit in prose.

> **Rule 11.1:** Name the sanctioned pause points for the workflow, and let everything else run to completion. A skill must not pause mid-phase to confirm something objectively determinable, and must not end a phase asking "shall I continue?" when the workflow already defines what comes next. Pause where a *decision* is genuinely the human's: direction, approach approval, verdicts, irreversible or outward-facing operations.

> **Rule 11.2:** At every pause point, present three things: the artifact path, the verification result, and the exact next command. The human's review is only meaningful if verification already ran — they should be checking judgement, not syntax.

Handing steps to autonomous agents later requires no redesign if five things are already true, and is unsafe if they are not:

1. **Machine-checkable contracts** (P5, Rule 5.3) — an agent cannot read the room; it can only validate an artifact against a schema and act on the result.
2. **Gates that don't rely on the model's honesty** (Rules 6.2, 6.5) — an autonomous loop with self-reported success compounds errors instead of catching them.
3. **Declared invocation control** (§4.3) — before agents drive, every skill must already say who may call it, or autonomy means anything can call anything.
4. **Truthful routing** (Rule 6.3) — chain edges must encode real verdicts before an agent follows them unsupervised.
5. **Isolated, self-contained steps** (Rules 5.1, 7.3) — a step depending on ambient session context cannot be handed to an agent.

> **Rule 11.3:** No autonomy work begins on a step whose contracts and gates aren't in place. Autonomy amplifies whatever verification culture exists.

---

## 12. Convergent ecosystem patterns

Independent, widely-used `.claude` collections — Anthropic's own skills repo, large community workflow plugins, and multi-hundred-skill agent catalogues — converge on the same structural ideas regardless of scale:

- **Progressive-disclosure skill folders.** `SKILL.md` plus optional `references/`, `scripts/`, `assets/`, each skill self-contained in its directory. Universal.
- **Frontmatter minimalism.** `name` and a description stating function *and* trigger; nothing else unless required.
- **Deterministic hooks as the verification layer.** Matcher-scoped hooks across multiple event types with exit-code gating — runtime enforcement outside model context that the model cannot hallucinate past.
- **A bounded, curated channel for persistent knowledge.** Session-start or prompt-time injection of a *ranked, capped* selection of accumulated knowledge, rather than dumping a knowledge base into context.
- **Commands as thin shims over skills.** New workflow logic lands in skills; commands are entry points. Invocation-control frontmatter (§4.3) expresses the same idea without parallel directories.
- **Tiered model assignment and tool allowlists** in agent definitions, as cost control and safety boundary respectively.

Two patterns worth adopting *selectively*:

- **Always-on skill consultation** ("check for a relevant skill before any task") suits toolbox-style collections, but is the wrong default when skills have side effects. Explicit invocation classes beat ambient triggering there.
- **Automatic knowledge extraction and self-modification** (agents clustering their own observations into new skills) scales knowledge capture at the cost of a human ever having approved what entered the knowledge base. Adopt it only once the gates in §11 exist.

Scale itself is not the pattern to copy. A single coherent chain with twenty skills beats a catalogue of two hundred for any workflow that actually has a spine.
