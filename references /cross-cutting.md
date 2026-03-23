# Cross-Cutting Concerns — Reference

---

## 1. Security Chi Tiết

### JWT — Pitfalls và CVEs thực tế (2025)

**Algorithm confusion attack (CVE lịch sử, vẫn còn phổ biến)**:
```
Attack: Attacker đổi header "alg": "RS256" thành "alg": "HS256"
Server dùng RS256 public key (thường public) như HMAC secret
→ Attacker có thể sign token với public key → bypass authentication

Fix:
  - Hardcode algorithm phía server, không đọc từ token header
  - jwt.verify(token, secret, { algorithms: ['RS256'] })  // explicit list
  - Không dùng "none" algorithm trong production
```

**Issuer array bypass (CVE-2025-27371 pattern)**:
```
Vulnerable library: Chấp nhận iss là array ["https://attacker/", "https://valid/"]
Library validate: "does valid issuer exist in array?" → YES → pass
External processor dùng first value: "https://attacker/"

Fix:
  - Validate iss là string, không phải array
  - Strict equality: iss MUST equal expected_issuer
  - Không dùng array includes check cho critical claims
```

**Audience validation hay bị bỏ qua**:
```
Scenario: Auth server issue token với aud: "api.example.com"
Service B nhận token intended cho Service A → không validate aud → PASS
→ Privilege escalation: dùng token của 1 service để access service khác

Fix:
  jwt.verify(token, secret, {
    algorithms: ['RS256'],
    issuer: 'https://auth.example.com',
    audience: 'api.example.com',  // PHẢI validate audience
  })
```

**JWT vs Session — khi nào dùng gì**:
```
JWT phù hợp:
  - Microservices: Service A verify token mà không cần gọi Auth Service
  - Mobile API: Stateless, không cần server-side session store
  - Short-lived tokens (< 1 giờ): Revocation ít cần thiết

JWT KHÔNG phù hợp:
  - Long-lived sessions trong web app
  - Cần revoke ngay lập tức (banned user, password change)
  - Storing sensitive data trong payload (payload không encrypted trong JWS)
  
Hybrid approach (best for web):
  - Browser: httpOnly cookie với opaque session token
  - Mobile/API: JWT short-lived + refresh token
  - Service-to-service: JWT với client_credentials grant
```

**Token storage**:
```
httpOnly cookie:
  ✅ Không accessible qua JavaScript → XSS safe
  ✅ Auto-sent với requests
  ❌ CSRF risk → fix với SameSite=Lax/Strict
  ❌ CORS cần credentials: true

localStorage:
  ❌ XSS có thể read token → send anywhere
  ❌ KHÔNG dùng cho tokens

Memory (React state):
  ✅ XSS không persist token sau refresh
  ❌ Mất khi refresh page → cần silent refresh mechanism

Best practice web SPA:
  Access token: Memory (React state / Zustand)
  Refresh token: httpOnly cookie với SameSite=Strict
  Silent refresh: Call /auth/refresh trong iframe hoặc background fetch
```

**Refresh token rotation + detection**:
```
Flow:
  1. Login → issue access_token (15m) + refresh_token (7d)
  2. Access token expire → call /auth/refresh với refresh_token
  3. Server issue NEW access_token + NEW refresh_token
  4. Invalidate old refresh_token
  
Reuse detection (token theft detection):
  5. Legitimate user dùng old refresh_token sau khi đã được rotate
  → Server phát hiện "old token" được dùng → COMPROMISE DETECTED
  → Invalidate ENTIRE token family cho user này
  → User bị logout toàn bộ devices → phải login lại

Storage cho refresh token family:
  Redis: refresh_token_family:{userId} = {token_hash, rotated_at}
  Hoặc DB với family_id tracking
```

### Authorization

**RBAC thực tế với edge cases**:
```
User có multiple roles:
  User A: roles = ['editor', 'billing_manager']
  → Permissions = union của tất cả roles
  → can('post:create') = true (from editor)
  → can('billing:view') = true (from billing_manager)

Permission check:
  // Middleware approach
  app.delete('/posts/:id', requirePermission('post:delete'), handler)

  // Policy trong handler
  async function deletePost(userId, postId) {
    const post = await db.getPost(postId)
    const canDelete = user.hasPermission('post:delete') ||
                      (user.hasPermission('post:delete:own') && post.authorId === userId)
    if (!canDelete) throw new ForbiddenError()
    await db.deletePost(postId)
  }

Caching permissions:
  // DB lookup per request → quá chậm
  // Redis cache với TTL 5 phút
  const perms = await redis.get(`permissions:${userId}`)
  if (!perms) {
    const dbPerms = await db.getUserPermissions(userId)
    await redis.setex(`permissions:${userId}`, 300, JSON.stringify(dbPerms))
  }
  
  // Invalidate khi role thay đổi:
  await redis.del(`permissions:${userId}`)
```

**Row-level security (RLS) — PostgreSQL**:
```sql
-- Enforce data access ở DB level, không chỉ application
ALTER TABLE posts ENABLE ROW LEVEL SECURITY;

CREATE POLICY user_posts ON posts
  USING (author_id = current_user_id())  -- Chỉ thấy posts của mình
  WITH CHECK (author_id = current_user_id());  -- Chỉ tạo/sửa posts của mình

-- Admin bypass
CREATE POLICY admin_all ON posts
  TO admin_role
  USING (true);

-- Benefit: Dù application bug, DB không leak data
-- Nhưng: Performance overhead, cần test kỹ
```

