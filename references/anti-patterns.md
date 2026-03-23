# Anti-patterns — NEVER DO THESE

Format: [Severity] ❌ Pattern → Tại sao sai → ✅ Thay bằng

Severity: 🔴 CRITICAL (security/data loss) · 🟠 RELIABILITY (production risk) · 🟡 QUALITY (tech debt/DX)

---

## Auth & Security

🔴 CRITICAL &nbsp; ❌ **Lưu JWT / access token trong `localStorage`**
> XSS có thể đọc và exfiltrate token. `localStorage` accessible qua bất kỳ JS nào chạy trên trang.
✅ `httpOnly` cookie (không accessible qua JS) + `SameSite=Lax`

🔴 CRITICAL &nbsp; ❌ **Không validate `alg` header trong JWT**
> Algorithm confusion attack: attacker đổi `"alg":"RS256"` → `"alg":"HS256"`, sign bằng public key → bypass auth.
✅ `jwt.verify(token, secret, { algorithms: ['RS256'] })` — hardcode danh sách, không đọc từ token.

🔴 CRITICAL &nbsp; ❌ **Không validate `aud` (audience) claim trong microservices**
> Token issue cho Service A có thể dùng được cho Service B → privilege escalation.
✅ Validate: `audience: 'https://api.service-a.example.com'`

🔴 CRITICAL &nbsp; ❌ **Accept `"alg": "none"` trong JWT**
> Token hoàn toàn không có chữ ký → anyone có thể forge.
✅ Reject tất cả token với `alg: none` ở middleware/gateway level.

🔴 CRITICAL &nbsp; ❌ **Hardcode secrets trong source code**
> Secret bị expose qua git history, image layers, logs. Không thể rotate mà không deploy lại.
✅ Environment variables + secret manager (Vault, AWS Secrets Manager, GCP Secret Manager).

🔴 CRITICAL &nbsp; ❌ **Log `Authorization` header, password, hoặc token**
> Credentials leak vào log aggregation system (Datadog, ELK) → readable bởi bất kỳ ai có log access.
✅ Mask trước khi log: `Authorization: Bearer ***`, password: `[REDACTED]`.

🔴 CRITICAL &nbsp; ❌ **String concat trong SQL query**
```sql
-- BAD
query = "SELECT * FROM users WHERE email = '" + email + "'"
-- email = "' OR 1=1 --" → dump toàn bộ table
```
✅ Parameterized queries: `db.query('SELECT * FROM users WHERE email = $1', [email])`

🔴 CRITICAL &nbsp; ❌ **`dangerouslySetInnerHTML` với untrusted content (React)**
> XSS: attacker inject `<script>document.cookie</script>` → chạy trong browser user.
✅ `DOMPurify.sanitize(html)` trước khi render, hoặc render as plain text.

🔴 CRITICAL &nbsp; ❌ **SSRF: fetch URL từ user input không validate**
```
POST /api/fetch { "url": "http://169.254.169.254/latest/meta-data/iam/credentials" }
→ Server fetch AWS metadata → attacker nhận cloud credentials
```
✅ Allowlist domains, block private IP ranges (10.x, 172.16.x, 192.168.x, 169.254.x, 127.x).

🔴 CRITICAL &nbsp; ❌ **Dùng MD5 hoặc SHA-1 để hash password**
> Rainbow table attack. MD5 crack < 1 giây với modern GPU.
✅ `bcrypt` (cost factor 12+) hoặc `argon2id`.

---

## Database

🟠 RELIABILITY &nbsp; ❌ **`SELECT *` trong production queries**
> Fetch dư data, break khi thêm column, index-only scan không work, serialization overhead.
✅ Explicit column list: `SELECT id, name, email FROM users`

🟠 RELIABILITY &nbsp; ❌ **Sharding trước khi thử các bước đơn giản hơn**
> Sharding = irreversible decision, massive complexity, cross-shard JOIN impossible.
✅ Đúng thứ tự: index → connection pool → cache → read replicas → table partitioning → vertical scale → sharding (last resort).

