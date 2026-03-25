``` mermaid 
flowchart TD
    subgraph ALWAYS["Always Available"]
        direction TB
        STATUS(["/status"])
        SCRATCH[("Scratch Memory\n.dev/slug/scratch.md")]
        HOOK{{"Hook: auto-load\nrelevant .ai-docs"}}
    end

    subgraph KB["Knowledge Base Management"]
        direction TB
        INIT(["/init-docs"])
        DRIFT(["/drift-check"])
        AIDOCS[(".ai-docs/\nKnowledge Base")]
        INIT_AG["doc-extractor\n+ document-writer"]
        DRIFT_AG["drift-analyzer"]
        INIT --> INIT_AG --> AIDOCS
        DRIFT --> DRIFT_AG --> AIDOCS
    end

    subgraph FL["Feature Lifecycle  .dev/slug/"]
        direction TB
        ENTRY_A(["/brainstorm\nvague idea"])
        ENTRY_B(["/plan\ndetailed requirements"])
        RES_AG["brainstorm-challenger\n+ arbiter"]
        PLAN_AG["plan-writer + arbiter"]
        BRAINSTORM_OUT[("brainstorm.md")]
        PLAN_OUT[("plan.md")]
        BUILD(["/build"])
        REVIEW(["/review"])
        REV_AG["code-reviewer"]
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
        PLAN_OUT --> BUILD
        BUILD --> REVIEW --> REV_AG --> DECISION
        DECISION -->|No| COMPLETE
        DECISION -->|Yes| REVIEW_FIX --> ITER
        ITER -->|Yes| REVIEW
        ITER -->|No| ESCAPE
        COMPLETE --> TRIAGE --> TRIAGE_AG
    end

    AIDOCS -->|queried automatically| HOOK
    HOOK -.->|injects context| FL
    STATUS -.->|inspects| FL
    STATUS -.->|inspects| KB
    SCRATCH -.->|captured throughout| FL
    TRIAGE_AG -->|promotes insights| AIDOCS
```