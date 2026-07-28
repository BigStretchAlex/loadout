``` mermaid 
flowchart TD
    subgraph ALWAYS["Always Available"]
        direction TB
        STATUS(["/status"])
        SCRATCH[("Scratch Memory\n.dev/slug/scratch.md")]
        HOOK{{"Hook: UserPromptSubmit\nscan .ai-docs/ topics"}}
        PLAN_HOOK{{"Hook: SubagentStop\nplan-mode rescan"}}
    end

    subgraph RULES["Project Rules"]
        direction TB
        CREATE_RULES(["/create-rules"])
        UPDATE_RULES(["/update-rules"])
        RULES_DIR[(".claude/rules/\ncommon/ + per-language")]
        CREATE_RULES -->|bootstrap| RULES_DIR
        UPDATE_RULES -->|distill + maintain| RULES_DIR
    end

    subgraph KB["Knowledge Base Management"]
        direction TB
        INIT(["/init-docs"])
        UPDATE_DOCS(["/update-docs"])
        DRIFT(["/drift-check"])
        AIDOCS[(".ai-docs/\nKnowledge Base")]
        INIT_AG["doc-extractor\n+ document-writer"]
        UPDATE_AG["doc-scanner\n+ doc-updater"]
        DRIFT_AG["drift-analyzer"]
        INIT --> INIT_AG --> AIDOCS
        UPDATE_DOCS --> UPDATE_AG --> AIDOCS
        DRIFT --> DRIFT_AG --> AIDOCS
    end

    subgraph FL["Feature Lifecycle  .dev/slug/"]
        direction TB
        ENTRY_A(["/brainstorm\nvague idea"])
        ENTRY_B(["/plan\ndetailed requirements"])
        ENTRY_TDD(["/tdd-plan\nplan + TDD Gates"])
        EXPRESS(["/perform-task\nexpress lane — prompt is the plan"])
        RES_AG["brainstorm-challenger\n+ arbiter"]
        PLAN_AG["plan-writer + arbiter"]
        GATE_AG["code-quality\nTDD gate review"]
        BRAINSTORM_OUT[("brainstorm.md")]
        PLAN_OUT[("plan.md")]
        BUILD(["/build"])
        TDD_BUILD(["/tdd-build\nfail-first gates"])
        TASKS_OUT[("tasks.md")]
        REVIEW(["/review"])
        REV_AG["code-reviewer\nor typescript-reviewer"]
        DECISION{Issues?}
        REVIEW_FIX(["/review-fix"])
        ITER{Iter <= 3?}
        ESCAPE["Escape hatch"]
        COMPLETE(["Feature Complete"])
        TRIAGE(["/triage"])
        TRIAGE_AG["document-writer"]

        ENTRY_A --> RES_AG --> BRAINSTORM_OUT
        BRAINSTORM_OUT -->|feeds into| ENTRY_B
        ENTRY_B --> PLAN_AG --> PLAN_OUT
        ENTRY_TDD --> PLAN_AG
        PLAN_AG -->|tdd path| GATE_AG --> PLAN_OUT
        PLAN_OUT --> BUILD
        PLAN_OUT -->|TDD Gates present| TDD_BUILD
        BUILD -->|progress + resume| TASKS_OUT
        TDD_BUILD -->|progress + resume| TASKS_OUT
        EXPRESS -->|builds inline| REVIEW
        BUILD --> REVIEW
        TDD_BUILD --> REVIEW
        REVIEW --> REV_AG --> DECISION
        DECISION -->|No| COMPLETE
        DECISION -->|Yes| REVIEW_FIX --> ITER
        ITER -->|Yes| REVIEW
        ITER -->|No| ESCAPE
        COMPLETE --> TRIAGE --> TRIAGE_AG
    end

    AIDOCS -->|queried automatically| HOOK
    AIDOCS -->|rescanned on explore| PLAN_HOOK
    HOOK -.->|injects context| FL
    PLAN_HOOK -.->|injects new context| FL
    RULES_DIR -.->|Applicable Rules\nheadings via doc-scanner| FL
    RULES_DIR -.->|testing rules\ninjected into executor| BUILD
    STATUS -.->|inspects| FL
    STATUS -.->|inspects| KB
    SCRATCH -.->|captured throughout| FL
    TRIAGE_AG -->|promotes insights| AIDOCS
```
