# Decision Trees — Quick Picks

Dùng file này trước khi đọc reference files chi tiết.
Format: câu hỏi → answer trong ≤ 4 bước.

---

## Choosing a database

```
Cần ACID + complex JOIN?
  YES → PostgreSQL ← default cho mọi project mới 2025
  NO  ↓

Schema flexible / nested / document-based?
  YES → MongoDB (general) | Firestore (realtime sync mobile/web)
  NO  ↓

Key-value lookup, extreme speed, simple structure?
  YES → Redis (in-memory, sub-ms) | DynamoDB (managed, serverless-friendly)
  NO  ↓

Time-series (metrics, IoT, events, logs)?
  YES → TimescaleDB (PostgreSQL extension, best of both worlds)
       | InfluxDB (purpose-built)
       | Prometheus (metrics-only, pull model)
  NO  ↓

Full-text search?
  YES → Meilisearch (simple, fast setup) | Typesense (lightweight)
       | Elasticsearch (powerful, complex ops)
       ⚠ KHÔNG thay thế primary DB — sync từ primary via CDC/webhook
  NO  ↓

Graph / multi-hop relationship traversal?
  YES → Neo4j | Amazon Neptune
  NO  → PostgreSQL vẫn là đáp án đúng
```

---

## Choosing a rendering strategy (web)

```
App sau login, SEO không quan trọng, heavy interactivity?
  YES → CSR (Vite)
  NO  ↓

Content personalized theo user (cart, feed, profile)?
  YES → SSR (Next.js App Router / Remix)
  NO  ↓

Content cập nhật thường (< 1 lần/giờ), cần SEO?
  YES → ISR (Next.js revalidate: 60)
  NO  ↓

Content gần như không đổi (docs, marketing, landing)?
  YES → SSG (Astro, Next.js getStaticProps)
  NO  → ISR với revalidate ngắn (30–60s)

Đặc biệt:
  Nhiều data sources per page, muốn shell hiện nhanh?
  → Streaming SSR + React Suspense
  
  Content-heavy site, ít JS, tốt nhất cho Core Web Vitals?
  → Astro (Islands Architecture)
```

---

## Choosing a cache strategy

```
Data thay đổi khi nào?
  Không bao giờ / rất hiếm → CDN cache + long TTL (1h–1d)
  Thỉnh thoảng, eventual consistency OK → Cache-aside + TTL
  Thường xuyên, cần consistency cao → Write-through
  Write-heavy, eventual consistency OK → Write-behind / write-around
  Real-time (stock, live score, chat) → Không cache / TTL rất ngắn (1–5s)

Cache ở đâu?
  Static assets (JS, CSS, images) → CDN
  API responses, computed data → Redis (application cache)
  DB query results → Redis hoặc in-process cache
  Rendered HTML → CDN edge + ISR
  Sessions → Redis với TTL
```

---

## Scaling decision

```
Có performance problem không?
  YES → MEASURE FIRST: EXPLAIN ANALYZE query, check CPU/mem metrics
  
Query chậm?
  → Thêm index → giải quyết 80% cases
  
DB connections exhausted?
  → PgBouncer connection pooling → giải quyết mà không đổi code
  
Read-heavy (ratio > 10:1)?
  → Read replicas → horizontal scale reads
  
Table > 100M rows hoặc > 100GB?
  → Table partitioning (RANGE/HASH) trong single DB
  → Không cần shard, joins vẫn work, foreign keys vẫn work
  
Server CPU/memory maxed out?
  → Vertical scale trước (đơn giản, không cần code change)
  → Horizontal scale sau (stateless app servers)
  
Write throughput maxed (> 50K TPS sustained)?
  → Sharding — LAST RESORT, không thể undo
```

---

## Choosing state management (React)

