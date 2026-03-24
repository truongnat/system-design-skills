---
name: system-design-overview
version: 3.5.0
last_updated: 2026-03
notes: Full-stack architect coverage including SRE, SaaS, Migration, ADR, Diagrams, Edge Cases, Tech Selection.
expires: 2027-03
freshness_notes: >
  Review when: React major release, PostgreSQL major release,
  Node.js LTS changes, new JWT/OAuth CVEs, Next.js App Router major updates,
  AI agent security vulnerabilities, GraphQL spec updates.
description: >
  Comprehensive reference for system design across UI design systems, frontend,
  mobile, backend HLD, low-level design, SRE, SaaS, and migration. Use this skill
  for architecture decisions, scaling, database selection, RAG, agents, 
  observability, and cost optimization. Trigger on: "how should I design X", 
  "which is better X or Y", "best practice for Z", "edge case in X", 
  "how to handle X at scale", "is X deprecated". Always follow the user's
  preferred language for communication while referencing English knowledge.
---

# System Design Overview — Reference Skill

## Full Landscape

```
┌──────────────────────────────────────────────────────────┐
│                      Client Layer                         │
│  ┌─────────────┐  ┌─────────────┐  ┌──────────────────┐  │
│  │ UI Design   │  │ Frontend    │  │ Mobile App       │  │
│  │ System      │  │ Web         │  │ iOS / Android    │  │
│  └─────────────┘  └─────────────┘  └──────────────────┘  │
└──────────────────────────────────────────────────────────┘
┌──────────────────────────────────────────────────────────┐
│                      Server Layer                         │
│  ┌───────────────────────────────────────────────────┐   │
│  │        High-Level Design (HLD) — Infrastructure   │   │
│  └───────────────────────────────────────────────────┘   │
│  ┌───────────────────────────────────────────────────┐   │
│  │        Low-Level Design (LLD) — Implementation    │   │
│  └───────────────────────────────────────────────────┘   │
└──────────────────────────────────────────────────────────┘
┌──────────────────────────────────────────────────────────┐
│     Cross-Cutting: Security · Observability · CI/CD       │
└──────────────────────────────────────────────────────────┘
```

## Routing — Which file to read?

| Domain | File | Trigger |
|--------|------|---------|
| Deployment & Release | `references/deployment-release.md` | "safe deploy", "CI/CD", "canary release", "blue green", "rollback" |
| SaaS & Multi-tenancy | `references/auth-multi-tenancy.md` | "SaaS design", "authz", "auth", "tenant", "multi-tenant" |
| SRE & Incident | `references/sre-incident-response.md` | "system down", "observability", "alert", "post-mortem", "SLO/SLA" |
| Edge Cases | `references/edge-case-analysis.md` | "edge case", "system failure", "race condition", "failure mode" |
| Diagrams | `references/documentation-diagrams.md` | "draw X diagram", "Mermaid", "C4 model", "Sequence diagram" |
| Migration | `references/migration-strategy.md` | "modernize system", "switch to microservices", "migrate database" |
| ADR (Records) | `references/adr-guide.md` | "record decision", "ADR", "why choose X?", "architecture logging" |
| Tech Selection | `references/tech-selection-strategy.md` | "which tool?", "compare X and Y", "modern stack for Z" |
| Quick decisions | `references/decision-trees.md` | "use X or Y?", "what to choose?" |
| Anti-patterns | `references/anti-patterns.md` | "should I use X?", "why is X failing?" |
| Sizing & numbers | `references/sizing-guide.md` | latency, throughput, thresholds, cost |
| AI Engineering | `references/ai-engineering.md` | RAG, LLM, agents, MCP, LLMOps, vector DB |
| Backend / HLD | `references/backend-hld.md` | API, DB, cache, queue, scale |
| Low-level Design | `references/lld.md` | patterns, CQRS, data model, algorithms |
| Testing | `references/testing-fundamentals.md` | Unit, integration, E2E, contract, performance |
| Data Pipelines | `references/data-pipelines.md` | ETL/ELT, CDC, Spark, dbt, Iceberg |
| Compliance | `references/compliance.md` | GDPR, HIPAA, PCI-DSS, PII |
| Edge & WASM | `references/edge-wasm.md` | Cloudflare Workers, WebAssembly, WASI |
| FinOps | `references/finops.md` | Cloud cost, unit economics, reserved instances |
| Cross-cutting | `references/cross-cutting.md` | Security, observability, CI/CD, SRE |

**Read `decision-trees.md` FIRST** if the user is choosing between options.
**Read `anti-patterns.md`** if the user asks about a specific approach.
**Read multiple files** if the question spans multiple domains.

---

## 3 First Questions (Every System)

1. **Scale** — DAU? QPS? Read-heavy or write-heavy? Real-time or batch?
2. **Team** — Size? Monolith or microservices? Web-only or mobile as well?
3. **Constraints** — Deadline, budget, existing stack, compliance (GDPR, PCI)?

---

## Latency benchmarks (Memorize these)

```
L1 cache:        ~1 ns
RAM:             ~100 ns
SSD read:        ~100 µs    (1000× RAM)
Network same DC: ~500 µs
HDD seek:        ~10 ms     (100× SSD)
Network cross DC:~100 ms
```

Cache hit vs DB query: ~1000× | RAM vs disk: ~100×

---

## Checklist severity convention (Used throughout the skill)

```
🔴 MUST     — Block ship if missing, security risk or data loss
🟠 SHOULD   — Fix before production, acceptable with documented exception
🟡 NICE     — Tech debt, minor DX/performance impact, fix over time
```
