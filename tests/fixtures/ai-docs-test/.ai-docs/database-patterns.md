---
title: "Database Patterns"
domain: "database"
patterns:
  - "database-queries"
  - "connection-pooling"
  - "migration-strategy"
  - "orm-patterns"
keywords:
  - "postgresql"
  - "sql"
  - "transaction"
  - "index"
  - "schema"
sections:
  - name: "Query Optimization"
    line_start: 30
    line_end: 65
    summary: "Database query optimization patterns and index strategy"
  - name: "Migration Workflow"
    line_start: 67
    line_end: 100
    summary: "Schema migration workflow with rollback support"
---

# Database Patterns

## Query Optimization

Queries should use proper indexing...

## Migration Workflow

Migrations follow a forward-only pattern with rollback scripts...
