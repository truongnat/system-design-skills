# Backend / High-Level Design — Reference

---

## 1. Topology chuẩn

```
Client
  └── CDN (static assets + edge cache)
       └── DDoS protection (Cloudflare, AWS Shield)
            └── Load Balancer (L7)
                 └── API Gateway (auth, rate limit, routing, logging)
                      ├── Service A (stateless, horizontal scale)
                      ├── Service B → Message Queue → Worker
                      │              (async, decoupled)
                      └── Service C
                           ├── Primary DB (write)
                           ├── Read Replica × N (read)
                           └── Cache Layer (Redis)
                                └── Search Index ← sync từ Primary DB
```

---

## 2. Estimating Scale — Làm Trước Khi Thiết Kế Bất Cứ Thứ Gì

```
Ví dụ: Social media app 1M DAU

Step 1: Request rate
  DAU: 1,000,000
  Sessions/day/user: 3
  Requests/session: 10
  → 30M requests/day = 347 QPS average
  Peak (3× avg): ~1,000 QPS

Step 2: Read/Write split
  Thường 95% read, 5% write
  Write: ~17 QPS
  Read: ~330 QPS

Step 3: Storage growth
  1 user = 10KB/day
  1M users × 10KB × 365 = 3.65TB/year
  → Cần xem xét sharding khi > 1TB trong single node

Step 4: Cache sizing (80/20 rule)
  20% data = 80% traffic → cache 20%
  3.65TB/year daily hot data = 3.65TB/365 = ~10GB/day
  Cache 20% = ~2GB — Redis r6g.large (13GB RAM) là đủ

Step 5: Bandwidth
  Average response = 1KB
  330 reads/s × 1KB = 330KB/s đọc
  + CDN offload → origin chỉ serve cache miss (~10%)
  → Origin bandwidth: ~33KB/s = negligible
```

---

## 3. Database — Decision Framework Chi Tiết

### Choosing the right DB type

```
Câu hỏi 1: Data có structured relationships và cần ACID transactions không?
  → YES → PostgreSQL (default 2025, surpassed MySQL với 55% usage)
           MySQL nếu team đã quen, nhưng PostgreSQL mạnh hơn về:
           JSONB, window functions, CTEs, LISTEN/NOTIFY, logical replication,
           partial indexes, expression indexes, GIN/GiST index types

Câu hỏi 2: Schema flexible, document-based?
  → MongoDB: general purpose, rich queries trên documents
  → Firestore: real-time sync, mobile/web, auto-scaling
  → DynamoDB: managed, predictable latency, serverless-friendly

Câu hỏi 3: Cần extreme read speed bằng key lookup?
  → Redis: in-memory, sub-millisecond
  → DynamoDB: managed, DAX nếu cần cache layer

Câu hỏi 4: Time-series data (metrics, IoT, logs)?
  → TimescaleDB (PostgreSQL extension): best of both worlds
  → InfluxDB: purpose-built, flux query language
  → Prometheus: metrics-specific, pull model

Câu hỏi 5: Full-text search?
  → Elasticsearch: powerful, complex ops
  → Meilisearch: developer-friendly, fast setup, less features
  → Typesense: lightweight, typo-tolerant
  → KHÔNG thay thế primary DB — sync từ primary via CDC

Câu hỏi 6: Graph relationships (social, recommendation)?
  → Neo4j: mature, Cypher query language
  → Amazon Neptune: managed, supports Gremlin + SPARQL
  → Dùng khi traversal nhiều hop: "friends of friends who like X"
```

### PostgreSQL indexing strategy chi tiết