```
Data từ API?
  → React Query / TanStack Query
  ← KHÔNG nhét vào Zustand/Redux
  ← KHÔNG dùng useEffect + fetch

Form state (> 3 fields)?
  → React Hook Form + Zod validation

Filters, pagination, sort, tab active?
  → URL state (useSearchParams)
  ← Lợi ích: shareable, bookmarkable, back button works

State chỉ dùng trong 1 component?
  → useState / useReducer

State cần share giữa nhiều component xa nhau?
  → Zustand (simple, recommended)
  → Jotai (atomic, derived state)
  → Redux Toolkit (large team, complex, cần devtools mạnh)
```

---

## Choosing API style

```
Public API, external developers, simple CRUD?
  → REST

Multiple clients với data requirements khác nhau (mobile vs web)?
  → GraphQL
  ⚠ Nhớ: DataLoader để tránh N+1, persisted queries cho production

Internal service-to-service, performance critical?
  → gRPC (binary protocol, bidirectional streaming)
  ← Cần proxy (grpc-gateway) để expose ra browser

Fullstack TypeScript, type safety end-to-end?
  → tRPC (no code generation, types shared trực tiếp)

Real-time, server push?
  → Server-Sent Events (1 chiều, đơn giản hơn WebSocket)
  → WebSocket (2 chiều, chat, collaborative)
```

---

## Choosing deployment strategy

```
Team nhỏ, app đơn giản, downtime chấp nhận được?
  → Recreate (stop old, start new)
  
Không muốn downtime, rollback cần vài phút?
  → Rolling update (default K8s)
  ⚠ Old và new version chạy song song → DB migration phải backward compat
  
Cần rollback tức thì (< 1 phút)?
  → Blue/Green
  ⚠ Double infrastructure cost trong quá trình deploy
  
Cần detect lỗi sớm với risk thấp nhất?
  → Canary (5% → 25% → 50% → 100%)
  ⚠ Phức tạp hơn, cần metrics-based auto-rollback
  
Cần decouple deploy từ release?
  → Feature flags (LaunchDarkly, Unleash, Flagsmith)
```

---

## Choosing a mobile approach

```
Team đã biết React/TypeScript, muốn share logic với web?
  → React Native
  
Cần UI nhất quán tuyệt đối iOS/Android, heavy animation?
  → Flutter
  
Finance/banking, deep hardware access (ARKit, HealthKit)?
  → Native (Swift / Kotlin)
  
App đơn giản, không cần App Store, offline cơ bản OK?
  → PWA

Cross-platform desktop (Mac, Windows, Linux)?
  → Electron (web tech) | Tauri (Rust + web, nhẹ hơn) | Flutter
```

---

## Choosing auth strategy

```
Web app, session-based, monolith?
  → Session + httpOnly cookie (Redis session store)

Stateless API, microservices, mobile?
  → JWT (RS256) — short-lived (15m) + refresh token

User login với Google/GitHub/SSO?
  → OAuth 2.0 Authorization Code + PKCE
  → KHÔNG tự implement — Auth0, Clerk, Supabase Auth, Keycloak

Service-to-service (không có user)?
  → OAuth 2.0 Client Credentials grant
  → API key nếu external, JWT nếu internal

Mobile app?
  → JWT + refresh token lưu trong Keychain/Keystore (KHÔNG AsyncStorage)
```

---

## Choosing a message queue

```
Event streaming, audit log, replay cần thiết, high throughput?
  → Kafka
  
Task queue (email, report, image processing), flexible routing?
  → RabbitMQ
  
Simple async tasks, đã dùng AWS?
  → SQS (standard hoặc FIFO)
  
Lightweight, đã có Redis?
  → Redis Streams hoặc Bull/BullMQ (Node.js)
  
Serverless, event-driven workflows?
  → AWS EventBridge | Google Pub/Sub | Azure Service Bus
```

---

## Choosing an observability stack