🟠 RELIABILITY &nbsp; ❌ **Dùng auto-increment integer ID làm shard key**
> Hotspot: tất cả writes vào shard "latest". Sequential ID → single shard nhận 100% traffic mới.
✅ `user_id`, `tenant_id`, hoặc consistent hash cho distributed write.

🟠 RELIABILITY &nbsp; ❌ **Không set `LIMIT` trong queries có thể trả về nhiều rows**
> Full table scan, OOM, timeout. 1 query có thể dump toàn bộ DB.
✅ Luôn paginate: `LIMIT 100 OFFSET 0` hoặc cursor-based.

🟠 RELIABILITY &nbsp; ❌ **`OFFSET` pagination trên table lớn**
```sql
SELECT * FROM posts ORDER BY created_at OFFSET 100000 LIMIT 20
-- DB scan 100,000 rows → O(n) performance, chậm dần theo trang
```
✅ Cursor pagination: `WHERE (created_at, id) < ($cursor_ts, $cursor_id) ORDER BY created_at DESC LIMIT 20`

🟠 RELIABILITY &nbsp; ❌ **Không có connection pooling trước DB**
> 100 app instances × 20 connections = 2,000 connections → PostgreSQL max_connections crash.
✅ PgBouncer transaction mode trước DB. Pool size 20–50 connections đến DB là đủ.

🟠 RELIABILITY &nbsp; ❌ **Đọc từ primary DB cho tất cả queries**
> Primary bottleneck khi read:write > 10:1. Primary down → cả reads và writes đều fail.
✅ Route reads sang read replicas. Primary chỉ nhận writes.

🔴 CRITICAL &nbsp; ❌ **DROP COLUMN trong một bước khi đang rolling deploy**
> Old app instances vẫn đang chạy reference column đó → crash ngay lập tức.
✅ Expand-Contract: (1) deploy code không dùng column, (2) verify, (3) DROP column.

🟠 RELIABILITY &nbsp; ❌ **Không có index trên foreign key columns**
> `SELECT * FROM orders WHERE user_id = 123` → full table scan khi không có index.
✅ Index tất cả FK columns và columns thường dùng trong WHERE, JOIN, ORDER BY.

---

## Frontend

🟡 QUALITY &nbsp; ❌ **Nhét server state (API data) vào Redux / Zustand**
> Duplicate caching logic, stale data phức tạp để sync, boilerplate không cần thiết.
✅ React Query / TanStack Query / SWR — thiết kế cho server state, handle cache tự động.

🟡 QUALITY &nbsp; ❌ **`useEffect` để fetch data**
```tsx
// BAD: race condition, no deduplication, no caching, no loading state
useEffect(() => {
  fetch('/api/users').then(r => r.json()).then(setUsers)
}, [])
```
✅ `useQuery` từ React Query. Handle loading, error, cache, background refetch tự động.

🟡 QUALITY &nbsp; ❌ **CSS `background-image` cho LCP element**
> Browser không thể preload background-image. LCP bị delay cho đến khi CSS parse xong.
✅ `<img>` với `priority` prop (Next.js) hoặc `<link rel="preload" as="image">` trong `<head>`.

🟡 QUALITY &nbsp; ❌ **`Date.now()` / `Math.random()` trong render (SSR)**
> Hydration mismatch: server render ra HTML khác client → React warning, layout flash.
✅ `useId()` cho stable IDs. Wrap dynamic values trong `useEffect` / `useState`.

🟡 QUALITY &nbsp; ❌ **Import cả lodash**
```ts
import _ from 'lodash' // BAD: 72KB gzipped vào bundle dù chỉ dùng 1 function
```
✅ `import debounce from 'lodash/debounce'` hoặc native `lodash-es` với tree shaking.

🟡 QUALITY &nbsp; ❌ **Inline object/array trong JSX props mà không memo**
```tsx
// BAD: tạo object mới mỗi render → child luôn re-render
<Child style={{ color: 'red' }} config={{ enabled: true }} />
```
✅ `const style = useMemo(() => ({ color: 'red' }), [])` hoặc define ngoài component.

