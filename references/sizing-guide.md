# Sizing Guide — Numbers Cần Nhớ

Dùng để estimate, không phải đo chính xác.
Tất cả numbers là approximate, phụ thuộc hardware / config.

---

## Latency Cheat Sheet

```
Operation                    Approx latency
─────────────────────────────────────────────
L1 cache hit                 ~0.5 ns
L2 cache hit                 ~7 ns
RAM access                   ~100 ns
Mutex lock/unlock            ~25 ns
Redis GET (same DC)          ~0.5–1 ms
SSD sequential read          ~0.1 ms (100 µs)
SSD random read              ~0.1–1 ms
Network same datacenter      ~0.5 ms (500 µs)
PostgreSQL simple query      ~1–5 ms (with index)
HDD seek                     ~10 ms
Network cross-region (Asia–US) ~150–200 ms
Network cross-region (Asia–EU) ~200–250 ms
```

**Rules of thumb:**
- Cache hit vs DB query: ~100–1000× difference
- RAM vs SSD: ~100× difference  
- Same DC vs cross-region: ~300× difference
- Redis vs PostgreSQL: ~10–100× difference cho simple lookup

---

## Throughput (single node, approximate)

```
Component              Reads/sec        Writes/sec
────────────────────────────────────────────────────
PostgreSQL (SSD)       ~50–100K QPS     ~10–30K TPS
PostgreSQL (HDD)       ~5–10K QPS       ~2–5K TPS
MySQL (InnoDB, SSD)    ~50K QPS         ~10K TPS
Redis (single thread)  ~100K ops/sec    ~100K ops/sec
Redis Cluster (6 nodes)~500K ops/sec    ~300K ops/sec
MongoDB                ~50–100K QPS     ~10–20K TPS
Elasticsearch          ~1–5K QPS        ~5–10K docs/sec
Kafka (single broker)  ~1M msg/sec read ~1M msg/sec write
Nginx (reverse proxy)  ~50K req/sec     —
Node.js (simple API)   ~10–50K req/sec  —
```

**Bối cảnh:**
- 1M DAU app: ~350 QPS average, ~1K QPS peak → PostgreSQL đủ dùng
- 10M DAU: ~3.5K QPS → cần read replicas + cache
- 100M DAU (Twitter scale): ~35K QPS → distributed, caching aggressive

---

## Storage Thresholds

```
PostgreSQL single instance:
  Comfortable:  < 500 GB
  Manageable:   < 2 TB (với SSD)
  Cần xem xét: > 1 TB (backup time, vacuum time tăng)
  Critical:     > 5 TB (restore time > 24h)

Consider table partitioning:
  Rows:   > 100M rows trong 1 table
  Size:   > 100 GB cho 1 table
  Benefit: query chỉ scan relevant partitions, vacuum per partition

Consider sharding:
  Write throughput: > 50K TPS sustained không thể vertical scale
  Data size: > 10 TB single instance không feasible
  Rule: Luôn thử partitioning trước sharding

Redis sizing:
  Working set rule: cache 20% hottest data
  1M users × 10KB/user working set = 10GB → Redis r6g.large (13GB) đủ
  Overhead: ~30% above dataset size (metadata, replication buffer)
```

---

## Availability & SLA

```
SLA          Downtime/month    Downtime/year
────────────────────────────────────────────
99%          7.3 giờ           3.65 ngày
99.5%        3.6 giờ           1.83 ngày
99.9%        43.8 phút         8.77 giờ       ← Standard SaaS target
99.95%       21.9 phút         4.38 giờ
99.99%       4.4 phút          52.6 phút      ← Premium / enterprise
99.999%      26 giây           5.26 phút      ← Very hard, very expensive
```

**Composite availability:**
- 3 services, mỗi cái 99.9% → combined: 99.9% × 99.9% × 99.9% = **99.7%**
- Mỗi dependency bạn thêm = giảm availability tổng
- Giải pháp: Circuit breaker + graceful degradation + fallback

**Error budget:**
- 99.9% SLA = 43.8 phút downtime/tháng
- Nếu đã dùng 80% error budget → freeze non-critical deploys
- Nếu đã dùng 100% → freeze tất cả deploys, focus stability

---

## Cache Hit Rate Targets

```
Hit rate     Meaning                       Action
──────────────────────────────────────────────────
< 50%        Cache không hiệu quả          Review key design, TTL, cache size
50–70%       Poor                          Investigate what's missing
70–85%       Acceptable                    Monitor
85–95%       Good                          ─
> 95%        Excellent                     ─
100%         Suspicious                    Stale cache? TTL quá dài?
```

