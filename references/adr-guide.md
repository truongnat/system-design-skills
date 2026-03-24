# Architecture Decision Records (ADR) Guide

Use this file to force the AI to output architecture decision records when making major changes.

## 📝 ADR Template (MUST follow this structure)

```markdown
# ADR [Number]: [Decision Title]

- **Date:** [YYYY-MM-DD]
- **Status:** [Proposed / Accepted / Superseded]
- **Deciders:** [User, AI Assistant]

### Context
Describe the current problem. Why is this decision necessary? What are the constraints?

### Decision
We will choose [Tech/Architecture]. Detail the implementation.

### Options Considered
- **Option A:** [Pros/Cons]
- **Option B:** [Pros/Cons]

### Consequences
- **Positive:** [e.g., Performance boost, cost reduction]
- **Negative:** [e.g., New language learning curve, increased complexity]

### Compliance Check
- [x] Checked Anti-patterns?
- [x] Fits the required Scale?
```

---

## 🚦 When to write an ADR?
The AI should automatically suggest an ADR when:
1. **Choosing a new Database** (SQL vs. NoSQL).
2. **Choosing a Language/Runtime** (Node vs. Go vs. Bun).
3. **Changing the Communication Style** (REST vs. gRPC vs. GraphQL).
4. **Changing the Caching/Storage Strategy** (Redis vs. CDN).
5. **Selecting Cloud Provider / Hosting.**

---

## 🔴 ADR Management
- Save files in the `docs/adr/` directory.
- Filename format: `0001-choice-of-database.md`.
- Old ADRs replaced by new ones must be updated to **Superseded** status and link to the new ADR.