🟡 QUALITY &nbsp; ❌ **`key={index}` trong list có thể reorder / add / remove**
> React dùng key để match DOM. Index key → wrong element reuse → state bug (input giữ value cũ).
✅ Stable unique key: `key={item.id}`

🟡 QUALITY &nbsp; ❌ **`any` type trong TypeScript**
> Mất type safety, compiler không catch bugs.
✅ `unknown` (type-safe), proper interface, hoặc generic.

---

## Mobile

🔴 CRITICAL &nbsp; ❌ **Lưu token trong `AsyncStorage` (React Native)**
> Không encrypted, accessible nếu device rooted.
✅ `react-native-keychain` (iOS Keychain / Android Keystore).

🟠 RELIABILITY &nbsp; ❌ **Assume network luôn available trong mobile app**
> Mobile network unreliable. App crash hoặc hang vô hạn khi offline.
✅ Handle offline state: show cached data, queue writes, sync khi online lại.

🟡 QUALITY &nbsp; ❌ **`key={index}` trong FlatList**
> Tương tự web — wrong element reuse khi list thay đổi.
✅ `keyExtractor={(item) => item.id}`

🟠 RELIABILITY &nbsp; ❌ **Không cleanup event listeners / subscriptions trong `useEffect`**
```tsx
// BAD: memory leak khi component unmount
useEffect(() => {
  const sub = eventEmitter.addListener('event', handler)
  // thiếu return cleanup!
}, [])
```
✅ `return () => sub.remove()`

🔴 CRITICAL &nbsp; ❌ **Cho phép Universal Links / App Links không validate**
> Malicious app có thể intercept deep links nếu chỉ dùng custom URL scheme (`myapp://`).
✅ Universal Links (iOS) / App Links (Android) với HTTPS domain ownership verification.

---

## API Design

🟡 QUALITY &nbsp; ❌ **Verb trong URL**
```
GET /getUsers      ← BAD
POST /createOrder  ← BAD
DELETE /deletePost ← BAD
```
✅ Noun + HTTP method: `GET /users`, `POST /orders`, `DELETE /posts/:id`

🟠 RELIABILITY &nbsp; ❌ **Return 200 cho tất cả responses kể cả lỗi**
```json
HTTP 200
{ "success": false, "error": "User not found" }  ← BAD
```
> Client không thể dùng HTTP status để detect errors. Logging/monitoring sai.
✅ Đúng HTTP status: 404 Not Found, 400 Bad Request, 500 Internal Server Error.

🟠 RELIABILITY &nbsp; ❌ **Remove field từ API response mà không version**
> Breaking change: client parse `user.name` → field mất → runtime error.
✅ API versioning. Deprecated field giữ lại ít nhất 6 tháng với `Deprecation` header.

🟠 RELIABILITY &nbsp; ❌ **POST endpoint không idempotent khi có thể**
> Network retry → double charge, double order, double email.
✅ `Idempotency-Key` header cho payment, order creation. Server dedup trong Redis 24h.

🔴 CRITICAL &nbsp; ❌ **Expose internal error details trong production**
```json
{ "error": "PG::UniqueViolation: duplicate key value violates unique constraint..." }
← Leak schema, table names, implementation details
```
✅ Generic message cho client: `{ "error": { "code": "CONFLICT", "message": "Email already exists" } }`

---

## Distributed Systems

🟠 RELIABILITY &nbsp; ❌ **Queue consumer không idempotent**
> At-least-once delivery → message có thể đến 2 lần → double processing.
✅ Dedup với Redis SET NX hoặc DB `ON CONFLICT DO NOTHING` dùng `message_id`.

🟠 RELIABILITY &nbsp; ❌ **Không có Dead Letter Queue**
> Failed messages mất forever hoặc retry vô hạn → crash consumer.
✅ Configure DLQ cho mọi queue. Alert khi DLQ > 0.

