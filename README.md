# System Design Overview — Skill

**Version:** 2.5.0 | **Updated:** March 2025 | **Score:** 87.8/100 | **Lines:** 15,164

A comprehensive, production-grade reference skill for system design — covering the full stack from UI design tokens to distributed infrastructure, AI engineering, platform engineering, compliance, and cloud economics.

---

## What this skill does

When installed, this skill gives Claude access to a structured knowledge base that Claude reads selectively based on your question. Rather than answering from training data alone, Claude consults the relevant reference file and provides deeper, more accurate, more current answers — including edge cases, trade-offs, anti-patterns, and decision frameworks.

**Trigger phrases** (Claude auto-loads this skill when you ask about):
- `"how should I design X"`
- `"which is better X or Y"`
- `"best practice for Z"`
- `"what should I use for [auth / cache / queue / state / mobile / rendering]"`
- `"is X deprecated"` / `"how do I migrate from X to Y"`
- `"how to handle X at scale"` / `"edge cases in X"`
- `"what are the trade-offs between X and Y"`

---

## Coverage

### 10 domain files — reference content

| File | Topics | Lines |
|------|---------|-------|
| `ai-engineering.md` | RAG pipeline, vector DBs, agents, MCP, LLMOps, multi-modal, fine-tuning, prompt engineering | 1,424 |
| `testing-fundamentals.md` | Unit, integration, E2E, contract, performance, visual regression, mobile, security, component | 1,440 |
| `testing-automation.md` | TDD, BDD/Gherkin, mutation testing, property-based, chaos, a11y automation, flaky tests, test strategy | 1,259 |
| `cross-cutting.md` | Security (JWT/OAuth/CVEs), observability, CI/CD, SRE/SLOs, Zero Trust, SBOM/SLSA | 1,272 |
| `data-pipelines.md` | ETL/ELT, CDC/Debezium, Spark, Flink, dbt, Iceberg, orchestration, data catalog, Reverse ETL | 1,112 |
| `lld.md` | Design patterns, CQRS/Saga, DDD, Clean/Hexagonal architecture, Event Storming, API contracts | 992 |
| `frontend.md` | Rendering (CSR/SSR/SSG/RSC), state, MFE, performance, Web Workers, PWA, Server Actions | 894 |
| `mobile.md` | React Native, Flutter, Native iOS/Android, offline-first, push notifications, profiling, background | 817 |
| `compliance.md` | GDPR, HIPAA, PCI-DSS, SOC 2 Type II, EU AI Act 2025, data residency, SBOM | 731 |
| `edge-wasm.md` | Cloudflare Workers, Durable Objects, WebAssembly, WASM Component Model, Miniflare testing | 721 |
| `platform-engineering.md` | IDP, golden paths, Backstage, GitOps, DevEx metrics, multi-cluster, Crossplane | 676 |
| `finops.md` | Unit economics, right-sizing, RI/Spot strategy, K8s cost, serverless pricing, GCP/Azure | 660 |
| `backend-hld.md` | DB selection, caching, message queues, API design, scaling, service mesh, PACELC | 832 |
| `ui-design-system.md` | Design tokens, component library, theming, a11y, motion tokens, Style Dictionary v4 | 580 |

### 5 utility files — quick lookup

| File | Purpose |
|------|---------|
| `decision-trees.md` | 15+ flowcharts: "should I use X or Y?" answered in 3 steps |
| `anti-patterns.md` | 80+ anti-patterns with severity (🔴 CRITICAL / 🟠 RELIABILITY / 🟡 QUALITY) |
| `deprecated.md` | Deprecated patterns + migration code from old → new |
| `sizing-guide.md` | Latency benchmarks, throughput numbers, SLA tables, GPU/ML sizing, cost ballpark |
| `SKILL.md` | Entry point: routing table, 3-question framework, latency cheat sheet |

---

## How it works

Claude uses a **routing table** in `SKILL.md` to decide which file(s) to read. For a question like *"should I use GraphQL or REST?"*, Claude reads `decision-trees.md` and `backend-hld.md`. For *"what's wrong with my JWT setup?"*, Claude reads `anti-patterns.md` and `cross-cutting.md`. Multiple files can be read simultaneously for cross-domain questions.

```
User question
    │
    ▼
SKILL.md (routing table)
    │
    ├── decision-trees.md    ← "which X or Y?"
    ├── anti-patterns.md     ← "is X a problem?"
    ├── deprecated.md        ← "is X still used?"
    ├── sizing-guide.md      ← "how many? how fast?"
    └── domain files         ← deep dives per topic
         ├── ai-engineering.md
         ├── backend-hld.md
         ├── frontend.md
         ├── ...
```

---

## Key features

### Tiered checklists — every file

Every domain file ends with a checklist sorted by severity:

```
🔴 MUST     — block ship if missing (security risk, data loss)
🟠 SHOULD   — fix before production (acceptable with documented exception)
🟡 NICE     — tech debt, fix over time
```

### Decision trees — not prose