---

## Connection Limits

```
PostgreSQL:
  Default max_connections: 100
  RAM per connection: ~5–10 MB
  Safe ceiling: 200–400 connections với đủ RAM
  PgBouncer transaction mode: 1000 client → 20–50 server connections
  
Redis:
  Default max clients: 10,000
  RAM per client: ~50 KB idle
  Practical limit: 5,000–10,000 concurrent
  
Node.js:
  Default max HTTP keep-alive: 5 connections/host
  Tăng lên: 50–100 nếu gọi nội bộ nhiều
```

---

## Image & Media Sizing

```
Web images (target file sizes):
  Hero/banner:    < 200 KB (WebP/AVIF)
  Product image:  < 100 KB
  Thumbnail:      < 20 KB
  Avatar:         < 10 KB
  Icon/logo SVG:  < 5 KB

Video:
  Streaming: HLS / DASH (adaptive bitrate)
  1080p:  ~5 Mbps = ~37 MB/phút
  720p:   ~2.5 Mbps = ~18 MB/phút
  480p:   ~1 Mbps = ~7.5 MB/phút

Upload limits (reasonable defaults):
  Avatar: 5 MB
  Document: 20 MB
  Video: 500 MB – 2 GB (chunked upload)
```

---

## Bundle Size Budgets (Web)

```
Metric               Budget         Alert
─────────────────────────────────────────
Initial JS (parsed)  < 170 KB       > 300 KB
Initial CSS          < 50 KB        > 100 KB
Total page weight    < 1 MB         > 2 MB
LCP image            < 200 KB       > 500 KB
Font files           < 100 KB/font  > 200 KB

Packages to watch (gzipped size):
  moment.js:    67 KB → replace with dayjs (2 KB)
  lodash:       72 KB → lodash-es with tree shaking, or native
  chart.js:     60 KB → recharts (tree-shakeable)
  antd:         ~1 MB → Shadcn/ui (copy-paste, zero bundle overhead)
  bootstrap:    ~30 KB → Tailwind (purged, ~5–15 KB)
```

---

## Rate Limiting Defaults (Starting Points)

```
Endpoint type                    Limit
────────────────────────────────────────────
Auth (login, register)           5–10 req/min per IP
Password reset                   3 req/hour per email
API (authenticated)              100–1000 req/min per user
API (unauthenticated)            20–60 req/min per IP
File upload                      10 req/min per user
Email send (app-triggered)       100/hour per user
Search                           30 req/min per user
Webhook delivery                 Retry với exponential backoff (5 lần)
```

---

## Cost Ballpark (AWS, ap-southeast-1, 2025)

```
EC2 (On-Demand):
  t3.medium (2 vCPU, 4 GB):     ~$30/tháng
  c6i.xlarge (4 vCPU, 8 GB):    ~$140/tháng
  Reserved 1 năm:               ~40% off

RDS PostgreSQL:
  db.t3.medium:                 ~$60/tháng
  db.r6g.large (16 GB):         ~$180/tháng
  Read replica:                 +same cost as primary

ElastiCache Redis:
  cache.t3.medium:              ~$50/tháng
  cache.r6g.large (13 GB):      ~$140/tháng

Data transfer (egress):
  Same region:                  Free
  Internet (first 100 GB):      $0.09/GB
  CloudFront → Internet:        $0.08/GB (cheaper via CDN)

S3:
  Storage:                      $0.023/GB/tháng
  GET request:                  $0.0004 per 1,000
  PUT/POST:                     $0.005 per 1,000
```

---

## Kubernetes Resource Requests (Starting Points)

```
App type              CPU request   Memory request   CPU limit    Memory limit
───────────────────────────────────────────────────────────────────────────────
Simple API (Node.js)  100m          128Mi            500m         256Mi
Heavy API (Java/JVM)  250m          512Mi            1000m        1Gi
Worker / consumer     100m          256Mi            500m         512Mi
ML inference          500m          1Gi              2000m        2Gi
Redis                 100m          256Mi            500m         (no limit)
PostgreSQL            250m          512Mi            (no limit)   (no limit)

m = millicores (100m = 0.1 CPU)
Mi = Mebibytes, Gi = Gibibytes
```

**Notes:**
- CPU limit: throttle khi exceed (không kill). JVM/GC cần burst → set limit cao hơn hoặc không set.
- Memory limit: OOMKilled khi exceed. Set conservatively vì restart ảnh hưởng user.
- Requests: dùng cho scheduling. Set thực tế (không quá thấp → oversubscription).