### Security Headers Checklist

```http
# HTTPS
Strict-Transport-Security: max-age=31536000; includeSubDomains; preload

# Clickjacking
X-Frame-Options: DENY
Content-Security-Policy: frame-ancestors 'none'

# MIME sniffing
X-Content-Type-Options: nosniff

# Referrer
Referrer-Policy: strict-origin-when-cross-origin

# CSP (content security policy)
Content-Security-Policy:
  default-src 'self';
  script-src 'self' 'nonce-{random}';
  style-src 'self' 'unsafe-inline';  # inline styles thường cần
  img-src 'self' data: https://cdn.example.com;
  connect-src 'self' https://api.example.com;
  frame-ancestors 'none';

# Permissions
Permissions-Policy: camera=(), microphone=(), geolocation=()
```

### Common Vulnerabilities

```
SSRF (Server-Side Request Forgery):
  Attack: POST /api/fetch { url: "http://169.254.169.254/latest/meta-data/iam/..." }
  → Server fetch AWS metadata → attacker gets cloud credentials
  
  Defense in depth:
  1. Validate URL scheme: ONLY https://
  2. Block private IPs: 10.x, 172.16.x-31.x, 192.168.x, 127.x, 169.254.x, ::1
  3. DNS rebinding protection: resolve DNS → check IP lại sau resolution
  4. Allowlist domains nếu có thể

Mass assignment:
  // BAD: Bind toàn bộ request body
  User.create(req.body)  // attacker có thể set role: "admin"
  
  // GOOD: Explicit allowlist
  User.create(pick(req.body, ['name', 'email', 'password']))

Path traversal:
  GET /files?name=../../etc/passwd
  
  Fix:
  const safeFileName = path.basename(req.query.name)  // strip directory traversal
  const filePath = path.join(UPLOAD_DIR, safeFileName)
  // Verify path starts with UPLOAD_DIR
  if (!filePath.startsWith(UPLOAD_DIR)) throw new Error()
```

---

## 2. Observability Chi Tiết

### Structured Logging

```json
// Template đầy đủ cho production
{
  "timestamp": "2024-01-15T10:30:00.123Z",
  "level": "error",
  "service": "order-service",
  "version": "2.3.1",
  "environment": "production",
  "region": "ap-southeast-1",
  "host": "pod-abc123",

  // Distributed tracing
  "traceId": "abc123def456789",
  "spanId": "789ghi012",
  "parentSpanId": "456def789",

  // Request context
  "requestId": "req-uuid-here",
  "correlationId": "corr-uuid",
  "userId": "user_123",
  "sessionId": "sess_456",

  // Business context
  "message": "Payment processing failed",
  "error": {
    "type": "PaymentDeclinedException",
    "message": "Card declined by issuer",
    "code": "CARD_DECLINED",
    "stack": "..."  // chỉ non-production hoặc behind flag
  },
  "context": {
    "orderId": "order_789",
    "amount": 9990,
    "currency": "VND",
    "paymentMethod": "card_****4242",
    "attemptNumber": 2
  },
  "duration_ms": 234,
  "http": {
    "method": "POST",
    "path": "/api/v1/payments",
    "statusCode": 402,
    "userAgent": "Mozilla/5.0..."
  }
}
```

**PII trong logs — hay bị vi phạm**:
```
KHÔNG log:
  - Password, PIN, security questions
  - Full credit card số (chỉ last 4)
  - Full SSN, CCCD
  - Auth tokens, API keys, session IDs (kể cả partial)
  - Tên + email + phone cùng nhau (combination = PII)
  - Location data nếu precise

Masking patterns:
  Email: a***@example.com
  Phone: ***-***-1234
  Card: ****-****-****-4242
  Token: {first6}...{last4}

GDPR compliance:
  Log retention: tối đa 30-90 ngày cho access logs
  Right to erasure: cần cơ chế xóa PII khỏi logs nếu user request
  Consider: log userId hash thay vì plaintext PII
```

**Log sampling**:
```
ERROR/CRITICAL: 100% (không bao giờ sample)
WARN: 100%
INFO (business events): 100%
INFO (health checks, routine ops): 1-10%
DEBUG: 0.1-1%

Dynamic sampling:
  Nếu error rate tăng → tạm thời tăng sample rate cho DEBUG
  Implement: Feature flag điều khiển log level per service
```

### Metrics

**4 Golden Signals chi tiết**:
```
1. Latency:
   p50 (median): 50% requests faster than này
   p95: 95% requests faster than này
   p99: 99% requests faster than này (SLA thường dùng)
   p99.9: 99.9% (ultra-strict SLA)
   
   Tại sao không dùng average/mean:
   1000 requests: 999 × 10ms + 1 × 10000ms = mean 20ms
   Nhưng p99 = 10000ms → user experience thực tế cực kỳ tệ

2. Traffic:
   HTTP: requests/giây per endpoint
   gRPC: calls/giây per method
   Queue: messages/giây, consumer lag
   DB: queries/giây, transactions/giây
   Cache: hits/giây, misses/giây, hit rate %

3. Errors:
   HTTP 5xx rate (server errors — luôn alert)
   HTTP 4xx rate (client errors — theo dõi, không luôn alert)
   Unhandled exceptions per service
   Queue processing failures per queue
   
   Error budget (SLO based):
   99.9% uptime = 43.8 phút downtime/tháng
   Nếu đã dùng 80% error budget → freeze deploys, focus on stability

4. Saturation:
   CPU: alert > 80% sustained 5 phút
   Memory: alert > 85% (để GC còn room)
   Disk: alert > 80% (growth rate cũng cần monitor)
   Network: ingress/egress bandwidth vs capacity
   DB connections: alert > 80% pool used
   Queue depth: alert khi growing trend (backlog accumulation)
```