```sql
-- B-tree (default): equality, range, ORDER BY, BETWEEN
CREATE INDEX idx_orders_user ON orders(user_id);
CREATE INDEX idx_orders_date ON orders(created_at DESC);

-- Composite index: leftmost prefix rule — quan trọng!
-- Query: WHERE user_id = ? AND status = ?  → CÓ THỂ dùng index dưới
-- Query: WHERE status = ?                  → KHÔNG dùng được (thiếu user_id)
-- Query: WHERE user_id = ?                 → CÓ THỂ dùng (leftmost prefix OK)
CREATE INDEX idx_orders_user_status ON orders(user_id, status, created_at DESC);

-- Partial index: nhỏ hơn, nhanh hơn B-tree toàn bộ
CREATE INDEX idx_pending ON orders(user_id) WHERE status = 'pending';
-- Chỉ index pending orders → dùng với WHERE status = 'pending'

-- GIN: arrays, JSONB, full-text
CREATE INDEX idx_tags ON posts USING GIN(tags);  -- tags là array
CREATE INDEX idx_metadata ON products USING GIN(metadata jsonb_path_ops);
CREATE INDEX idx_search ON articles USING GIN(to_tsvector('english', title || ' ' || body));

-- GiST: geometric, range types, nearest-neighbor
CREATE INDEX idx_location ON stores USING GIST(coordinates);
-- SELECT * FROM stores ORDER BY coordinates <-> point(10.5, 106.7) LIMIT 10;

-- BRIN: cực nhỏ, chỉ hiệu quả khi column có correlation với physical storage
-- Ví dụ: created_at trong append-only logs
CREATE INDEX idx_logs_time ON logs USING BRIN(created_at) WITH (pages_per_range = 128);

-- Expression index
CREATE INDEX idx_email_lower ON users(LOWER(email));
-- Query: WHERE LOWER(email) = 'test@example.com' → dùng index
-- Query: WHERE email = 'test@example.com'         → KHÔNG dùng

-- Index visibility: Kiểm tra xem query có dùng index không
EXPLAIN (ANALYZE, BUFFERS) SELECT * FROM orders WHERE user_id = 123;
-- Tìm "Index Scan" vs "Seq Scan"
-- Seq Scan với small table là bình thường — planner tự quyết định
```

### N+1 query — phổ biến và dễ bỏ qua

```sql
-- Phát hiện: slow query log hoặc APM (Datadog, New Relic)
-- Query < 1ms nhưng chạy 1000 lần → N+1

-- BAD: 1 query users + N queries orders
SELECT * FROM users LIMIT 100;  -- 1 query
-- for each user: SELECT * FROM orders WHERE user_id = ?  -- 100 queries!

-- GOOD: JOIN
SELECT u.id, u.name, o.id, o.total
FROM users u
LEFT JOIN orders o ON o.user_id = u.id
WHERE u.id IN (SELECT id FROM users LIMIT 100);

-- GOOD: Separate optimized query
SELECT * FROM users LIMIT 100;         -- 1 query, lấy user IDs
SELECT * FROM orders WHERE user_id IN (1,2,3,...100);  -- 1 query

-- ORM: eager loading
-- Prisma: include: { orders: true }
-- Sequelize: include: [Order]
-- Django: prefetch_related('orders')
-- ActiveRecord: includes(:orders)
```

### Connection pooling — critical cho production

```
Vấn đề:
  PostgreSQL max_connections mặc định = 100
  Mỗi connection ~5-10MB RAM
  100 app instances × 10 connections/pool = 1000 connections → DB OOM

PgBouncer transaction mode:
  Client connections: 1000 (app)
  Server connections: 20-50 (DB)
  1 connection serve nhiều clients vì transactions ngắn
  Config: pool_mode = transaction, max_client_conn = 1000, default_pool_size = 25

Lưu ý với PgBouncer transaction mode:
  - KHÔNG dùng với: SET LOCAL, LISTEN/NOTIFY, prepared statements (cần session mode)
  - Prepared statements trong ORM: tắt hoặc dùng session mode cho ORM

Prisma + PgBouncer: cần thêm ?pgbouncer=true&connection_limit=1 vào DATABASE_URL
Django: dùng CONN_MAX_AGE = 0 với PgBouncer transaction mode
```

---

## 4. Scaling Strategy — Đúng Thứ Tự

### Scaling order (don't jump straight to sharding)

```
Bước 1: Query optimization (free, luôn làm trước)
  - EXPLAIN ANALYZE cho slow queries
  - Thêm missing indexes
  - Fix N+1 queries
  - Rewrite inefficient queries
  → Thường giải quyết 80% vấn đề

Bước 2: Connection pooling (PgBouncer)
  - Scale connections mà không scale DB
  → Chi phí: gần như 0

Bước 3: Caching (Redis)
  - Cache read-heavy data
  - Giảm 90% DB reads với cache-aside
  → Chi phí: 1 Redis node ~ $50-100/tháng

Bước 4: Read replicas
  - Horizontal scale reads
  - Read:write ratio > 10:1 → thêm replicas
  - Chi phí bằng 1 DB instance thêm
  - Không cần thay đổi schema hay application (chỉ routing)
  → Thường giải quyết 90% remaining problems

Bước 5: Vertical scaling (upgrade instance)
  - Đơn giản, không cần code changes
  - Nhưng: cost tăng exponential, có ceiling

Bước 6: Table partitioning (trong single DB)
  - PostgreSQL native PARTITION BY RANGE/HASH/LIST
  - Tốt cho: time-series, orders by month, events by user_id
  - Query optimizer tự route đến đúng partition
  - Không thay đổi application code
  → Thường xuyên bị bỏ qua, rất effective

Bước 7: Sharding (LAST RESORT)
  - Chỉ khi write throughput vượt quá single primary
  - Hoặc data size > 5-10TB trong single node
  - Cost: $2M+ implementation, massive complexity
  → Salesforce shards by org_id, PayPal dùng 1024 shards
```