```
Self-hosted, open source?
  → Prometheus + Grafana (metrics)
  → Loki + Grafana (logs)
  → Jaeger hoặc Tempo (traces)
  → OpenTelemetry để instrument (vendor-neutral)

Managed, all-in-one, không muốn ops overhead?
  → Datadog (best-in-class, expensive)
  → New Relic (similar)
  → Grafana Cloud (cheaper, open source base)

AWS-native?
  → CloudWatch (metrics + logs) + X-Ray (traces)
  → Không tốt bằng dedicated tools nhưng integrated

Startup, budget hạn chế?
  → Grafana Cloud free tier + Sentry (errors) + UptimeRobot (uptime)
```

---

## Choosing test type for each situation

```
Đang test logic thuần (function → result, no I/O)?
  → Unit test (Jest/Vitest)

Đang test API endpoint với DB?
  → Integration test (Supertest + Testcontainers)
  ← Không mock DB trong integration test

Đang test user flow phức tạp qua nhiều pages?
  → E2E test (Playwright)
  ← Chỉ cho critical paths, không mọi feature

Đang test service A gọi service B không break?
  → Contract test (Pact)

Đang test hệ thống chịu được 1000 concurrent users?
  → Load test (k6)

Đang test component UI không bị vỡ layout?
  → Visual regression (Chromatic / Playwright screenshot)

Đang test security vulnerabilities tự động?
  → SAST trong CI (Semgrep) + dependency audit (npm audit)
```

## Choosing test frameworks

```
JavaScript/TypeScript:
  Unit/Integration:  Vitest (2024 recommended) | Jest (legacy)
  Component:         @testing-library/react
  API mock:          MSW (Mock Service Worker)
  E2E:               Playwright (recommended) | Cypress
  Load:              k6 | Artillery

Python:
  Unit/Integration:  pytest + pytest-asyncio
  API:               httpx + pytest
  E2E:               Playwright (python)
  Load:              Locust

Go:
  Unit:              testing (built-in) + testify
  E2E:               Playwright

Java:
  Unit:              JUnit 5 + Mockito + AssertJ
  Integration:       Spring Boot Test + Testcontainers
  E2E:               Playwright (java)

Mobile React Native:
  Unit/Component:    Jest + @testing-library/react-native
  E2E:               Maestro (simpler) | Detox (more control)

Mobile Flutter:
  Unit/Widget:       flutter test
  Integration:       integration_test package
  E2E:               Maestro | Patrol
```

---

## Chọn Testing Approach

```
Có BA/QA non-technical tham gia viết test cases?
  YES → BDD (Gherkin + Cucumber/Playwright)
  NO  → Developer-owned tests (unit + integration + E2E)

Code coverage < 60% và không biết test gì?
  → Mutation testing (Stryker) để tìm test gaps

Testing algorithm / data transformation phức tạp?
  → Property-based testing (fast-check) để tìm edge cases

Test fail intermittently (flaky)?
  → Quarantine ngay, track flaky rate
  → Fix root cause: timing? shared state? external dependency?

Test suite chậm > 10 phút?
  → Parallelize (Vitest threads, Playwright --workers)
  → Split: unit (fast, mọi PR) + E2E (slow, merge to main only)
  → Check slow tests: npx vitest run --reporter=verbose | sort by duration

Muốn test UX mà không test implementation?
  → @testing-library (không test state, không test CSS classes)
  → Test: accessible roles, text content, user interactions

Test đang verify behavior hay implementation?
  Implementation: expect(component.state.count).toBe(1) → BAD
  Behavior:       expect(screen.getByText('Count: 1')).toBeVisible() → GOOD
```

## Choosing test data strategy

```
Test cần isolated, không ảnh hưởng lẫn nhau?
  → DB transaction rollback per test (fastest)
  → Hoặc: truncate + seed per test

Test cần realistic data volume?
  → Anonymized production snapshot (weekly refresh)
  → KHÔNG dùng real PII trong test DB

Test cần generate nhiều variations?
  → Factory với faker.js (không hardcode fixtures)
  → Property-based testing cho extreme variations

Test sensitive data (payment, PII)?
  → Synthetic data hoàn toàn
  → Không bao giờ real card numbers dù test cards

Staging environment có đủ data để test không?
  → Seeding script từ factory definitions
  → Cần referential integrity khi seed (users → orders → items)
```