🟠 RELIABILITY &nbsp; ❌ **Fanout event không có version / schema**
> Consumer A parse event OK, Consumer B parse event fail vì field thay đổi.
✅ Event versioning: `{ "version": "1.2", "type": "order.placed", "data": {...} }`. Schema registry (Avro, Protobuf).

🟠 RELIABILITY &nbsp; ❌ **Distributed lock không có timeout**
```
Lock acquired → process crash → lock never released → deadlock
```
✅ `redis.set(key, 1, NX=True, EX=30)` — luôn có TTL.

🟠 RELIABILITY &nbsp; ❌ **2PC (Two-Phase Commit) cross-service**
> Blocking, single point of failure, performance thảm hại dưới load.
✅ Saga pattern (choreography hoặc orchestration) với compensation transactions.

---

## Testing

🟡 QUALITY &nbsp; ❌ **Mock mọi thứ trong unit tests**
> Tests chỉ verify "function X calls function Y", không catch real bugs. Refactor code → tests fail dù behavior không đổi.
✅ Mock chỉ I/O boundaries (DB, HTTP, filesystem). Dùng in-memory fakes cho domain logic.

🟡 QUALITY &nbsp; ❌ **`await page.waitForTimeout(2000)` trong E2E**
> Flaky: pass khi app fast, fail khi app slow. Làm CI chậm.
✅ `await expect(element).toBeVisible()` hoặc `waitFor({ state: 'visible' })`.

🟡 QUALITY &nbsp; ❌ **`key={index}` trong React list**
> React reuse DOM element sai → state bug (input giữ value cũ khi list reorder).
✅ `key={item.id}` — stable, unique identifier.

🟡 QUALITY &nbsp; ❌ **Snapshot test mọi thứ**
> Developers chỉ `--update-snapshots` khi fail mà không review. Tests không meaningful.
✅ Snapshot chỉ cho complex serialized output. Dùng explicit assertions cho behavior.

🟠 RELIABILITY &nbsp; ❌ **Tests phụ thuộc thứ tự chạy**
> Test 2 pass chỉ khi test 1 đã chạy trước → `--runInBand` dependency, không thể parallelize.
✅ Mỗi test tự setup và teardown. `beforeEach` reset state. `afterEach` cleanup.

🔴 CRITICAL &nbsp; ❌ **Production data trong test database**
> GDPR/HIPAA violation. Data thay đổi → flaky tests.
✅ Synthetic data (faker.js). Anonymized snapshots cho performance tests.

🟠 RELIABILITY &nbsp; ❌ **Không test error paths**
> 100% happy path coverage, 0% error path → bugs đầy khi network fail, DB down, invalid input.
✅ Test: 4xx/5xx responses, timeout, empty state, boundary values, concurrent writes.

🟡 QUALITY &nbsp; ❌ **Hard-coded `sleep` trong load tests**
> Coordinated Omission: client không send khi server slow → undercount real latency.
✅ k6 `constant-arrival-rate` executor: gửi requests theo rate cố định, không phụ thuộc response time.

---

## Testing — Additional

🟡 QUALITY &nbsp; ❌ **Viết test SAU code rồi gọi là TDD**
> Không có Red phase = không drive design từ tests = chỉ là test-after.
✅ Red (fail) → Green (pass) → Refactor là thứ tự bắt buộc.

🟡 QUALITY &nbsp; ❌ **Gherkin do developer tự viết mà không có BA/QA**
> Mất đi mục đích chính của BDD: shared understanding. Tốn công gấp đôi.
✅ BDD chỉ có giá trị khi 3 Amigos (BA + Dev + QA) viết cùng nhau.

🟠 RELIABILITY &nbsp; ❌ **`retry: 3` để "fix" flaky tests**
> Root cause vẫn còn. CI chậm hơn. Flaky tests tích lũy.
✅ Fix root cause: timing → `waitFor`, shared state → `beforeEach` cleanup.