### Table partitioning — alternative tốt hơn sharding

```sql
-- Range partitioning theo thời gian (orders, events, logs)
CREATE TABLE orders (
  id BIGSERIAL,
  user_id BIGINT,
  total DECIMAL,
  created_at TIMESTAMP
) PARTITION BY RANGE (created_at);

CREATE TABLE orders_2024_q1 PARTITION OF orders
  FOR VALUES FROM ('2024-01-01') TO ('2024-04-01');
CREATE TABLE orders_2024_q2 PARTITION OF orders
  FOR VALUES FROM ('2024-04-01') TO ('2024-07-01');

-- Hash partitioning by user_id (distribute load)
CREATE TABLE events (
  id BIGSERIAL,
  user_id BIGINT,
  event_type TEXT
) PARTITION BY HASH (user_id);

CREATE TABLE events_0 PARTITION OF events FOR VALUES WITH (MODULUS 8, REMAINDER 0);
-- ... tạo 8 partitions
-- Query: WHERE user_id = 123 → PostgreSQL tự route đến đúng partition
-- Joins WORK: không như cross-shard
-- Foreign keys WORK: không như cross-shard
-- Aggregations WORK: không như cross-shard
```

### Sharding — khi buộc phải dùng

```
Shard key selection (critical decision — không thể thay đổi sau):
  BAD: Auto-increment ID → sequential, tất cả write vào shard "latest" (hotspot)
  BAD: Timestamp → hotspot tương tự
  BAD: Random UUID → phân phối đều nhưng range queries phải scatter-gather
  GOOD: user_id → distributed, most queries scoped per user
  GOOD: tenant_id (SaaS) → Salesforce model, tenant isolation tự nhiên
  GOOD: Geographic region → data locality, compliance

Cross-shard limitations (không thể tránh):
  - JOIN cross-shard: phải denormalize hoặc application-side join
  - UNIQUE constraint across shards: không native, cần distributed ID generator
  - Foreign keys cross-shard: không support, application phải enforce
  - Transactions cross-shard: 2PC rất chậm, dùng Saga pattern

Tools giảm bớt đau:
  - Vitess: automate shard routing, transparent đến application
  - Citus (PostgreSQL): distributed PostgreSQL, transparent sharding
  - CockroachDB: distributed SQL, automatic sharding, strong consistency
  Nhưng: Tools solve routing, không solve fundamental data distribution problems
```

---

## 5. Caching Chi Tiết

### Cache key design

```
Bad: "products" → quá broad, invalidate toàn bộ khi 1 sản phẩm thay đổi
Bad: "product_1" → không có version/namespace, collision risk

Good patterns:
  products:list:cat=shoes:sort=price:p=2:l=20   → list với params
  products:detail:{id}                           → single item
  users:{userId}:permissions                     → scoped per user
  rate:{userId}:{endpoint}:{window_minute}       → rate limiting
  leaderboard:global:top100                      → leaderboard
  search:query:{hash(query)}                     → search results

Namespace cho batch invalidation:
  Redis SCAN + DEL pattern "products:*"          → xóa tất cả product cache
  Hoặc: Versioning prefix — "v3:products:..."   → đổi v3 → v4 để invalidate all
```

### Redis data structures theo use case

```
String (SET/GET):
  Session store: SET session:{id} {json} EX 3600
  Rate limit counter: INCR + EXPIRE
  Feature flags: SET feature:new_ui:user:{id} 1

Hash (HSET/HGET):
  User profile fields: HSET user:{id} name "An" email "an@test.com"
  Shopping cart: HSET cart:{userId} {productId} {quantity}
  Tốt hơn JSON string khi cần update một field

List (LPUSH/RPOP):
  Job queue: LPUSH jobs {task_json} + BRPOP jobs 0
  Activity feed: LPUSH feed:{userId} {event} + LTRIM feed:{userId} 0 99

Sorted Set (ZADD/ZRANGEBYSCORE):
  Leaderboard: ZADD leaderboard {score} {userId}
              ZREVRANK leaderboard {userId}
  Rate limit (sliding window): ZADD + ZREMRANGEBYSCORE
  Delayed job queue: ZADD delayed {execute_at_timestamp} {job}

Set (SADD/SISMEMBER):
  Online users: SADD online:{roomId} {userId}
  Unique visitors: SADD unique:{date} {userId}
  Tags: SADD post:{id}:tags tag1 tag2

Stream (XADD/XREAD):
  Event log với consumer groups
  Tương tự Kafka nhưng trong Redis
  XADD events * type order_placed data {json}
```