**USE Method cho infrastructure**:
```
Utilization: Tỉ lệ % resource đang được dùng
Saturation: Có work đang queue chờ không?
Errors: Resource có báo lỗi không?

Áp dụng theo thứ tự debugging:
  CPU: utilization high + saturation (run queue)? → scale up/out
  Memory: utilization high? → OOM risk, kiểm tra leaks
  Disk I/O: saturation (io wait) high? → slow queries, slow logging
  Network: errors (dropped packets)? → network issue
```

### Distributed Tracing — OpenTelemetry

```python
# Setup một lần, instrument nhiều nơi
from opentelemetry import trace
from opentelemetry.sdk.trace import TracerProvider
from opentelemetry.exporter.otlp.proto.grpc.trace_exporter import OTLPSpanExporter

provider = TracerProvider()
provider.add_span_processor(
    BatchSpanProcessor(OTLPSpanExporter(endpoint="http://jaeger:4317"))
)
trace.set_tracer_provider(provider)
tracer = trace.get_tracer(__name__)

# Auto-instrument frameworks (không cần code changes)
# Flask: FlaskInstrumentor().instrument_app(app)
# Django: DjangoInstrumentor().instrument()
# SQLAlchemy: SQLAlchemyInstrumentor().instrument(engine=engine)
# Redis: RedisInstrumentor().instrument()
# Requests: RequestsInstrumentor().instrument()

# Manual instrument business logic
def process_order(order_id: str):
    with tracer.start_as_current_span("process_order") as span:
        span.set_attribute("order.id", order_id)
        span.set_attribute("order.customer_id", customer_id)
        
        try:
            result = do_processing()
            span.set_status(StatusCode.OK)
            return result
        except Exception as e:
            span.record_exception(e)
            span.set_status(StatusCode.ERROR, str(e))
            raise
```

**Context propagation trong async — hay bị mất**:
```python
# BAD: Trace context bị mất qua asyncio/threading
async def handle_order(order_id):
    await asyncio.create_task(send_email(order_id))  # mất context

# GOOD: Propagate context explicitly
async def handle_order(order_id):
    ctx = context.get_current()  # capture current context
    await asyncio.create_task(
        send_email_with_context(order_id, ctx)
    )

async def send_email_with_context(order_id, ctx):
    context.attach(ctx)  # restore context in new task
    with tracer.start_as_current_span("send_email"):
        await smtp.send(...)
```

**Sampling strategies**:
```
Head-based sampling (quyết định tại start):
  - 100% errors
  - 10% normal requests
  - Simple nhưng miss "slow" requests không biết trước

Tail-based sampling (quyết định sau khi complete):
  Otel Collector Tail Sampler:
  - Sample 100% traces với errors
  - Sample 100% traces với duration > 1s
  - Sample 1% remaining
  
  Better insight nhưng cần buffer → memory cost
```

---

## 3. CI/CD Chi Tiết

### Pipeline với timing targets

```yaml
# .github/workflows/ci.yml
name: CI

on: [push, pull_request]

jobs:
  fast-checks:             # Target: < 3 phút
    runs-on: ubuntu-latest
    steps:
      - lint-and-typecheck  # ESLint + tsc --noEmit: ~1min
      - unit-tests          # Jest/Vitest: ~2min
      - dependency-audit    # npm audit --audit-level=high

  integration:             # Target: < 10 phút
    needs: fast-checks
    services:
      postgres:
        image: postgres:16
        env: { POSTGRES_DB: testdb, POSTGRES_PASSWORD: password }
      redis:
        image: redis:7
    steps:
      - integration-tests   # API tests với real DB
      - contract-tests      # Pact consumer tests

  security:                # Parallel với integration
    needs: fast-checks
    steps:
      - sast                # Semgrep, CodeQL: static analysis
      - container-scan      # Trivy: scan Docker image
      - secrets-scan        # gitleaks, TruffleHog

  build:
    needs: [integration, security]
    steps:
      - docker-build
      - push-to-registry   # Tag với git SHA

  deploy-staging:          # Auto deploy sau merge main
    needs: build
    environment: staging
    steps:
      - deploy
      - smoke-tests         # Critical path E2E: ~5min

  deploy-prod:             # Manual approval required
    needs: deploy-staging
    environment: production
    steps:
      - deploy-canary       # 5% traffic
      - monitor-5min        # Check error rate, latency
      - deploy-full         # 100% nếu OK
```

### Deployment strategies — chi tiết hơn

