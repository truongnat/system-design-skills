---
name: system-design-overview
version: 2.6.0
last_updated: 2026-03
notes: Comprehensive coverage of AI engineering, platform, compliance, data, edge, finops, testing + GraphQL + AI Agent Security
expires: 2027-03
freshness_notes: >
  Review lại khi: React major release, PostgreSQL major release,
  Node.js LTS thay đổi, CVE mới trong JWT/OAuth, Next.js App Router thay đổi lớn,
  AI agent security vulnerabilities mới, GraphQL spec updates.
description: >
  Comprehensive reference for system design across UI design systems, frontend web,
  mobile apps, backend HLD, low-level design, and cross-cutting concerns. Use this skill
  whenever the user asks about architecture decisions, rendering strategies, state management,
  design tokens, component libraries, mobile architecture, offline-first, API design,
  database selection, caching strategies, scalability patterns, security, observability,
  CI/CD, or testing. Trigger on: "how should I design X", "which is better X or Y",
  "best practice for Z", "what should I use for [auth/cache/queue/state/mobile/rendering]",
  "edge case in X", "trade-off between X and Y", "how to handle X at scale",
  "is X deprecated", "should I use X or Y". Always use for fullstack and system
  architecture questions — contains detailed edge cases, decision trees, anti-patterns,
  and step-by-step guidance beyond training data.
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

## Routing — đọc file nào

| Domain | File | Trigger |
|--------|------|---------|
| Deployment & Release | `references/deployment-release.md` | "deploy an toàn", "CI/CD", "canary release", "blue green", "rollback" |
| SaaS & Multi-tenancy | `references/auth-multi-tenancy.md` | "thiết kế SaaS", "phân quyền", "auth", "tenant", "multi-tenant" |
| SRE & Incident | `references/sre-incident-response.md` | "hệ thống sập", "giám sát", "alert", "post-mortem", "SLO/SLA" |
| Edge Cases | `references/edge-case-analysis.md` | "trường hợp biên", "edge case", "lỗi hệ thống", "race condition", "failure mode" |
| Diagrams | `references/documentation-diagrams.md` | "vẽ sơ đồ X", "Mermaid", "C4 model", "Sequence diagram" |
| Migration | `references/migration-strategy.md` | "nâng cấp hệ thống", "chuyển sang microservices", "migrate database" |
| ADR (Records) | `references/adr-guide.md` | "ghi lại quyết định", "ADR", "tại sao chọn X?", "lưu trữ kiến trúc" |
| Tech Selection | `references/tech-selection-strategy.md` | "nên dùng tool gì?", "so sánh X và Y", "stack hiện đại cho Z", "framework nào tốt nhất?" |
| Quick decisions | `references/decision-trees.md` | "dùng X hay Y?", "nên chọn gì?" |
| Anti-patterns | `references/anti-patterns.md` | "có nên dùng X?", "tại sao X bị lỗi?" |
| Deprecated patterns | `references/deprecated.md` | "X còn dùng được không?" |
| Sizing & numbers | `references/sizing-guide.md` | latency, throughput, thresholds, cost |
| AI Engineering | `references/ai-engineering.md` | RAG, LLM, agents, MCP, LLMOps, vector DB |
| Platform Engineering | `references/platform-engineering.md` | IDP, golden paths, Backstage, GitOps, DevEx |
| UI Design System | `references/ui-design-system.md` | tokens, component library, theming |
| Frontend Web | `references/frontend.md` | rendering, state, MFE, performance |
| Mobile App | `references/mobile.md` | RN/Flutter/Native, offline, push |
| Backend / HLD | `references/backend-hld.md` | API, DB, cache, queue, scale |
| Low-level Design | `references/lld.md` | patterns, CQRS, data model, algorithms |
| Testing (fundamentals) | `references/testing-fundamentals.md` | Unit, integration, E2E, contract, performance, visual, mobile, security, frontend |
| Testing (automation) | `references/testing-automation.md` | TDD, BDD, mutation, property-based, chaos, a11y, cross-browser, fuzz, strategy, flaky |
| Data Pipelines | `references/data-pipelines.md` | ETL/ELT, CDC, Spark, dbt, Iceberg, feature store, streaming |
| Compliance | `references/compliance.md` | GDPR, HIPAA, PCI-DSS, data residency, PII, retention |
| Edge & WASM | `references/edge-wasm.md` | Cloudflare Workers, Durable Objects, WebAssembly, WASI, edge patterns |
| FinOps | `references/finops.md` | Cloud cost, unit economics, reserved instances, right-sizing, tagging |
| Cross-cutting | `references/cross-cutting.md` | Security, observability, CI/CD, SRE |

Đọc `decision-trees.md` TRƯỚC nếu user đang chọn giữa các options.
Đọc `anti-patterns.md` nếu user đang hỏi về một approach cụ thể.
Đọc nhiều files nếu câu hỏi span nhiều domain.

---

## 3 câu hỏi đầu tiên (mọi system)

1. **Scale** — DAU? QPS? read-heavy hay write-heavy? realtime hay batch?
2. **Team** — size? monolith hay microservices? web-only hay cả mobile?
3. **Constraints** — deadline, budget, existing stack, compliance (GDPR, PCI)?

---

## Latency benchmarks (nhớ thuộc)

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

## Checklist severity convention (dùng trong toàn bộ skill)

```
🔴 MUST     — block ship nếu thiếu, security risk hoặc data loss
🟠 SHOULD   — fix trước production, acceptable với documented exception
🟡 NICE     — tech debt, ảnh hưởng DX hoặc perf nhẹ, fix dần
```