### Thundering herd — 3 solutions thực tế

```python
# Solution 1: Mutex (Redis SET NX)
def get_data(key):
    cached = redis.get(key)
    if cached: return cached

    lock_key = f"lock:{key}"
    acquired = redis.set(lock_key, 1, nx=True, ex=5)  # 5s timeout

    if acquired:
        try:
            data = db.query(key)
            redis.setex(key, 300, data)
            return data
        finally:
            redis.delete(lock_key)
    else:
        time.sleep(0.05)  # 50ms backoff
        return redis.get(key)  # retry

# Solution 2: Probabilistic Early Expiration
def get_with_early_refresh(key, ttl=300):
    item = redis.get(key)  # includes stored_ttl
    if not item: return load_and_cache(key, ttl)

    remaining = redis.ttl(key)
    # Random chance của refresh tăng dần khi gần expire
    if remaining < ttl * 0.1 and random.random() < 0.1:
        asyncio.create_task(background_refresh(key, ttl))

    return item

# Solution 3: Background refresh (best UX, cho phép stale)
def get_data(key):
    data = redis.get(key)
    ttl = redis.ttl(key)

    if data is None:
        data = db.query(key)
        redis.setex(key, 300, data)
    elif ttl < 30:
        # Data sắp expire → refresh async, serve stale ngay
        queue.enqueue(refresh_cache, key)

    return data  # luôn return ngay, kể cả stale
```

### Redis cluster vs Sentinel — khi nào dùng gì

```
Single Redis node:
  Dev, staging, small production
  SPOF: nếu node down → cache miss toàn bộ

Redis Sentinel (HA):
  1 Primary + 2-5 Replicas + 3+ Sentinels
  Auto failover khi primary down (~30-60s)
  Chỉ scale reads (thêm replicas), KHÔNG scale writes
  Phù hợp: Production với HA requirement, < 50GB data

Redis Cluster (horizontal scale):
  16384 hash slots phân phối qua N primary nodes
  Mỗi primary có replicas cho HA
  Scale cả reads và writes
  Minimum: 6 nodes (3 primary + 3 replica)
  
  Limitations so với single node:
  - MULTI/EXEC transaction: chỉ hoạt động nếu tất cả keys cùng slot
  - Lua scripts: tương tự MULTI/EXEC
  - SCAN: phải scan từng node, không phải toàn cluster
  - Cross-slot commands: MGET, SUNION, etc. không work cross-slot

  Workaround hash tags: {user:123}:profile và {user:123}:settings
  → Cùng key trong {} → cùng slot → có thể MGET/transaction

  Phù hợp: > 50GB data, > 100K ops/sec
```

---

## 6. Message Queue Chi Tiết

### Kafka vs RabbitMQ vs SQS

```
Kafka:
  Model: Log-based (messages persist indefinitely, consumers track offset)
  Replay: ✅ Consumer có thể reread từ bất kỳ offset nào
  Throughput: Millions msg/sec
  Ordering: Per partition (không globally)
  Consumer group: Multiple consumers chia nhau partitions
  
  Phù hợp:
    - Event sourcing, audit log (cần replay)
    - Real-time analytics pipeline
    - CDC (Change Data Capture): DB changes → downstream
    - Multiple independent consumers cùng event stream
    - Activity feed, user behavior events
  
  Không phù hợp:
    - Simple task queue (overkill)
    - Team chưa quen với Kafka ops

RabbitMQ:
  Model: Message-oriented middleware (messages deleted sau khi consumed)
  Routing: Exchange types (direct, fanout, topic, headers)
  Consumer: Push-based
  
  Phù hợp:
    - Task queue (email, image processing, notifications)
    - Request/reply RPC pattern
    - Routing phức tạp (route theo header, routing key)
    - Message TTL, priority queues
  
  Dead Letter Queue: x-dead-letter-exchange config

AWS SQS:
  Model: Managed queue, at-least-once delivery
  Visibility timeout: Message ẩn với other consumers khi được receive
  Phù hợp: Simple async task queue trong AWS ecosystem
  FIFO queue: Exactly-once, strict ordering (nhưng throughput giới hạn)

Redis Streams:
  Lightweight Kafka alternative
  Consumer groups, message ACK, persistent
  Phù hợp: Lightweight event streaming, khi đã có Redis
```