**Blue/Green với DB migration**:
```
Problem: Blue và Green cùng connect đến cùng 1 DB
  Blue: đọc/viết column "name"
  Green: cần đổi "name" thành "full_name" (rename)
  
  Nếu rename trong migration → Blue crash ngay khi deploy Green

Giải pháp: Expand-Contract pattern
  Migration 1 (deploy với Green):
    ADD COLUMN full_name
    Copy data: full_name = name
    Application viết cả 2 columns
    Application đọc full_name (có fallback về name)
  
  Verify: Tất cả data migrated, Green stable
  
  Migration 2 (deploy sau):
    DROP COLUMN name (contract phase)
    Application chỉ dùng full_name
  
  Rule: Không bao giờ DROP column và deploy cùng lúc
```

**Canary với metrics-based auto-rollback**:
```yaml
# Argo Rollouts example
apiVersion: argoproj.io/v1alpha1
kind: Rollout
spec:
  strategy:
    canary:
      steps:
        - setWeight: 5      # 5% traffic sang canary
        - pause: { duration: 5m }
        - analysis:
            templates:
              - templateName: error-rate-check  # Check error rate
        - setWeight: 25
        - pause: { duration: 5m }
        - analysis:
            templates:
              - templateName: latency-check    # Check p99 latency
        - setWeight: 100

# Analysis template
kind: AnalysisTemplate
spec:
  metrics:
    - name: error-rate
      provider:
        prometheus:
          query: |
            rate(http_requests_total{status=~"5.."}[5m])
            / rate(http_requests_total[5m]) * 100
      successCondition: result[0] < 1  # < 1% error rate
      failureLimit: 1
```

**Feature flags — lifecycle**:
```
Stage 1: Deploy behind flag (flag = off)
  Code trong production, không ai thấy
  
Stage 2: Internal testing (flag = on cho QA team)
  Test với production data

Stage 3: Gradual rollout
  on cho 1% → 5% → 20% → 50% → 100%
  
Stage 4: Default on, flag deprecated
  Remove flag reference trong code

Stage 5: Cleanup (< 2 sprints sau Stage 4)
  Delete flag từ feature flag service
  
Anti-patterns:
  - Flags tồn tại > 3 tháng → "flag debt"
  - Nested flags (flag inside flag) → testing matrix explosion
  - Không cleanup → undefined behavior khi flag deleted
  
Tools: LaunchDarkly, Unleash (open source), Flagsmith, GrowthBook
```

### Kubernetes — edge cases production

```yaml
# Resource requests vs limits — hay bị sai
resources:
  requests:           # Kubernetes scheduling dùng đây
    memory: "256Mi"   # Guaranteed minimum
    cpu: "250m"       # 0.25 CPU guaranteed
  limits:
    memory: "512Mi"   # Exceed → OOMKilled (restart)
    cpu: "500m"       # Exceed → throttled (không restart, nhưng slow)

# Common mistakes:
# 1. requests == limits: không cho phép burst, waste resources
# 2. Không set requests: Pod ở "Burstable" class, dễ bị evicted
# 3. Không set limits: noisy neighbor problem
# 4. CPU limit quá thấp: app slow khi cần burst (GC, startup)
#    → Set CPU limit = 2-4x requests, hoặc không set CPU limit

# liveness vs readiness vs startup probes
livenessProbe:    # Fail → restart pod
  httpGet: { path: /health/live, port: 8080 }
  initialDelaySeconds: 30    # Chờ app start
  periodSeconds: 10
  failureThreshold: 3        # 3 consecutive failures → restart

readinessProbe:   # Fail → remove từ Service endpoints (stop traffic)
  httpGet: { path: /health/ready, port: 8080 }
  periodSeconds: 5
  failureThreshold: 3
  # /health/ready trả về 503 khi: DB disconnected, cache disconnected,
  #                               đang processing startup tasks

startupProbe:     # Cho slow-starting apps (JVM, model loading)
  httpGet: { path: /health/live, port: 8080 }
  failureThreshold: 60    # 60 × 10s = 10 phút max startup time
  periodSeconds: 10
  # Khi startupProbe pass → liveness/readiness bắt đầu chạy

# PodDisruptionBudget: đảm bảo availability khi rolling update
apiVersion: policy/v1
kind: PodDisruptionBudget
spec:
  selector: { matchLabels: { app: my-service } }
  minAvailable: 2   # Luôn ít nhất 2 pods available
  # hoặc:
  maxUnavailable: 1  # Không bao giờ > 1 pod down cùng lúc

# HPA với custom metrics
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
spec:
  scaleTargetRef:
    kind: Deployment
    name: my-service
  minReplicas: 3
  maxReplicas: 50
  metrics:
    - type: Resource
      resource:
        name: cpu
        target: { type: Utilization, averageUtilization: 70 }
    - type: External          # Custom: scale theo queue depth
      external:
        metric: { name: sqs_messages_visible }
        target: { type: AverageValue, averageValue: "100" }
```

---

## 4. Testing Strategy

> Testing có file riêng với coverage đầy đủ: **`references/testing.md`**
> File đó cover: unit, integration, E2E, contract, load, visual regression, mobile, security testing,
> test doubles, factories, MSW, Playwright POM, k6 load tests, anti-patterns, CI pipeline design.

### Testing trong CI pipeline — chỉ gates

```
Gate 1 (< 2 min, mọi commit):    Lint + typecheck
Gate 2 (< 5 min, mọi PR):        Unit tests + coverage check
Gate 3 (< 10 min, mọi PR):       Integration tests với real containers
Gate 4 (< 3 min, parallel):      Security scan (SAST + secrets + deps)
Gate 5 (< 20 min, merge to main): E2E critical paths
Gate 6 (staging, pre-prod):       Load tests + smoke tests
```