---

## Choosing an AI engineering approach

```
Muốn thêm AI vào product?
  Cần generate text/answer từ existing knowledge base?
    YES → RAG
    NO  → LLM API wrapper hoặc fine-tuned model

RAG: corpus size?
  < 10K docs:   pgvector + OpenAI embeddings
  10K–1M docs:  Pinecone, Weaviate, Qdrant
  > 1M docs:    Milvus, sharded vector DB

RAG: query type?
  FAQ / exact match → BM25 keyword search đủ
  Semantic meaning → Dense vector search
  Mixed (most cases) → Hybrid: BM25 + dense + reranker

Cần agent hay RAG?
  One-shot Q&A từ documents → RAG
  Multi-step task, cần tools, cần actions → Agent
  Mix: Agentic RAG (agent orchestrate retrieval + tools)

Latency requirement?
  < 500ms: Skip reranker, prompt caching, streaming response
  < 2s:    Standard pipeline + reranker
  Async:   Full pipeline, GraphRAG, complex multi-hop

Dùng fine-tuning hay RAG?
  Data thay đổi thường xuyên → RAG (fine-tuning stale nhanh)
  Cần behavior/style/format specific → Fine-tuning
  Cần both knowledge + behavior → RAG + fine-tuning combine
```

## Choosing a platform engineering approach

```
Team size?
  < 50 engineers:    Shared docs + runbooks + simple CI templates đủ
                     Chưa cần IDP/Backstage
  50–200 engineers:  SaaS IDP (Port, Cortex) hoặc managed Backstage
  > 200 engineers:   Build on Backstage hoặc full custom IDP

Đang gặp vấn đề gì?
  "Mất nhiều ngày để setup new service" → Golden path cho new service
  "Không biết ai owns service X" → Software catalog (Backstage)
  "Deploy phức tạp, mỗi team làm khác nhau" → Standardized CI/CD golden path
  "Dev phải mở ticket để get resources" → Self-service provisioning

Build Backstage từ scratch hay mua?
  Have 3+ FTE để maintain, unique requirements → Build từ scratch
  Want speed, không muốn ops → Managed Backstage (Roadie) hoặc SaaS (Port)
  Already Atlassian shop → Compass

GitOps: ArgoCD vs Flux?
  Cần visual UI, multi-cluster management → ArgoCD
  Prefer CLI-first, lightweight, composable → Flux
  Both: 93% adoption intent 2025, cả hai đều valid
```

---

## SRE & reliability

```
SLO bị breach, what to do?
  Error budget > 50% consumed this month?
    YES → Slow down feature releases, focus reliability sprint
  Error budget < 10% remaining?
    YES → Freeze all non-critical deploys, war room
  SLA at risk?
    YES → Incident response immediately

Đang thiết kế reliability cho new service?
  Define SLI trước: What metric chứng minh service healthy?
    Availability: % successful requests
    Latency: % requests < X ms (p99)
    Error rate: % requests không có 5xx
  Set SLO: SLO = SLA + buffer (SLO > SLA)
  Calculate error budget: 1 - SLO
  Set burn rate alerts: page at 14.4x burn over 1h

Có quá nhiều toil?
  > 50% engineer time on toil → Halt new features
  Identify top 3 toil sources by time spent
  Automate top source first (highest ROI)
  Re-measure after 1 sprint
```

## Service mesh