### DLQ — bắt buộc phải setup

```
Messages đến DLQ khi:
  - Consumer throw exception sau N retries (default: 3-5 lần)
  - Message TTL expire trước khi processed
  - Queue max-length bị vượt

Retry policy với exponential backoff:
  Attempt 1: immediate
  Attempt 2: 30s delay
  Attempt 3: 5 phút delay
  Attempt 4: 1 giờ delay
  → DLQ

DLQ monitoring:
  Alert ngay khi DLQ.size > 0
  Dashboard tracking DLQ size theo thời gian
  Never let DLQ grow indefinitely without investigation

Reprocessing từ DLQ:
  Sau khi fix bug → move messages từ DLQ về main queue
  Hoặc: Replay với idempotency key để safe
```

### Idempotency — critical

```python
# Message queue deliver "at-least-once" → consumer phải idempotent
# Cùng message có thể arrive 2 lần

# Pattern 1: Redis-based deduplication
def process_message(message):
    dedup_key = f"processed:{message.id}"
    was_set = redis.set(dedup_key, 1, nx=True, ex=86400)  # 24h TTL
    if not was_set:
        logger.info(f"Duplicate message {message.id}, skipping")
        return
    
    # Process message
    do_work(message)

# Pattern 2: Database upsert
def process_order_event(event):
    # ON CONFLICT = idempotent
    db.execute("""
        INSERT INTO order_events (event_id, order_id, type, processed_at)
        VALUES ($1, $2, $3, NOW())
        ON CONFLICT (event_id) DO NOTHING
    """, [event.id, event.order_id, event.type])

# Pattern 3: Outbox pattern (đảm bảo DB write + queue publish atomic)
# Vấn đề: DB write thành công nhưng queue publish fail → inconsistent
# Solution:
#   1. Trong cùng DB transaction: write business data + write to outbox table
#   2. Separate process poll outbox → publish to queue → mark as published
#   Atomic vì cùng DB transaction, không dùng distributed transaction
```

---

## 7. API Design Edge Cases

### REST pagination

```
Offset pagination: GET /posts?offset=100&limit=20
  Vấn đề 1: Performance
    SELECT * FROM posts OFFSET 100000 LIMIT 20
    → DB phải skip 100,000 rows → O(offset) performance
    → Với table 10M rows và offset 9,999,980 → rất chậm
  
  Vấn đề 2: Data drift
    User đang đọc page 5 → new post inserted trang 1
    → Tất cả posts shift → user thấy duplicate ở page 5
  
  Phù hợp: Admin dashboard, finite data, không cần performance

Cursor pagination: GET /posts?cursor=eyJpZCI6MTIzfQ&limit=20
  Cursor = base64({"id": 123, "created_at": "2024-01-15T10:00:00Z"})
  WHERE (created_at, id) < (cursor_ts, cursor_id)
  ORDER BY created_at DESC, id DESC
  LIMIT 20
  
  → Stable khi insert mới (không shift)
  → O(1) performance với proper index
  → Limitation: Không thể jump đến trang cụ thể
  
  Response:
  {
    "data": [...],
    "pagination": {
      "next_cursor": "eyJpZCI6MTAzfQ",
      "has_more": true,
      "total": null  // thường không biết total với cursor
    }
  }
  
  Phù hợp: Feed, chat history, infinite scroll, API với large datasets
```

### API versioning và deprecation

```
URL versioning (recommended):
  /api/v1/users → /api/v2/users
  Rõ ràng, cacheable, dễ test, routing dễ

Bao giờ nên bump major version:
  - Remove field trong response
  - Đổi field name
  - Đổi behavior của existing endpoint
  - Đổi authentication scheme

Không cần bump:
  - Thêm optional field trong response
  - Thêm optional request parameter
  - Thêm mới endpoint

Deprecation process đầy đủ:
  1. Announce: email, changelog, docs — ít nhất 6 tháng trước
  2. Deprecation-Warning header: "This API version is deprecated. See docs.example.com/migrate"
  3. Sunset header: Sunset: Sat, 1 Jan 2026 00:00:00 GMT
  4. Monitoring: Track traffic per version, reach out to active users 1 tháng trước sunset
  5. 410 Gone sau sunset date (không 404)
```