---

## 8. GPU & AI Compute Sizing

### Cloud GPU pricing (AWS, 2025 approximate)

```
Inference (serving):
  g4dn.xlarge  (1× T4  16GB):   $0.526/hr   — Good for small models (< 7B params)
  g5.xlarge    (1× A10G 24GB):  $1.006/hr   — Good for 7B-13B models
  g5.48xlarge  (8× A10G 192GB): $16.29/hr   — Large models (70B)
  p3.2xlarge   (1× V100 16GB):  $3.06/hr    — Legacy, A10G better value
  p4d.24xlarge (8× A100 320GB): $32.77/hr   — Foundation model inference

Training:
  p4d.24xlarge  (8× A100 80GB): $32.77/hr
  p5.48xlarge   (8× H100 640GB):$98.32/hr   — Latest, fastest training

Spot discounts: 60-90% off for training (fault-tolerant workloads)
Reserved 1yr:   ~40% off for inference (stable serving)

Rule of thumb:
  7B model inference: 1× A10G ($1/hr) → ~200 req/min
  13B model inference: 2× A10G → ~100 req/min
  70B model inference: 4× A10G → ~30 req/min
  (Numbers vary significantly by sequence length, batch size)
```

### Model memory requirements

```
Formula: Parameters × precision_bytes + KV cache + overhead
  7B model fp16:   7B × 2 bytes = 14GB + 2-4GB overhead = ~18GB → needs 1× A10G (24GB)
  13B model fp16:  13B × 2 bytes = 26GB → needs 2× A10G (48GB) or 1× A100 (40GB)
  70B model fp16:  70B × 2 bytes = 140GB → needs 4× A10G (96GB) or 2× A100 (160GB)
  70B model int4:  70B × 0.5 bytes = 35GB → fits in 2× A10G (48GB) with quantization

Quantization trade-offs:
  fp32:  Full precision, 4 bytes/param → rarely used (too slow/expensive)
  fp16/bf16: Standard serving, 2 bytes/param → good quality
  int8:  2× compression, slight quality loss, 1 byte/param
  int4:  4× compression, noticeable quality loss (GPTQ, AWQ)
  → Use int4/int8 for cost optimization when quality acceptable

vLLM: Best open-source inference server
  PagedAttention: 24× higher throughput than naive implementation
  Continuous batching: Better GPU utilization
  Supports: llama, mistral, qwen, and most HuggingFace models
```

### Inference cost calculator

```
API-based (no GPU management):
  claude-sonnet-4:  $3/M input + $15/M output tokens
  gpt-4o:           $2.5/M + $10/M output
  gpt-4o-mini:      $0.15/M + $0.6/M output

  1000 users × 10 queries/day × 500 tokens avg → 5M tokens/day
  → claude-sonnet: (5M × $3 + 5M × $15) / 1M = $90/day = $2,700/month

Self-hosted (GPU rental + management overhead):
  vLLM on g5.4xlarge (1× A10G 24GB): $1.624/hr → $1,170/month
  Can serve 7B-13B models
  Throughput: ~500 req/min (depending on model/length)
  
  Break-even vs API:
    If self-hosted can serve cheaper than API rate
    Rule of thumb: > 1M tokens/day → self-hosting worth evaluating

Serverless GPU (no idle cost):
  Modal: $0.0002/GPU-second (A10G) → pay only during inference
  Runpod Serverless: Similar pricing
  → Good for spiky, unpredictable workloads
  → Cold start: 5-30 seconds (loading model into GPU memory)
```

### Training vs Fine-tuning cost

```
Full pre-training (never do this yourself):
  GPT-3 scale: ~$5M USD, months of compute
  Llama 2 70B: ~$3M

Full fine-tuning (adjusting all weights):
  Llama 2 7B on 100K examples: ~$200 (p4d.24xlarge × 2 hours)
  Llama 2 70B: ~$2,000

LoRA / QLoRA (parameter-efficient fine-tuning):
  Only train ~1% of parameters (adapters)
  7B model with QLoRA: 1 GPU (A10G, 24GB) for < 24 hours → ~$25
  70B model with QLoRA: 4 GPUs for ~12 hours → ~$800
  Quality: 90-95% of full fine-tuning at 1-5% cost

When to fine-tune vs RAG vs prompting:
  Style/format/behavior → Fine-tuning (few-shot prompting first)
  Domain knowledge → RAG (cheaper, updatable)
  Task-specific structure → Fine-tuning + RAG
  Budget limited → Prompting first, fine-tune if needed
```