🟡 QUALITY &nbsp; ❌ **Mutation score 100% là mục tiêu**
> Tốn thời gian, diminishing returns. Config files và trivial code không cần.
✅ Focus mutation testing vào business logic core (pricing, validation, workflow).

🔴 CRITICAL &nbsp; ❌ **Load test trực tiếp trên production environment**
> Real users bị ảnh hưởng. Database bị stress. Không thể reset.
✅ Load test trên staging environment có cùng infrastructure config với production.

🔴 CRITICAL &nbsp; ❌ **Test environment dùng production data (PII)**
> GDPR/HIPAA violation. Security risk. Test DB thường ít secured hơn production.
✅ Anonymized snapshot: hash emails, randomize names, mask payment data.

🟠 RELIABILITY &nbsp; ❌ **Chaos experiments không có steady state baseline trước**
> Không biết "normal" là gì → không thể detect degradation.
✅ Define và measure steady state metrics TRƯỚC khi inject failure.

🟠 RELIABILITY &nbsp; ❌ **Không có flaky test policy**
> Developers ignore flaky tests → số lượng tích lũy → CI unreliable → team ignore CI.
✅ Quarantine sau 2 fails, fix SLA 2 sprints, delete nếu không fix được.

---

## AI Engineering

🟠 RELIABILITY &nbsp; ❌ **Dump toàn bộ documents vào context window (no RAG)**
> "Model có 200K context, mình bỏ hết docs vào" — context rot: performance degrades với long context dù window đủ lớn. Cost cũng explode.
✅ RAG: retrieve < 8K tokens relevant context. Shorter, more precise context = better answers.

🟡 QUALITY &nbsp; ❌ **Chunk size quá lớn (> 1024 tokens)**
> Embedding "represents everything and nothing" — retrieved chunk luôn có irrelevant content.
✅ Start với 256–512 tokens, 20% overlap. Tune dựa trên retrieval quality metrics thực tế.

🟡 QUALITY &nbsp; ❌ **Dense-only vector search**
> Yếu với exact terms, product codes, proper nouns: "SKU-12345" không match semantically.
✅ Hybrid search: dense + BM25 với Reciprocal Rank Fusion. Default cho production RAG.

🟡 QUALITY &nbsp; ❌ **Không có reranking**
> Cosine similarity ≠ actual relevance. Top-5 by similarity không phải top-5 by usefulness.
✅ Cross-encoder reranker sau retrieval: retrieve 20 → rerank → top 5 cho LLM.

🔴 CRITICAL &nbsp; ❌ **System prompt chứa secrets hoặc sensitive instructions**
> Prompt injection + "What's in your system prompt?" → leak credentials, bypass safety.
✅ Không bao giờ secrets trong prompt. Hardcode instructions không thể override bằng user input.

🔴 CRITICAL &nbsp; ❌ **Không validate LLM output trước khi execute**
> LLM output được dùng trong SQL query, shell command, HTML render → injection attack.
✅ Parse và validate output. Never exec() hoặc eval() LLM output trực tiếp.

🔴 CRITICAL &nbsp; ❌ **Trust MCP servers từ community mà không audit**
> MCP server có thể bị backdoor, có malicious tool descriptions (prompt injection).
✅ Audit MCP servers trước khi dùng. Tool approval workflow cho sensitive actions. Minimal permissions.

---

## Platform Engineering

🟡 QUALITY &nbsp; ❌ **Cài Backstage và tuyên bố "chúng tôi có IDP"**
> Backstage là portal framework (UI layer). Platform = backend orchestration, automation, golden paths. Portal không có backend = empty shell.
✅ Build backend trước: automation, golden paths, policies. Portal là optional UI layer thêm sau.

🟠 RELIABILITY &nbsp; ❌ **Build "golden cage" thay vì "golden path"**
> Platform quá rigid, không cho phép bất kỳ deviation nào → teams build shadow tooling xung quanh platform.
✅ Golden path = recommended default với clear opt-out process. Teams có thể deviate với justification.