### Idempotency keys cho POST

```
POST /payments không idempotent bình thường
Vấn đề: Network timeout → client retry → double charge

Solution: Idempotency-Key header
  POST /payments
  Idempotency-Key: uuid-v4-per-payment-attempt
  
  Server:
  1. Check nếu key đã exist trong Redis/DB
  2. Nếu có → return cached response
  3. Nếu không → process → store (key → response) với TTL 24h → return
  
  Stripe dùng approach này
  
  Edge cases:
  - Đang xử lý request với cùng key → 409 Conflict (hoặc wait và return)
  - Key expire sau 24h → client phải dùng new key (retry với new intent)
  - Response cần deterministic: same key → same response
```

---

## 8. Scalability Patterns

### Stateless design pitfalls

```
CẦN move ra ngoài app server:
  Sessions → Redis/DB
  Uploaded files → S3 (không local disk)
  Scheduled jobs → Dedicated scheduler (không cron trên app server)
  WebSocket state → Redis pub/sub hoặc dedicated service

File upload anti-pattern:
  Client → API Server → lưu local disk
  Problem: 3 instances → file chỉ ở 1 instance → 2/3 requests fail

Correct pattern:
  1. Client request presigned S3 URL từ API
  2. Client upload trực tiếp lên S3 (bypass API server)
  3. Client notify API "upload done" với S3 key
  4. API xử lý file (scan virus, resize, etc.) via async job
  Benefits: API server không bottleneck, scalable, cheap
```

### Circuit Breaker chi tiết

```
States:
  Closed: Requests flow normally, track failures
  Open: Requests fail immediately without attempting (fast fail)
  Half-Open: Allow limited requests to test recovery

Thresholds (ví dụ):
  Closed → Open: 5 failures trong 10 requests (50% failure rate)
  Open → Half-Open: Sau 30 seconds timeout
  Half-Open → Closed: 3 consecutive successes
  Half-Open → Open: 1 failure

Với fallback:
  - Return cached response (stale but available)
  - Return default/empty response
  - Return error với clear message (không crash cascade)

Libraries:
  Node.js: opossum, cockatiel
  Java: Resilience4j (successor of Hystrix)
  .NET: Polly
  Python: pybreaker, circuitbreaker
  Go: gobreaker

Bulkhead pattern (kết hợp với Circuit Breaker):
  Isolate failures: Thread pool/connection pool riêng per downstream service
  Service A có pool 20 connections đến DB
  Service B có pool 10 connections đến Payment
  → Payment slow không ảnh hưởng DB connections của Service A
```

---

---

## 9. Service Mesh & Sidecar Pattern

### Tại sao cần Service Mesh

```
Microservices problem: Mỗi service phải tự handle:
  - mTLS, certificate rotation
  - Retry logic, circuit breaking
  - Observability (traces, metrics)
  - Traffic management (canary, A/B)
  - Load balancing

→ Same code duplicated across 20 services, 5 languages
→ Hard to change consistently

Service Mesh: Tách những concerns này ra infrastructure layer
  Service → Sidecar proxy (Envoy) → handles all networking
  Application code chỉ lo business logic
```

### Sidecar Pattern

```
Mỗi service pod có 2 containers:
  ┌──────────────────────────────┐
  │ Pod                          │
  │  ┌──────────────┐  ┌──────┐ │
  │  │  App (8080)  │  │Envoy │ │
  │  │              │◄─┤Proxy │ │
  │  └──────────────┘  │15001 │ │
  │                    └──────┘ │
  └──────────────────────────────┘

All traffic in/out qua Envoy proxy
Envoy handles: mTLS, retry, tracing, rate limit, circuit break
App code không thay đổi

Control Plane (Istiod):
  Pushes config tới tất cả Envoy sidecars
  Certificate management (SPIFFE/SPIRE)
  Traffic policies
```

### Istio — phổ biến nhất

```yaml
# mTLS giữa tất cả services (zero-trust networking)
apiVersion: security.istio.io/v1beta1
kind: PeerAuthentication
metadata:
  name: default
  namespace: production
spec:
  mtls:
    mode: STRICT  # Reject non-mTLS traffic

---
# Circuit breaker
apiVersion: networking.istio.io/v1alpha3
kind: DestinationRule
metadata:
  name: payment-service
spec:
  host: payment-service
  trafficPolicy:
    outlierDetection:
      consecutiveGatewayErrors: 5
      interval: 30s
      baseEjectionTime: 30s
      maxEjectionPercent: 50

---
# Canary: 10% traffic to new version
apiVersion: networking.istio.io/v1alpha3
kind: VirtualService
metadata:
  name: order-service
spec:
  hosts: [order-service]
  http:
    - route:
        - destination: { host: order-service, subset: v2 }
          weight: 10
        - destination: { host: order-service, subset: v1 }
          weight: 90
```