### Test pyramid summary

```
E2E (10%):          Playwright — critical user flows only
Integration (60%):  Supertest + Testcontainers — API + DB
Unit (30%):         Vitest/Jest — business logic, utils, algorithms
Static (free):      TypeScript + ESLint — catches errors before runtime
```

---

---

## 5. SRE — Site Reliability Engineering

### SLI, SLO, SLA — phân biệt rõ

```
SLI (Service Level Indicator): Metric thực tế đo được
  Ví dụ: 99.3% requests hoàn thành < 200ms trong 30 ngày qua

SLO (Service Level Objective): Target nội bộ team đặt ra
  Ví dụ: 99.5% requests < 200ms (KHÔNG public với khách hàng)
  SLO = SLI target. Cần stricter hơn SLA để có buffer.

SLA (Service Level Agreement): Cam kết với khách hàng, có penalty
  Ví dụ: 99.0% uptime/month. Vi phạm → service credit.
  SLA < SLO < SLI thực tế (nếu system healthy)

Tại sao SLO cần stricter hơn SLA:
  SLA: 99.0% → 7.2 giờ downtime/tháng
  SLO: 99.5% → 3.6 giờ downtime/tháng (buffer 3.6 giờ)
  Nếu SLO bị breach → fix trước khi ảnh hưởng SLA
```

### Error Budget

```
Error Budget = 1 - SLO
  SLO 99.9% → Error budget = 0.1% = 43.8 phút/tháng

Error budget là RESOURCE, không punishment:
  Còn budget → Can ship, experiment, take risks
  Budget exhausted → Freeze non-critical releases, focus reliability

Error budget burn rate:
  Budget burn rate = actual error rate / (1 - SLO)
  Burn rate > 1 → depleting budget faster than allowed
  Burn rate > 14.4x over 1 hour → page on-call immediately
  Burn rate > 6x over 6 hours → ticket, fix within 3 days

Error budget policy (cần document trước incident):
  If burn rate > 2x for 3 consecutive days:
    → Reduce deployment frequency by 50%
  If error budget < 10% remaining:
    → Freeze feature releases, reliability sprint only
  If SLA at risk:
    → Incident response, war room

Tracking error budget:
  Prometheus:
    1 - (sum(rate(http_requests_total{status!~"5.."}[30d]))
         / sum(rate(http_requests_total[30d])))
  Dashboard: remaining budget %, burn rate trend, SLO compliance
```

### Toil — định nghĩa và đo lường

```
Toil: Công việc manual, repetitive, automatable, không tạo lasting value
  Characteristic: Scales linearly với service growth (không O(1))

Ví dụ toil:
  ✓ Manual certificate rotation mỗi 90 ngày
  ✓ Restarting service khi memory leak
  ✓ Manually scaling capacity trước events
  ✓ Responding to false-positive alerts
  ✓ Copy-paste config cho mỗi environment
  ✗ Investigating new class of errors (NOT toil — adds knowledge)
  ✗ Building automation tool (NOT toil — eliminates future toil)

Measuring toil:
  Survey engineers: "% time last sprint on toil?" → track trend
  Ticket categorization: tag tickets as toil vs project work
  On-call burden: # of pages, time to resolve per rotation

Target: < 50% engineer time on toil (Google SRE target)
If > 50% → toil reduction là highest priority, halt new features
```

### Reliability Design Patterns

**Graceful degradation:**
```
System partially available > system unavailable

Tiers of degradation:
  Tier 1: Full functionality
  Tier 2: Core features only (drop non-critical: recommendations, analytics)
  Tier 3: Read-only mode (show cached data, disable writes)
  Tier 4: Maintenance page với status updates

Implementation:
  Feature flags: Disable non-critical features when system stressed
  Circuit breakers: Fast-fail calls to degraded dependencies
  Fallback responses: Cached data, default values, graceful empty states

Examples:
  Netflix: Remove recommendations feature → still stream video
  E-commerce: Disable real-time inventory → show "usually in stock"
  Twitter (historical): Fail whale > total outage
```

**Backpressure:**
```
Producer sends data faster than consumer can process → buffer overflow

Solutions:
  Load shedding: Reject excess requests explicitly (503)
    Prefer shedding non-critical requests (analytics, batch)
    Return Retry-After header so client knows when to retry

  Queue-based leveling: Buffer requests in queue
    Consumer processes at sustainable rate
    Alert when queue depth grows (possible consumer failure)

  Rate limiting: Prevent producers overwhelming system
    Token bucket per client
    Graduated limits: higher tier users get higher limits

  Adaptive throttling: Adjust limits dynamically based on system health
    Istio: Adaptive concurrency limiting
    gRPC: Built-in backpressure via flow control
```

**Bulkhead pattern:**
```
Isolate failures: separate resource pools per downstream

Without bulkhead:
  App → 1 connection pool (100 connections) → DB + Payment + Shipping
  Payment hangs → all 100 connections consumed → DB queries also fail

With bulkhead:
  DB pool: 60 connections → dedicated for DB
  Payment pool: 20 connections → dedicated for Payment
  Shipping pool: 20 connections → dedicated for Shipping
  Payment hangs → only Payment pool exhausted → DB still responsive

Kubernetes: Resource quotas per namespace enforce bulkheads
Thread pools: Separate executor per external dependency (Hystrix approach)
```