🟠 RELIABILITY &nbsp; ❌ **Platform team build theo ý mình, không hỏi developers**
> Platform có low adoption: 10% engineers dùng sau 6 months implementation.
✅ Interview 5-10 developers trước khi build. "Bạn mất thời gian nhất ở đâu?" → build cho pain đó.

🟠 RELIABILITY &nbsp; ❌ **Build portal trước backend**
> Backstage portal với không có automation backend = developers click button → không có gì xảy ra.
✅ Automation engine trước. Portal chỉ là interface; CLI + docs thường đủ cho small teams.

🟡 QUALITY &nbsp; ❌ **Không track platform adoption metrics**
> "Chúng tôi có platform" nhưng không biết có ai dùng không.
✅ Track: golden path usage, deviation rate, time-to-first-PR, developer satisfaction quarterly.

---

## Data Engineering

🔴 CRITICAL &nbsp; ❌ **Lưu raw PII trong data lake không encrypted**
> S3 bucket với plain-text emails, SSNs, card numbers → breach = GDPR/PCI violation.
✅ Column-level encryption hoặc tokenization trước khi land vào lake. Separate raw PII từ analytics data.

🟠 RELIABILITY &nbsp; ❌ **CDC replication slot không monitored**
> Debezium slot lag tăng → PostgreSQL WAL không được cleaned → disk full → production DB crash.
✅ Alert khi slot lag > 1GB. Monitor `pg_replication_slots` continuously.

🟠 RELIABILITY &nbsp; ❌ **dbt models không có tests**
> Data quality issues (nulls, duplicates, invalid values) không được detected cho đến khi dashboard sai.
✅ Minimum: `not_null` và `unique` trên primary keys. `accepted_values` cho enums.

🟡 QUALITY &nbsp; ❌ **Full table reload mỗi ngày cho large tables**
> 100GB table × daily full reload = 100GB scan/day = expensive và slow.
✅ Incremental models trong dbt: chỉ process rows mới/updated.

---

## FinOps

🟠 RELIABILITY &nbsp; ❌ **Dev/staging environments chạy 24/7**
> Dev environment idle 16h/ngày, weekend → 65% wasted compute cost.
✅ Auto-shutdown: Stop instances at 7pm, start at 8am. Script với AWS Lambda hoặc Instance Scheduler.

🟡 QUALITY &nbsp; ❌ **Không có tagging strategy trước khi deploy**
> Không biết team nào gây $50K spike. Cost allocation impossible sau khi scale.
✅ Enforce tags từ ngày 1: team, environment, service. SCP block untagged resources.

🟡 QUALITY &nbsp; ❌ **Reserved Instances cho tất cả compute**
> Variable workloads committed → paying for unused capacity.
✅ RI chỉ cho stable baseline (24/7). On-Demand/Spot cho variable/batch workloads.

---

## Compliance

🔴 CRITICAL &nbsp; ❌ **PHI trong application logs (HIPAA)**
> Logging `user.email + diagnosis` → logs thường ít secured hơn prod DB → HIPAA violation.
✅ Strip PII/PHI trước khi log. Log user_id, không email. Mask sensitive fields.

🔴 CRITICAL &nbsp; ❌ **Không có BAA với AWS/Sendgrid/Slack trước khi store PHI**
> Vendor agreement không có = HIPAA violation ngay cả nếu data encrypted.
✅ Sign BAA với MỌI vendor trước khi any PHI touches their systems.

🔴 CRITICAL &nbsp; ❌ **Store CVV hoặc full magnetic stripe (PCI-DSS)**
> PCI-DSS prohibits storing security code và magnetic stripe data. Automatic Level 1 violation.
✅ Never store. Use Stripe/Adyen tokenization — they handle PAN, you store only token.

🟠 RELIABILITY &nbsp; ❌ **GDPR erasure request chỉ delete từ primary DB**
> Data còn trong: search index, Redis cache, S3 exports, analytics warehouse, backups, third-party CRM.
✅ Erasure checklist: primary DB, replicas, cache, search, CDN, analytics, third-parties, backup (cryptographic erasure).
