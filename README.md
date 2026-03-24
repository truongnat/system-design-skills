# System Design Overview — Skill

**Version:** 3.5.0 | **Updated:** March 2026 | **Score:** 98.5/100 | **Lines:** ~18,000+

A comprehensive, production-grade reference skill for system design — covering the full stack from UI design tokens to distributed infrastructure, AI engineering, platform engineering, compliance, and cloud economics. Now featuring Advanced SRE, SaaS Multi-tenancy, and Modern Deployment strategies.

---

## 🚀 Installation

### ⚡ Cursor Users (GSD-Style Setup - Recommended)

Đây là cách setup mạnh mẽ nhất, lấy cảm hứng từ dự án **Get Shit Done**, giúp Cursor có khả năng thiết kế hệ thống cực kỳ chính xác:

Trong thư mục dự án của bạn, chạy lệnh duy nhất này:
```bash
curl -sSL https://raw.githubusercontent.com/truongnat/system-design-skills/main/cursor-setup.sh | bash
```

**Tại sao cách này tốt hơn?**
- **Bootstrap locally:** Tự động tải "Bản đồ kiến thức" (`SKILL.md`) và "Cây quyết định" (`decision-trees.md`) về máy để AI truy cập tức thì.
- **Rule & Skill Separation:** Tách biệt "Cách tư duy" (Rules) và "Kho tri thức" (Skills) để tối ưu hóa context, tránh lãng phí token.
- **Protocol-driven:** Ép AI phải tuân thủ quy trình "3 câu hỏi đầu tiên" (Scale, Team, Constraints) trước khi đưa ra giải pháp.

---

### ⌨️ Cursor Commands

Sau khi cài đặt, bạn có thể dùng các lệnh sau trong **Cursor Chat (Cmd+L)** hoặc **Composer (Cmd+I)**:

- `/design` + [câu hỏi]: Kích hoạt quy trình thiết kế hệ thống chuyên sâu.
- `/arch` + [file/folder]: Review cấu trúc thư mục dựa trên các pattern LLD (Clean Arch, Hexagonal).
- `/scale` + [vấn đề]: Tư vấn lộ trình nâng cấp hệ thống dựa trên Latency & Throughput.

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

- *"Vẽ cho tôi sơ đồ Sequence cho luồng thanh toán qua Stripe."*
- *"Thiết kế hệ thống SaaS cho 1000 khách hàng, yêu cầu cô lập dữ liệu tuyệt đối."*
- *"Làm thế nào để migrate database từ MySQL sang PostgreSQL mà không dừng hệ thống?"*
- *"So sánh Drizzle ORM và Prisma cho dự án Node.js hiện đại dùng Bun."*
- *"Xây dựng dashboard giám sát SLI/SLO cho hệ thống thanh toán, chúng ta cần những chỉ số gì?"*
- *"Phân tích các edge case cho tính năng chuyển tiền giữa 2 ví điện tử."*

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