### Service Mesh trade-offs

```
Pros:
  ✅ mTLS cho tất cả service-to-service (zero trust)
  ✅ Retry, circuit breaking không cần code change
  ✅ Distributed tracing tự động
  ✅ Traffic splitting cho canary
  ✅ Rate limiting tập trung

Cons:
  ❌ Sidecar overhead: ~50MB memory per pod, ~5-10ms latency
  ❌ Complexity: Steep learning curve, debugging khó hơn
  ❌ Istiod là thêm 1 component cần maintain
  ❌ Overkill cho small teams (< 10 services)

When to use:
  YES: > 10 microservices, security requirements cao, large team
  NO: Monolith, small microservices setup, team chưa có K8s expertise

Alternatives nếu không muốn full service mesh:
  Linkerd: Lighter, simpler, Rust-based (vs Envoy C++)
  Cilium Service Mesh: eBPF-based, no sidecar (kernel level)
  mTLS without mesh: cert-manager + custom retry library
```


## 9. GraphQL Schema Design Patterns

### When to use GraphQL vs REST

```
GraphQL phù hợp:
  - Multiple client platforms (web, mobile, tablet) với different data requirements
  - Complex nested data relationships (user → orders → orderItems → product)
  - Client needs to combine multiple resources in single request
  - Rapid frontend iteration, frequent new data requirements
  - Public API với diverse consumers (partners, integrations)

REST phù hợp:
  - Simple CRUD applications
  - File upload/download (GraphQL không handle binary tốt)
  - Caching ở HTTP layer quan trọng (CDN, browser cache)
  - Team chưa quen với GraphQL complexity
  - Microservices với clear bounded contexts (GraphQL có thể trở thành gateway bottleneck)

Hybrid approach (recommended 2025):
  - GraphQL cho client-facing API (BFF pattern)
  - REST/gRPC cho service-to-service communication
  - GraphQL mutations delegate sang async queue cho long-running operations
```

### Schema design — best practices

```graphql
# ❌ BAD: Overly nested mutations
mutation UpdateUser($input: UpdateUserInput!) {
  updateUser(input: $input) {
    user {
      profile {
        address {
          city {
            name
          }
        }
      }
    }
  }
}

# ✅ GOOD: Flat mutations, return meaningful payload
mutation UpdateUser($input: UpdateUserInput!) {
  updateUser(input: $input) {
    user
    errors { field, message }
  }
}

# Union type cho polymorphic responses
union SearchResult = User | Post | Comment

search(query: String!): [SearchResult!]!

# Interface cho shared behavior
interface Node {
  id: ID!
  createdAt: DateTime!
  updatedAt: DateTime!
}

type User implements Node {
  id: ID!
  createdAt: DateTime!
  updatedAt: DateTime!
  email: String!
}

# Cursor-based pagination (relay spec)
type Query {
  users(first: Int, after: String): UserConnection!
}

type UserConnection {
  edges: [UserEdge!]!
  pageInfo: PageInfo!
  totalCount: Int  # expensive, optional
}

type UserEdge {
  cursor: String!
  node: User!
}

type PageInfo {
  hasNextPage: Boolean!
  hasPreviousPage: Boolean!
  startCursor: String
  endCursor: String
}
```

### N+1 query problem trong GraphQL

```
Vấn đề: Resolver chạy N queries cho N items
  Query: { users { name, posts { title } } }
  Execution:
    1 query: SELECT * FROM users
    N queries: SELECT * FROM posts WHERE user_id = ? (cho mỗi user)

Solution: DataLoader pattern (batch + cache)

class UserPostsLoader {
  async batchLoad(userIds: string[]) {
    // Single query thay vì N queries
    const posts = await db.query(
      'SELECT * FROM posts WHERE user_id = ANY($1)',
      [userIds]
    );
    // Group by user_id
    return userIds.map(id => 
      posts.filter(p => p.user_id === id)
    );
  }
}

// Trong resolver
const posts = await context.loaders.userPosts.load(user.id);
// DataLoader tự động batch tất cả calls trong cùng tick
```

### GraphQL security pitfalls