### Capacity Planning

```
Process:
  1. Baseline: Current resource utilization vs load
     "At 1000 QPS: CPU 40%, Memory 60%, DB connections 30%"

  2. Growth projection:
     Expected load growth: 20% MoM → 3× next 6 months
     → At 3000 QPS: CPU ~120% → need scale

  3. Load test to find limits:
     Run load test until 5xx appear → find breaking point
     Breaking point at 2500 QPS → safety margin 40% (target max 1500 QPS operational)

  4. Headroom planning:
     Never run at > 70% capacity sustained
     Keep 30% headroom for traffic spikes

  5. Scale triggers (auto-scaling thresholds):
     Scale out at: CPU 60%, Memory 70%, Request queue depth > 100
     Scale in at: CPU < 30% for 10 minutes (với cooldown)

Capacity planning cadence:
  Monthly: Review growth rate vs forecast
  Quarterly: Formal capacity review, budget request if needed
  Pre-event: Special review before product launches, holidays, campaigns
```


## 6. Incident Response

### Runbook template

```markdown
## Incident: Service XYZ High Error Rate

### Detection
Alert: error_rate > 5% for 5 minutes
Dashboard: [link]
Slack: #alerts-production

### Severity Classification
P1: Complete outage, revenue impact
P2: Partial outage, major feature broken
P3: Degraded performance, minor feature broken
P4: No user impact, potential future risk

### Immediate Response (first 15 phút)
1. Acknowledge alert trong PagerDuty
2. Open incident channel: #inc-{date}-{service}
3. Notify stakeholders (P1/P2 only)
4. Check: Recent deploys? Schedule changes? Traffic anomalies?

### Diagnose (15-30 phút)
1. Error dashboard: Which endpoints? Which users?
2. APM traces: Where is the error occurring?
3. Logs: Error patterns? Stack traces?
4. Metrics: CPU/memory/connections spike?
5. Recent changes: deploys, config, infrastructure

### Mitigate
Option A: Rollback (if recent deploy)
  kubectl rollout undo deployment/service-xyz
  → Takes ~2-5 minutes

Option B: Feature flag (if feature flag available)
  Turn off new feature flag → isolate issue
  → Takes ~30 seconds

Option C: Scale (if resource exhaustion)
  kubectl scale deployment/service-xyz --replicas=10
  → Takes ~1 minute

### Post-Incident (within 48h)
- Blameless post-mortem
- Timeline of events
- Root cause analysis (5 Whys)
- Action items với owner và deadline
- Publish to internal wiki
```

---

---

---

## 8. Zero Trust Architecture

### "Never Trust, Always Verify"

```
Traditional perimeter security:
  Firewall protects internal network
  Inside = trusted; Outside = untrusted
  Problem: Insider threats, lateral movement after breach

Zero Trust principles:
  1. Verify explicitly: Always authenticate + authorize (không trust network location)
  2. Least privilege: Minimum necessary access per request
  3. Assume breach: Design as if attacker already inside
  → Every request treated as potentially hostile, regardless of source

Implementation layers:
  Identity:    Who is this? (user, service, device)
  Device:      Is device compliant? (patch level, security config)
  Network:     mTLS between services, micro-segmentation
  Application: Per-request authorization (ABAC)
  Data:        Data classification, DLP, encryption
```

### mTLS between services

```yaml
# Mutual TLS: Both sides authenticate with certificates
# Without service mesh: implement manually

# Using cert-manager to issue certs automatically
apiVersion: cert-manager.io/v1
kind: Certificate
metadata:
  name: payment-service-cert
  namespace: payments
spec:
  secretName: payment-service-tls
  duration: 24h        # Short-lived, auto-renewed
  renewBefore: 1h
  privateKey:
    algorithm: ECDSA
    size: 256
  subject:
    organizations: ["mycompany"]
  commonName: payment-service.payments.svc.cluster.local
  dnsNames:
    - payment-service.payments.svc.cluster.local
  issuerRef:
    name: internal-ca
    kind: ClusterIssuer

# Service verifies peer certificate is signed by internal CA
# → Only internal services can call each other
```

**With Istio (easier):**
```yaml
# PeerAuthentication: Enforce mTLS for entire namespace
apiVersion: security.istio.io/v1beta1
kind: PeerAuthentication
metadata:
  name: default
  namespace: production
spec:
  mtls:
    mode: STRICT   # Reject plain-text connections

# AuthorizationPolicy: Service A can ONLY call Service B's /api endpoints
apiVersion: security.istio.io/v1beta1
kind: AuthorizationPolicy
metadata:
  name: payment-service-policy
  namespace: payments
spec:
  selector:
    matchLabels:
      app: payment-service
  rules:
    - from:
        - source:
            principals: ["cluster.local/ns/orders/sa/order-service"]
      to:
        - operation:
            methods: ["POST"]
            paths: ["/api/charge", "/api/refund"]
```

### SPIFFE / SPIRE — workload identity