```
Có nên dùng service mesh không?
  Số lượng microservices?
    < 5 services:    Không cần — library-level retry/circuit breaker đủ
    5–15 services:   Cân nhắc Linkerd (lighter) hoặc Cilium
    > 15 services:   Istio hoặc Linkerd đáng đầu tư

  Security requirements?
    mTLS bắt buộc giữa services → Cần service mesh
    Audit trail cho service-to-service calls → Cần service mesh

  Team có K8s expertise chưa?
    NO → Master K8s trước. Service mesh trên nền K8s không vững = disaster

Chọn service mesh:
  Full-featured, battle-tested: Istio
  Lightweight, simpler ops:    Linkerd (Rust, no sidecar overhead như Istio)
  No-sidecar (eBPF):           Cilium Service Mesh
  AWS-native:                  AWS App Mesh
```

## Domain-driven design

```
Có nên dùng DDD không?
  Business domain có complex rules? (pricing, workflow, compliance)
    NO → CRUD app → Simple layered architecture đủ
    YES → Consider DDD

  Team size?
    < 3 devs → Overhead không xứng
    > 5 devs → DDD giúp module boundaries clear

  System lifespan?
    < 2 years → Skip DDD
    > 5 years → DDD pays off

Đang design aggregate boundaries?
  Rule 1: 1 aggregate = 1 transaction
  Rule 2: Keep aggregates small (1-4 entities)
  Rule 3: Reference other aggregates by ID only (không by object reference)
  Rule 4: Cross-aggregate communication → domain events

Bounded Context size?
  Hướng: 1 team = 1 bounded context = 1 deployable unit
  Conway's Law: System architecture mirrors communication structure
  Tách BC khi: Different teams, different rate of change, different scaling needs
```

---

## Choosing a data pipeline approach

```
Muốn analyze production data?
  Real-time (seconds)?     → Kafka → Flink → ClickHouse/Druid
  Near real-time (minutes)?→ CDC (Debezium) → Kafka → streaming → DW
  Daily batch?             → Airbyte/Fivetran → raw → dbt → marts

Data size?
  < 10GB:    PostgreSQL analytics queries đủ (EXPLAIN ANALYZE trước)
  < 100GB:   dbt + BigQuery/Snowflake
  > 100GB:   Spark + data lake (Iceberg on S3)

Transform tool?
  SQL-centric team → dbt (ELT, version-controlled SQL)
  Python-heavy / ML → Spark
  Real-time →         Flink / Kafka Streams

Data lake format?
  2025 default → Apache Iceberg (ACID, time travel, schema evolution)
  Databricks native → Delta Lake
  CDC with upserts → Iceberg MERGE INTO or Delta Lake MERGE
```

## Choosing a compliance approach

```
Handling EU user data?
  YES → GDPR applies regardless of where company is located
  → Implement: lawful basis, consent management, data subject rights

Healthcare data in the US?
  YES → HIPAA applies
  → Sign BAA với tất cả vendors, PHI encryption mandatory

Processing payment cards?
  YES → PCI-DSS applies
  → Use Stripe/Adyen tokenization → minimize PCI scope dramatically
  → PCI Level? > 6M transactions/year → Level 1 (strictest)

Multiple regulations?
  → Start với controls satisfying all (encryption, access control, audit logs)
  → 1 implementation → satisfies GDPR + HIPAA + PCI-DSS simultaneously
  → Then add regulation-specific requirements
```

## Choosing a cloud cost approach

```
Highest ROI first?
  Step 1: Dev/staging auto-shutdown → immediate 40-60% non-prod savings
  Step 2: Terminate idle resources (EC2 < 5% CPU, unused EBS, old snapshots)
  Step 3: Right-size with AWS Compute Optimizer recommendations
  Step 4: S3 lifecycle policies for logs/backups → Glacier
  Step 5: gp3 storage migration for RDS
  Step 6: Reserved Instances for stable baseline

Purchase model?
  Runs 24/7, predictable? → Reserved 1yr (40% off)
  Batch, fault-tolerant?  → Spot (90% off)
  Variable?               → On-Demand or Compute Savings Plans

Unit economics healthy?
  Cost per user increasing as scale grows → Architecture has linear cost problem
  Cost per user decreasing as scale grows → Healthy economies of scale
  Track monthly: Total infra cost / MAU
```