```graphql
# ❌ CRITICAL: Deep queries → DoS
query {
  user {
    friends {
      friends {
        friends { ... 50 levels deep ... }
      }
    }
  }
}
# Solution: Query depth limiting (max depth: 5-10)

# ❌ CRITICAL: Wide queries → DoS
query {
  user {
    field1 field2 field3 ... field100
  }
}
# Solution: Query complexity analysis
# Assign cost: field1=1, expensiveField=10, reject if total > 1000

# ❌ CRITICAL: Introspection trong production
# query { __schema { types { name } } }
# Solution: Disable introspection trong production
# Apollo: introspection: false

# ❌ Rate limiting khó vì tất cả POST /graphql
# Solution: Persisted queries (client gửi query hash, server map to query)
# Hoặc: GraphQL-aware rate limiting (tính complexity per query)

# ✅ Query timeout
# Apollo: plugins với timeout 5-10s

# ✅ Field-level authorization
# @hasRole(role: ADMIN) directive
type User {
  id: ID!
  email: String! @hasRole(role: ADMIN)  # chỉ admin đọc được
}
```

### GraphQL performance patterns

```graphql
# Query batching (Apollo Client tự động)
# Multiple queries trong 1 HTTP request
query {
  user(id: 1) { name }
  user(id: 2) { name }
  user(id: 3) { name }
}

# Query deduplication
# Client request cùng query 2 lần trong short window → merge thành 1

# Persisted Queries (recommended cho production)
# Client: gửi query hash
# Server: lookup hash → full query
# Benefits:
#   - Giảm bandwidth (hash nhỏ hơn query string)
#   - Prevent injection attacks (chỉ execute queries đã register)
#   - CDN cacheable (hash = cache key)

# Automatic Persisted Queries (APQ):
#   1. Client gửi hash + full query (first time)
#   2. Server cache hash → query mapping
#   3. Client chỉ gửi hash (subsequent times)
#   4. Server lookup và execute

# Subscriptions cho realtime
type Subscription {
  orderStatusChanged(orderId: ID!): OrderUpdate!
}

# Implementation: WebSocket (graphql-ws protocol)
# Scaling: Pub/Sub backend (Redis) để sync across instances
```

### Schema evolution — backward compatibility

```graphql
# ✅ Thêm field mới (backward compatible)
type User {
  id: ID!
  email: String!
  phoneNumber: String  # mới, optional
}

# ✅ Thêm optional argument (backward compatible)
type Query {
  users(limit: Int = 10, offset: Int = 0): [User!]!
  users(first: Int, after: String): UserConnection!  # new cursor-based
}

# ❌ Remove field (breaking change)
# Solution: Deprecate trước, remove sau
type User {
  email: String! @deprecated(reason: "Use primaryEmail instead")
  primaryEmail: String!
}

# ❌ Đổi field type (breaking change)
# User.age: Int → User.age: String
# Solution: Tạo field mới, deprecate field cũ

# ❌ Thêm required argument (breaking change)
# Solution: Thêm optional argument với default value
```

---

## 10. Service Mesh & Sidecar Pattern

### Tại sao cần Service Mesh

```
Microservices problem: Mỗi service phải tự handle:
  - mTLS, certificate rotation
  - Retry logic, circuit breaking
  - Observability (traces, metrics)
  - Traffic management (canary, A/B)
  - Load balancing

→ Same code duplicated across 20 services, 5 languages
→ Hard to change consistently

Service Mesh: Tách những concerns này ra infrastructure layer
  Service → Sidecar proxy (Envoy) → handles all networking
  Application code chỉ lo business logic
```

🟠 SHOULD:
- [ ] Estimate QPS, storage, bandwidth trước khi thiết kế
- [ ] EXPLAIN ANALYZE top queries, thêm missing indexes
- [ ] Read replicas nếu read:write ratio > 10:1
- [ ] Table partitioning trước khi xem xét sharding
- [ ] Cache layer với invalidation strategy rõ ràng
- [ ] Circuit breaker cho downstream service calls
- [ ] Idempotency key cho POST endpoints (payment, order)
- [ ] Cursor pagination cho large datasets và realtime feed
- [ ] API versioning strategy documented

🟡 NICE:
- [ ] Thundering herd protection (mutex / probabilistic refresh)
- [ ] Bulkhead pattern (separate connection pools per dependency)
- [ ] `Deprecation` + `Sunset` headers trên deprecated endpoints
- [ ] Distributed rate limiting (Redis token bucket)
- [ ] Query result caching với cache warming strategy
