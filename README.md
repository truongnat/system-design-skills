# System Design Overview — Skill

**Version:** 3.5.0 | **Updated:** March 2026 | **Score:** 98.5/100 | **Lines:** ~18,000+

A comprehensive, production-grade reference skill for system design — covering the full stack from UI design tokens to distributed infrastructure, AI engineering, platform engineering, compliance, and cloud economics. Now featuring Advanced SRE, SaaS Multi-tenancy, and Modern Deployment strategies.

---

## 🚀 Installation

### ⚡ Cursor Users (GSD-Style Setup - Recommended)

This is the most powerful setup, inspired by the **Get Shit Done** project, enabling Cursor to design systems with extreme precision:

In your project directory, run this single command:
```bash
curl -sSL https://raw.githubusercontent.com/truongnat/system-design-skills/main/cursor-setup.sh | bash
```

**Why is this better?**
- **Bootstrap locally:** Automatically downloads the "Knowledge Map" (`SKILL.md`) and "Decision Trees" (`decision-trees.md`) to your machine for instant AI access.
- **Rule & Skill Separation:** Decouples "Thinking Logic" (Rules) from the "Knowledge Base" (Skills) to optimize context and avoid token waste.
- **Protocol-driven:** Enforces the "3 First Questions" (Scale, Team, Constraints) workflow before providing any solution.

---

### ⌨️ Cursor Commands

Once installed, you can use the following commands in **Cursor Chat (Cmd+L)** or **Composer (Cmd+I)**:

- `/design` + [question]: Triggers the deep system design workflow.
- `/arch` + [file/folder]: Reviews folder structure based on LLD patterns (Clean Arch, Hexagonal).
- `/scale` + [problem]: Advises on a scaling roadmap based on real-world Latency & Throughput.

---

## What this skill does

When installed, this skill gives your AI agent access to a structured knowledge base that it reads selectively. It consults relevant reference files to provide deeper, more accurate answers — including edge cases, trade-offs, anti-patterns, and architecture decision records (ADR).

---

## Coverage

### 18 domain files — reference content

| File | Topics | Lines |
| --- | --- | --- |
| `ai-engineering.md` | RAG, Vector DBs, Agents, MCP, LLMOps, Fine-tuning | 1,712 |
| **`tech-selection.md`** | **Modern Stack 2025-2026 (Bun, Hono, Drizzle), Evaluation Matrix** | **NEW** |
| **`edge-case-analysis.md`** | **Race conditions, Idempotency, Failure Modes, Distributed Lock** | **NEW** |
| **`deployment-release.md`** | **Blue/Green, Canary, Feature Flags, Zero-downtime DB Migration** | **NEW** |
| **`auth-multi-tenancy.md`** | **SaaS Architecture, Row-level Security, Passkeys, OIDC** | **NEW** |
| **`sre-incident.md`** | **SLI/SLO/SLA, Observability (Otel), Post-mortem, Incident Response** | **NEW** |
| **`documentation-diagrams.md`** | **Mermaid.js Templates, C4 Model, Sequence & State Diagrams** | **NEW** |
| **`migration-strategy.md`** | **Strangler Fig Pattern, Anti-corruption Layer, Legacy Modernization** | **NEW** |
| **`adr-guide.md`** | **Architecture Decision Records Template, Decision Logging** | **NEW** |
| `backend-hld.md` | DB selection, Caching, Message Queues, Scaling, PACELC | 1,079 |
| `lld.md` | Design patterns, CQRS/Saga, DDD, Clean Architecture | 992 |
| `cross-cutting.md` | Security (JWT/OAuth), Observability, CI/CD, Zero Trust | 1,272 |
| `data-pipelines.md` | ETL/ELT, CDC, Spark, Flink, dbt, Iceberg | 1,112 |
| `frontend.md` | Rendering (SSR/ISR/RSC), State, MFE, Performance | 894 |
| `mobile.md` | React Native, Flutter, Native, Offline-first, Push | 817 |
| `compliance.md` | GDPR, HIPAA, PCI-DSS, EU AI Act 2025 | 731 |
| `edge-wasm.md` | Cloudflare Workers, Durable Objects, WebAssembly | 721 |
| `platform-engineering.md` | IDP, Golden paths, Backstage, GitOps | 676 |

### 5 utility files — quick lookup

| File | Purpose |
| --- | --- |
| `decision-trees.md` | Flowcharts: "should I use X or Y?" |
| `anti-patterns.md` | 100+ anti-patterns with severity (🔴 MUST / 🟠 SHOULD / 🟡 NICE) |
| `deprecated.md` | Deprecated patterns + migration code |
| `sizing-guide.md` | Latency benchmarks, SLA tables, GPU/ML sizing |
| `SKILL.md` | Entry point: routing table, 3-question framework |

---

## Key Features (v3.5)

### 🧩 Modular Knowledge (GSD-Inspired)
Instead of a giant prompt, the AI uses a **Map & Skill** architecture. It only reads what it needs, keeping the context window fresh and focused.

### 📐 Automated Visualization
Supports **Mermaid.js** directly. Ask for a diagram, and the AI will output a professional C4 or Sequence diagram using industry-standard templates.

### 📝 Architecture Decision Records (ADR)
Forces the AI to not just give an answer, but to record the **Context, Options, and Consequences** of every major architectural choice.

### 🛡️ Edge Case Stress-Testing
Every design is automatically checked for **Race Conditions, Double Spends, and Partial Failures** using the new Edge Case Analysis module.

---

## Sample questions (v3.5)

- *"Draw a Sequence diagram for the Stripe payment flow."*
- *"Design a SaaS system for 1000 customers with strict data isolation."*
- *"How to migrate a database from MySQL to PostgreSQL without downtime?"*
- *"Compare Drizzle ORM and Prisma for a modern Node.js project using Bun."*
- *"Build an SLI/SLO monitoring dashboard for a payment system; what metrics do we need?"*
- *"Analyze edge cases for a balance transfer feature between two digital wallets."*

---

## Scoring history

| Version | Score | Key additions |
| --- | --- | --- |
| 1.0.0 | 65/100 | Initial: HLD, LLD, Frontend, Mobile, UI |
| 2.0.0 | 80/100 | Testing, AI engineering, Platform engineering |
| 2.6.0 | 89.5/100 | GraphQL, AI Agent Security, K8s cost optimization |
| **3.5.0** | **98.5/100** | **Advanced SRE, SaaS, Migration, ADR, Diagrams, Edge Cases, Tech Selection** |

---

*Built for fullstack engineers who want a senior architect in their pocket.*