```
SPIFFE (Secure Production Identity Framework For Everyone):
  Standard for workload identity (pod, container, VM, function)
  Each workload gets SVID (SPIFFE Verifiable Identity Document)
  SVID = X.509 certificate với SPIFFE URI: spiffe://company.com/ns/payments/sa/payment-service

SPIRE (SPIFFE Runtime Environment):
  Implementation of SPIFFE
  Server: Issues SVIDs to workloads
  Agent: Runs on each node, attests workload identity

Benefits:
  Works across: Kubernetes, VMs, bare metal, AWS, GCP, Azure
  No hardcoded secrets for service-to-service auth
  Short-lived certs (auto-renewed) — compromise window minimal

Integration:
  Istio + SPIRE: Istio uses SPIRE for workload identity (instead of Kubernetes SA)
  HashiCorp Vault + SPIRE: Vault grants secrets based on SPIFFE identity
```

---

## 9. Supply Chain Security

### Why it matters

```
SolarWinds (2020): Malicious code injected in build process → 18,000 orgs compromised
Log4Shell (2021): 1 open-source library → vulnerable systems worldwide
XZ Utils (2024): Maintainer backdoor in SSH dependency

Supply chain attacks target:
  Source code (compromised contributor)
  Build system (compromised CI/CD)
  Dependencies (malicious package, typosquatting)
  Distribution (compromised registry, Docker Hub)

Your app is only as secure as its weakest dependency.
```

### SBOM — Software Bill of Materials

```
SBOM = Inventory of all components in your software
  Like nutrition label for software
  Who made it, version, known vulnerabilities, licenses

Formats:
  SPDX (Linux Foundation): Most widely adopted, JSON/YAML/RDF
  CycloneDX: Security-focused, good tooling

Generate SBOM:
  # Syft: Generate SBOM from container image
  syft myapp:latest -o spdx-json > sbom.json

  # Or from source (scans package.json, go.mod, requirements.txt, etc.)
  syft dir:. -o cyclonedx-json > sbom.json

  # Grype: Scan SBOM for vulnerabilities
  grype sbom:./sbom.json

In CI pipeline:
  1. Build container image
  2. syft image → generate SBOM
  3. grype sbom → scan vulnerabilities → fail if CRITICAL
  4. Attach SBOM to release artifacts
  5. Publish SBOM to artifact registry alongside image

US federal requirement (EO 14028): All software sold to US government must include SBOM.
Growing enterprise requirement: Customers increasingly ask for SBOM.
```

### SLSA — Supply Chain Levels for Software Artifacts

```
SLSA (pronounced "salsa"): Framework for supply chain integrity
Levels 1-4 (increasing rigor):

SLSA Level 1 (easy, recommended minimum):
  - Build process documented
  - Provenance generated (who built what, from what source, when)
  - Build system: any

SLSA Level 2 (achievable with GitHub Actions):
  - Hosted build service
  - Signed provenance: GitHub Actions OIDC → signed SLSA attestation
  - Consumers can verify build happened in trusted CI

SLSA Level 3 (stricter):
  - Hardened build environment
  - Source reviewed (branch protection, code review required)
  - Two-person review

SLSA Level 4 (very strict):
  - Hermetic build: reproducible, no external dependencies at build time
  - Only for high-security projects

GitHub Actions SLSA Level 2 (practical):
  # .github/workflows/release.yml
  - uses: slsa-framework/slsa-github-generator/.github/workflows/generator_container_slsa3.yml@v2
    with:
      image: ${{ env.IMAGE }}
      digest: ${{ steps.build.outputs.digest }}
  # Generates signed SLSA provenance attestation automatically
```

### Sigstore — code signing

```
Sigstore: Free, open standard for code signing
  Keyless signing: No long-lived keys to manage
  Identity: GitHub Actions OIDC token → certificate from Fulcio CA
  Transparency log: Every signature recorded in Rekor (immutable)

Sign container image:
  # After build and push
  cosign sign --yes myregistry.com/myapp@sha256:abc123
  # Signs using GitHub Actions OIDC identity
  # Records in public transparency log

Verify before deploy:
  cosign verify     --certificate-identity-regexp "https://github.com/myorg/myapp/.github"     --certificate-oidc-issuer "https://token.actions.githubusercontent.com"     myregistry.com/myapp:latest

In Kubernetes (policy enforcement):
  # Policy Controller rejects images not signed by trusted identity
  apiVersion: policy.sigstore.dev/v1beta1
  kind: ClusterImagePolicy
  spec:
    images:
      - glob: "myregistry.com/**"
    authorities:
      - keyless:
          url: https://fulcio.sigstore.dev
          identities:
            - issuer: https://token.actions.githubusercontent.com
              subject: https://github.com/myorg/myapp/.github/workflows/release.yml
```


## 7. Decision Trees — Cross-Cutting