Instead of "here are 5 considerations to weigh...", the decision trees give direct answers:

```
RAG: corpus size?
  < 10K docs   → pgvector + OpenAI embeddings
  10K–1M docs  → Pinecone, Weaviate, Qdrant
  > 1M docs    → Milvus, sharded vector DB
```

### Anti-patterns with severity

Every anti-pattern has a severity label, making it clear what's critical vs cosmetic:

```
🔴 CRITICAL   ❌ Store CVV or full magnetic stripe (PCI-DSS)
🟠 RELIABILITY ❌ Queue consumer not idempotent
🟡 QUALITY     ❌ key={index} in React list
```

### Current as of 2025

Includes recent developments:
- MCP (Model Context Protocol) — 97M monthly SDK downloads by Feb 2026
- EU AI Act — passed Aug 2024, enforcement 2025-2026
- Next.js App Router (RSC, Server Actions, PPR)
- WASM Component Model — W3C standard 2024
- Voyage-3-large embedding benchmarks (Feb 2026)
- CodePush deprecation (March 2025)
- React Native New Architecture (v0.76+)

---

## Sample questions this skill handles well

**Architecture decisions:**
- *"Should I use microservices or a monolith for my new startup?"*
- *"When should I add a message queue vs call services directly?"*
- *"We're hitting DB performance limits — what's the right order of optimizations?"*

**AI Engineering:**
- *"How do I build a RAG system that doesn't hallucinate?"*
- *"When should I fine-tune vs use RAG vs prompt engineer?"*
- *"What are the security risks in an agentic AI system using MCP?"*

**Testing:**
- *"What's the right testing strategy for a microservices backend?"*
- *"How do I fix flaky tests in our CI pipeline?"*
- *"When does BDD make sense and when is it overkill?"*

**Frontend:**
- *"Should I use SSR, SSG, or CSR for this e-commerce product page?"*
- *"What's causing our INP score to be above 200ms?"*
- *"How do I implement offline support in a Next.js app?"*

**Compliance:**
- *"We have EU users — what do we technically need to implement for GDPR?"*
- *"What does SOC 2 Type II actually require us to build?"*
- *"How do we minimize our PCI-DSS scope?"*

**Scaling:**
- *"Our PostgreSQL is getting slow — where do I start?"*
- *"When do I actually need to shard a database?"*
- *"How do I estimate if my system can handle 1M users?"*

**Cost:**
- *"Our AWS bill jumped 40% — how do I find and fix it?"*
- *"Should we use Lambda or EC2 for this workload?"*
- *"What's the unit economics calculation for our SaaS?"*

---

## What this skill does NOT cover

- Specific framework tutorials (e.g., "how to set up a Next.js project from scratch")
- Algorithm problem-solving (LeetCode-style)
- Business strategy / product decisions
- Deep ML/AI research (model architecture, training from scratch)
- Vendor-specific ops details (e.g., specific AWS console navigation)
- Extremely niche technologies with no mainstream adoption

---

## Freshness policy

The `SKILL.md` frontmatter includes:
```yaml
expires: 2026-03
freshness_notes: >
  Review when: React major release, PostgreSQL major,
  Node.js LTS change, new JWT/OAuth CVEs, Next.js App Router changes.
```

Review and update annually or after major ecosystem shifts.

---

## Scoring history

| Version | Score | Lines | Key additions |
|---------|-------|-------|---------------|
| 1.0.0   | 65/100 | 3,239 | Initial: HLD, LLD, Frontend, Mobile, UI, Cross-cutting |
| 1.5.0   | 72/100 | 4,779 | Anti-patterns, decision trees, deprecated, sizing guide |
| 2.0.0   | 80/100 | 7,441 | Testing (full), AI engineering, Platform engineering |
| 2.1.0   | 82/100 | 8,864 | Testing split, severity labels, DDD, SRE, service mesh |
| 2.2.0   | 83/100 | 9,791 | Data pipelines, compliance, edge/WASM, FinOps |
| 2.3.0   | 84/100 | 12,102 | Multi-modal AI, SOC2, EU AI Act, Zero Trust, SBOM |
| 2.4.0   | 85/100 | 13,556 | PWA, Web Workers, fine-tuning, orchestration, GPU sizing |
| **2.5.0** | **87.8/100** | **15,164** | Profiling, background tasks, WASM Component Model, migration paths |

---

## Contributing / updating

When updating this skill:

1. **Add content to the relevant reference file** — not to SKILL.md (keep it short)
2. **Follow the format conventions:**
   - Section headers in English
   - Code blocks for concrete examples
   - Checklists use 🔴/🟠/🟡 severity tiers
   - Anti-patterns use ❌ → ✅ format with severity label
3. **Update SKILL.md routing table** if adding a new file
4. **Bump version** in SKILL.md frontmatter
5. **Update `last_updated` and `expires`** fields
6. **Re-run the scoring audit** to measure impact

---

*Built for fullstack engineers who want a senior architect in their pocket.*