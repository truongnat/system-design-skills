# Decision Trees — Quick Picks

Use this file before diving into detailed reference materials.
Format: Question → Answer in ≤ 4 steps.

---

## Choosing a database

```
Need ACID + complex JOIN?
  YES → PostgreSQL ← default for every new project in 2025
  NO  ↓

Flexible schema / nested / document-based?
  YES → MongoDB (general) | Firestore (real-time sync mobile/web)
  NO  ↓

Key-value lookup, extreme speed, simple structure?
  YES → Redis (in-memory, sub-ms) | DynamoDB (managed, serverless-friendly)
  NO  ↓

Time-series (metrics, IoT, events, logs)?
  YES → TimescaleDB (PostgreSQL extension) | InfluxDB | Prometheus
  NO  ↓

Full-text search?
  YES → Meilisearch (simple) | Typesense (lightweight) | Elasticsearch (powerful)
  ⚠ DO NOT replace primary DB — sync from primary via CDC/webhook
  NO  ↓

Graph / multi-hop relationship traversal?
  YES → Neo4j | Amazon Neptune
  NO  → PostgreSQL is still the right answer
```

---

## Choosing a rendering strategy (web)

```
App behind login, SEO not important, heavy interactivity?
  YES → CSR (Vite)
  NO  ↓

Personalized content (cart, feed, profile)?
  YES → SSR (Next.js App Router / Remix)
  NO  ↓

Frequently updated content (< once/hour), need SEO?
  YES → ISR (Next.js revalidate: 60)
  NO  ↓

Static content (docs, marketing, landing)?
  YES → SSG (Astro, Next.js getStaticProps)
  NO  → ISR with short revalidate (30–60s)
```

---

## Choosing a cache strategy

```
When does data change?
  Never / rarely → CDN cache + long TTL (1h–1d)
  Occasionally, eventual consistency OK → Cache-aside + TTL
  Frequently, need high consistency → Write-through
  Write-heavy, eventual consistency OK → Write-behind / write-around
  Real-time (stock, live score) → No cache / very short TTL (1–5s)

Where to cache?
  Static assets (JS, CSS, images) → CDN
  API responses, computed data → Redis (application cache)
  DB query results → Redis or in-process cache
  Rendered HTML → CDN edge + ISR
```

---

## Scaling decision

```
Performance problem?
  YES → MEASURE FIRST: EXPLAIN ANALYZE query, check CPU/mem metrics
  
Slow query?
  → Add index → solves 80% of cases
  
DB connections exhausted?
  → PgBouncer connection pooling
  
Read-heavy (ratio > 10:1)?
  → Read replicas
  
Table > 100M rows or > 100GB?
  → Table partitioning (RANGE/HASH) in a single DB
  
Server CPU/memory maxed out?
  → Vertical scale first (simpler)
  → Horizontal scale next (stateless app servers)
  
Write throughput maxed (> 50K TPS sustained)?
  → Sharding — LAST RESORT, irreversible
```

---

## Choosing an AI engineering approach

```
Corpus size?
  < 10K docs:   pgvector + OpenAI embeddings
  10K–1M docs:  Pinecone, Weaviate, Qdrant
  > 1M docs:    Milvus, sharded vector DB

Query type?
  FAQ / exact match → BM25 keyword search
  Semantic meaning → Dense vector search
  Mixed (most cases) → Hybrid search + reranker

Agent or RAG?
  One-shot Q&A from documents → RAG
  Multi-step task, need tools/actions → Agent
  Mixed: Agentic RAG
```