```
Chọn Auth strategy?
  Web app, session-based, monolith → httpOnly cookie + server sessions (Redis)
  API + microservices → JWT (RS256, short TTL) + refresh token rotation
  SSO / third-party login → OAuth 2.0 Authorization Code + PKCE
  Service-to-service → Client Credentials grant hoặc mTLS

JWT claims có đủ không?
  PHẢI validate: alg (hardcode RS256/HS256), iss, aud, exp
  Thiếu aud validation trong microservices → token của service A dùng được cho B

Observability stack?
  Self-hosted, budget limited → Prometheus + Grafana + Loki + Jaeger
  Managed, want simplicity → Datadog (best) / Grafana Cloud (cheaper)
  AWS-native → CloudWatch + X-Ray (functional but less powerful)
  Startup: → Grafana Cloud free tier + Sentry + UptimeRobot

Alert trên metric gì?
  Error rate > 1%: warning; > 5%: critical (p99, không mean)
  Latency p99 > 500ms: warning; > 2s: critical
  CPU sustained > 80% for 5 min: warning
  Memory > 85%: warning (to prevent OOM)
  Queue depth growing (not just high): warning — consumer may be stuck

Deployment strategy?
  Team nhỏ, downtime acceptable: Rolling update
  Cần zero-downtime rollback < 1 min: Blue/green
  Cần catch bugs với minimal blast radius: Canary (5% → 25% → 100%)
  Feature not ready but code deployed: Feature flags

Testing gates trong CI pipeline?
  Every commit (< 2 min): Lint + typecheck
  Every PR (< 5 min): Unit tests + security scan (npm audit, gitleaks)
  Every PR (< 10 min): Integration tests (real containers)
  Merge to main: E2E critical paths
  Pre-release: Load test + DAST scan

SLO breach — what to do?
  Burn rate > 14.4x in 1h → Page on-call immediately
  Error budget < 20% → Slow feature releases
  Error budget < 10% → Freeze deploys, reliability sprint
  SLA at risk → War room
```


## Checklist

> 🔴 MUST = block ship | 🟠 SHOULD = fix trước prod | 🟡 NICE = tech debt

### Security

🔴 MUST:
- [ ] HTTPS + `Strict-Transport-Security` header
- [ ] Parameterized queries — zero string concat trong SQL
- [ ] JWT: validate `alg` explicitly (`algorithms: ['RS256']`), không accept `none`
- [ ] JWT: validate `iss` và `aud` claims
- [ ] Tokens trong `httpOnly` cookie — KHÔNG `localStorage`
- [ ] Secrets trong env vars / secret manager — không hardcode, không commit
- [ ] Input validation + sanitization cho tất cả user input
- [ ] Không log credentials, tokens, PII

🟠 SHOULD:
- [ ] Refresh token rotation với reuse/theft detection
- [ ] `Content-Security-Policy` header
- [ ] Rate limiting trên auth endpoints (login, register, password reset)
- [ ] SSRF protection: allowlist + block private IP ranges
- [ ] Dependency audit trong CI (`npm audit --audit-level=high`)
- [ ] Security headers: `X-Content-Type-Options`, `X-Frame-Options`, `Referrer-Policy`

🟡 NICE:
- [ ] Row-level security (PostgreSQL RLS) cho multi-tenant
- [ ] Certificate pinning (chỉ cần cho finance/banking)
- [ ] Subresource Integrity (SRI) cho CDN scripts
- [ ] Automated DAST scanning

### Observability

🔴 MUST:
- [ ] Structured JSON logging với `traceId`, `requestId`
- [ ] Không log PII, passwords, tokens
- [ ] Error rate alert (> 1% → warn, > 5% → critical)
- [ ] Health endpoints: `/health/live` + `/health/ready`

🟠 SHOULD:
- [ ] 4 Golden Signals dashboard (latency p99, traffic, errors, saturation)
- [ ] Log sampling: 100% errors, sampled debug/info
- [ ] OpenTelemetry instrumentation với context propagation qua async
- [ ] Startup probe cho slow-starting services (K8s)
- [ ] Alert trên saturation: CPU > 80%, memory > 85%, connection pool > 80%

🟡 NICE:
- [ ] Tail-based sampling (sample 100% errors + slow traces)
- [ ] Business metrics dashboard (conversion rate, order rate)
- [ ] SLO / error budget tracking
- [ ] Synthetic monitoring (scheduled E2E tests chạy mọi 5 phút)

### CI/CD

🔴 MUST:
- [ ] Không deploy trực tiếp lên production (luôn qua pipeline)
- [ ] Fast feedback < 5 phút (lint + type check + unit tests) trên mọi PR
- [ ] DB migration: Expand-Contract pattern (không DROP column + deploy đồng thời)
- [ ] Rollback plan < 5 phút

🟠 SHOULD:
- [ ] Integration tests với real Docker containers
- [ ] Security scan (SAST, container scan, secrets scan) trong pipeline
- [ ] Canary hoặc blue/green với metrics-based auto-rollback
- [ ] `PodDisruptionBudget` nếu dùng Kubernetes
- [ ] Bundle size check → fail nếu tăng > 10KB unexpected

🟡 NICE:
- [ ] Contract tests (Pact) cho service boundaries
- [ ] Load tests trong staging trước major releases
- [ ] Chaos engineering (Chaos Monkey) cho production resilience

### Testing

🔴 MUST:
- [ ] Unit tests tồn tại cho business logic (coverage > 70%)
- [ ] Không check in code breaking existing tests

🟠 SHOULD:
- [ ] Unit test coverage > 80% cho business logic
- [ ] Integration tests cho tất cả API endpoints
- [ ] E2E tests cho critical user flows (checkout, login, core feature)
- [ ] Test data builders / factories (không hardcode fixtures)

🟡 NICE:
- [ ] E2E với Page Object Model (không brittle selectors)
- [ ] Visual regression tests (Chromatic) cho UI components
- [ ] Mutation testing để verify test quality
- [ ] Performance regression tests trong CI
