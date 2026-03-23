# Edge Computing & WebAssembly — Reference

Edge computing = run code closer to users (CDN PoPs, not origin servers).
WebAssembly = near-native speed execution in browser AND server environments.
Two converging trends reshaping where and how code runs in 2025.

---

## 1. Edge Computing Landscape

### Why Edge

```
Traditional: All requests → Origin server (1 region)
  User in Tokyo → us-east-1 → 150ms latency
  User in Lagos → us-east-1 → 250ms latency
  All users share same compute → bottleneck at peak

Edge: Code runs at 300+ PoPs globally
  User in Tokyo → Tokyo PoP → 2-5ms latency
  User in Lagos → Johannesburg PoP → 10-20ms latency
  Distributed compute → no single bottleneck

Use cases where edge wins:
  A/B testing: Personalize response at edge (no origin roundtrip)
  Auth middleware: Validate JWT at edge → reject bad requests early
  Geolocation routing: Route user to right backend region
  Rate limiting: Throttle at edge (DDoS protection)
  Static asset serving: Already done by CDN
  SSR for dynamic content: Edge SSR (Next.js on Vercel Edge)
  API proxying: Transform request/response, aggregate APIs
```

### Edge Platforms Comparison

```
Cloudflare Workers:
  Runtime: V8 isolates (JavaScript/TypeScript + WASM)
  Cold start: ~0ms (isolates, not containers)
  CPU limit: 10ms (free) / 50ms (paid) per request
  Memory: 128MB
  Pricing: $5/month for 10M requests
  Durable Objects: Consistent, stateful objects at edge (unique!)
  R2: S3-compatible object storage, no egress fees
  Phù hợp: Low-latency APIs, auth middleware, A/B testing, proxying

Vercel Edge Functions:
  Runtime: V8 isolates (same as Cloudflare) + Next.js integration
  Cold start: ~0ms
  Tightly integrated với Next.js Edge Runtime
  Phù hợp: Next.js apps, middleware, edge SSR

Fastly Compute@Edge:
  Runtime: WebAssembly (any language compiling to WASM)
  Cold start: ~0ms
  Strict security: WASM sandbox, no arbitrary I/O
  Phù hợp: High-security, language flexibility needed

AWS Lambda@Edge / CloudFront Functions:
  Lambda@Edge: Full Node.js, longer cold starts (ms range)
  CloudFront Functions: V8 JS only, 1ms CPU limit, cheapest
  Phù hợp: AWS-native teams, CloudFront integration

Deno Deploy:
  Runtime: V8 + Deno APIs (TypeScript-first)
  Good Deno ecosystem integration
  Phù hợp: Deno-first teams
```

---

## 2. Cloudflare Workers — Deep Dive

### Worker anatomy

```typescript
// src/index.ts
export interface Env {
  // KV Namespace bindings
  CACHE: KVNamespace
  // Durable Object bindings
  RATE_LIMITER: DurableObjectNamespace
  // Environment variables
  API_KEY: string
  // R2 bucket
  ASSETS: R2Bucket
}

export default {
  async fetch(request: Request, env: Env, ctx: ExecutionContext): Promise<Response> {
    const url = new URL(request.url)

    // Route handling
    if (url.pathname.startsWith('/api/')) {
      return handleAPI(request, env, ctx)
    }

    if (url.pathname.startsWith('/assets/')) {
      return serveAsset(url.pathname, env)
    }

    return new Response('Not Found', { status: 404 })
  }
}

async function handleAPI(request: Request, env: Env, ctx: ExecutionContext) {
  // 1. Rate limiting at edge (before hitting origin)
  const clientIP = request.headers.get('CF-Connecting-IP') ?? 'unknown'
  const rateLimiter = env.RATE_LIMITER.get(
    env.RATE_LIMITER.idFromName(clientIP)
  )
  const { allowed, remaining } = await rateLimiter.checkLimit()
  if (!allowed) {
    return new Response('Rate limit exceeded', {
      status: 429,
      headers: { 'Retry-After': '60', 'X-RateLimit-Remaining': '0' }
    })
  }

  // 2. Auth validation at edge
  const token = request.headers.get('Authorization')?.replace('Bearer ', '')
  if (!token || !await validateJWT(token, env.JWT_SECRET)) {
    return new Response('Unauthorized', { status: 401 })
  }

  // 3. Cache check before origin
  const cacheKey = new Request(request.url, request)
  const cachedResponse = await caches.default.match(cacheKey)
  if (cachedResponse) return cachedResponse

  // 4. Forward to origin
  const originResponse = await fetch(`https://api.myapp.com${new URL(request.url).pathname}`, {
    headers: request.headers,
    method: request.method,
    body: request.body,
  })

  // 5. Cache successful responses
  if (originResponse.status === 200) {
    const responseToCache = new Response(originResponse.body, originResponse)
    responseToCache.headers.set('Cache-Control', 'public, max-age=60')
    ctx.waitUntil(caches.default.put(cacheKey, responseToCache.clone()))
    return responseToCache
  }

  return originResponse
}
```

### Durable Objects — Stateful Edge

```typescript
// Unique: Consistent stateful objects at edge
// Each Durable Object is a single-threaded actor with storage
// Great for: rate limiting, collaboration, game state, sessions

export class RateLimiter {
  private state: DurableObjectState
  private counts: Map<string, { count: number; resetAt: number }> = new Map()

  constructor(state: DurableObjectState) {
    this.state = state
  }

  async fetch(request: Request): Promise<Response> {
    const body = await request.json() as { key: string; limit: number; windowMs: number }
    const { key, limit, windowMs } = body

    const now = Date.now()
    const entry = this.counts.get(key)

    if (!entry || now > entry.resetAt) {
      // New window
      this.counts.set(key, { count: 1, resetAt: now + windowMs })
      return Response.json({ allowed: true, remaining: limit - 1 })
    }

    if (entry.count >= limit) {
      return Response.json({ allowed: false, remaining: 0 })
    }

    entry.count++
    return Response.json({ allowed: true, remaining: limit - entry.count })
  }
}

// Usage from Worker:
async function checkRateLimit(env: Env, key: string): Promise<boolean> {
  const id = env.RATE_LIMITER.idFromName(key)  // Same key → same DO instance globally
  const obj = env.RATE_LIMITER.get(id)
  const response = await obj.fetch('https://do/', {
    method: 'POST',
    body: JSON.stringify({ key, limit: 100, windowMs: 60_000 })
  })
  const { allowed } = await response.json() as { allowed: boolean }
  return allowed
}
```

### KV vs Durable Objects vs R2

```
KV (Key-Value store):
  Eventual consistency (may be stale up to 60s)
  Global replication (reads from nearest PoP)
  Fast reads (~1ms), slow writes (must propagate globally)
  Phù hợp: Config, feature flags, static-ish data, caching

Durable Objects:
  Strong consistency (single authoritative instance)
  Low latency writes (located near creator/first request)
  Serialized requests (no concurrent modification)
  Phù hợp: Rate limiting, collaborative state, sessions, counters

R2 (Object Storage):
  Like S3 but NO egress fees
  Eventual consistency for objects
  Phù hợp: Static files, user uploads, data export files

Comparison:
  KV: 128MB max value, 1B keys per namespace
  DO: 128KB max value (storage API), unlimited writes
  R2: 5GB max object size, S3-compatible API
```

---

## 3. WebAssembly (WASM)

### What WASM solves

```
Problem 1: Performance-critical code in browser
  JavaScript: Interpreted, GC pauses, single-threaded by default
  WASM: Near-native speed, predictable performance, no GC (for compiled languages)
  Use cases: Image/video processing, cryptography, game engine, CAD, scientific computing

Problem 2: Run any language on any platform
  Compile C/C++/Rust/Go/Python → WASM binary
  WASM binary runs in browser, Node.js, Cloudflare Workers, standalone WASM runtimes
  "Write once, run everywhere" (actually works this time)

Problem 3: Sandboxed plugin systems
  Untrusted third-party code runs in WASM sandbox
  Cannot access host memory unless explicitly shared
  Figma plugins, Shopify functions, Fastly Compute@Edge
```

### WASM in the browser

```typescript
// Load and use WASM module (Rust compiled to WASM)
// cargo build --target wasm32-unknown-unknown --release

async function loadImageProcessor() {
  const { default: init, process_image } = await import('./image_processor_bg.wasm')
  await init()  // Initialize WASM module

  // Use exported function (Rust function exposed to JS)
  const inputBytes = new Uint8Array(imageFile.arrayBuffer())
  const outputBytes = process_image(inputBytes, { quality: 85, format: 'webp' })
  return new Blob([outputBytes], { type: 'image/webp' })
}

// Performance: WASM image processing 5-10x faster than pure JS
// Real use: Figma, AutoCAD Web, Google Earth, Zoom web client
```

### WASI — WASM System Interface

```
WASM originally: Browser sandbox, no file/network/OS access
WASI: Standard API for WASM to access OS capabilities in controlled way
  wasi:filesystem  → File read/write
  wasi:sockets     → Network connections
  wasi:clocks      → System time
  wasi:random      → Random numbers

WASM + WASI = Run WASM outside browser:
  Wasmtime (Rust runtime): wasmtime my-app.wasm
  WasmEdge: Optimized for cloud/edge
  Spin (Fermyon): HTTP framework for WASM microservices

WASM on server use cases:
  Serverless functions: Sub-millisecond cold start vs 100ms+ for containers
  Plugin systems: Allow customers to run custom code safely (Shopify Functions)
  Edge computing: Cloudflare Workers, Fastly Compute@Edge
  Embedded scripting: Extend app with user-defined logic
```

### Rust + WASM — recommended stack

```rust
// lib.rs — Rust compiled to WASM
use wasm_bindgen::prelude::*;

#[wasm_bindgen]
pub fn process_csv(csv_data: &str) -> String {
    let mut reader = csv::Reader::from_reader(csv_data.as_bytes());
    let mut results: Vec<serde_json::Value> = Vec::new();

    for record in reader.records() {
        let record = record.unwrap();
        results.push(serde_json::json!({
            "name": &record[0],
            "value": record[1].parse::<f64>().unwrap_or(0.0)
        }));
    }

    serde_json::to_string(&results).unwrap()
}

// Build: wasm-pack build --target web
// Output: pkg/my_module_bg.wasm + pkg/my_module.js (JS bindings)
```

**When to use Rust+WASM vs pure JS:**
```
Use Rust+WASM:
  CPU-heavy: parsing, encoding, cryptography, compression
  Need predictable latency (no GC pauses)
  Existing Rust codebase to port to web
  Performance benchmark shows JS is bottleneck

Stay with JS:
  DOM manipulation (WASM cannot access DOM directly without JS bridge)
  Simple business logic
  Team not familiar with Rust
  Performance is acceptable
```

---

## 4. Edge-Native Architecture Patterns

### Auth at Edge (Zero Origin Calls for Auth)

```
Traditional: Every request → Origin validates JWT → response
  100 requests = 100 auth checks at origin

Edge auth:
  JWT validation at edge (no origin call)
  Edge has public key (JWKS endpoint cached)
  Invalid JWT → 401 at edge, never reaches origin

  // Cloudflare Worker: validate JWT
  import { jwtVerify, importSPKI } from 'jose'

  async function validateToken(token: string, env: Env): Promise<boolean> {
    try {
      const publicKey = await importSPKI(env.JWT_PUBLIC_KEY, 'RS256')
      await jwtVerify(token, publicKey, {
        issuer: 'https://auth.myapp.com',
        audience: 'https://api.myapp.com',
      })
      return true
    } catch {
      return false
    }
  }

Result: 100% of invalid requests stopped at edge
Origin only sees authenticated requests
```

### Edge Caching with Stale-While-Revalidate

```typescript
// Pattern: Return stale content instantly, update in background
export default {
  async fetch(request: Request, env: Env, ctx: ExecutionContext) {
    const cache = caches.default
    const cacheKey = new Request(request.url)

    const cachedResponse = await cache.match(cacheKey)

    if (cachedResponse) {
      const age = parseInt(cachedResponse.headers.get('Age') ?? '0')
      const maxAge = 60   // Serve stale up to 60s
      const swr = 3600    // Revalidate in background up to 1h

      if (age < maxAge) {
        return cachedResponse  // Fresh: return immediately
      }

      if (age < maxAge + swr) {
        // Stale: Return stale, revalidate in background
        ctx.waitUntil(revalidate(request, env, cache, cacheKey))
        return cachedResponse
      }
    }

    // Cache miss or too stale: fetch from origin
    return revalidate(request, env, cache, cacheKey)
  }
}
```

### Geo-routing at Edge

```typescript
// Route user to nearest backend region
export default {
  async fetch(request: Request) {
    const country = request.cf?.country  // Cloudflare provides geo data
    const continent = request.cf?.continent

    const backendRegion = getBackendRegion(country, continent)

    const backendUrl = `https://${backendRegion}.api.myapp.com`
    return fetch(new Request(backendUrl + new URL(request.url).pathname, request))
  }
}

function getBackendRegion(country?: string, continent?: string): string {
  if (continent === 'AS') return 'ap-southeast-1'
  if (continent === 'EU') return 'eu-west-1'
  if (country === 'AU' || country === 'NZ') return 'ap-southeast-2'
  return 'us-east-1'  // default
}
```

---

## 5. Edge Limitations & Edge Cases

```
CPU time limits:
  Cloudflare Workers free: 10ms CPU per request
  Workers paid: 50ms CPU
  This is CPU time, not wall clock — await does not count
  Long computation → "Worker exceeded CPU limit" → 503
  Fix: Offload heavy work to origin, use streaming

Memory limits:
  Workers: 128MB
  Large in-memory operations → OOM → 503
  Fix: Stream data, process in chunks

Cold starts:
  Workers: ~0ms (V8 isolates reused, not containers)
  Lambda@Edge: 100ms+ cold start
  Implication: Workers better for latency-sensitive paths

No filesystem:
  Workers have no persistent disk access
  State: KV, Durable Objects, R2, external DB
  Cannot: npm install at runtime, read local files

Limited Node.js APIs:
  Workers runtime ≠ Node.js
  Missing: fs, child_process, net, crypto.createCipheriv (limited)
  Available: fetch, WebCrypto, Cache API, Workers-specific APIs
  Tools: workers-rs (Rust), workers-py (Python via WASM)

Debugging:
  No local breakpoints in edge environment
  wrangler dev: Local simulation (not 100% same as production)
  Console.log → Cloudflare dashboard logs (not real-time locally)
```

---

## 6. Decision Trees

```
Muốn giảm latency cho users globally?
  Static assets → CDN đủ (không cần edge functions)
  Dynamic content → Edge SSR (Next.js + Vercel Edge) hoặc Workers
  API responses → Edge caching với SWR pattern
  Auth validation → JWT validation at edge (Workers)

Chọn edge platform?
  Already on Cloudflare → Cloudflare Workers + Durable Objects
  Next.js focused → Vercel Edge Functions
  Multi-language (Rust, Go) → Fastly Compute@Edge (WASM-based)
  AWS native → CloudFront Functions (simple) hoặc Lambda@Edge (complex)

WASM hoặc JS tại edge?
  Simple routing, auth, transforms → JS/TypeScript (simpler)
  CPU-intensive (parsing, compression) → WASM (performance)
  Existing Rust/C++ library → WASM (port to edge)

Stateful edge?
  Session state, rate limiting, real-time collaboration → Durable Objects
  Configuration, feature flags → KV (eventual consistency OK)
  File storage → R2

WASM use case?
  Browser performance bottleneck → WASM (Rust/C++)
  Plugin system with untrusted code → WASM sandbox
  Server-side edge functions → WASM via WASI
  Cross-platform library (web + native) → WASM target
```

---

## Checklist Edge & WASM

> 🔴 MUST | 🟠 SHOULD | 🟡 NICE

🔴 MUST:
- [ ] CPU time budget verified (không exceed 10-50ms limit per request)
- [ ] Error handling: Worker errors return proper HTTP responses (không crash silently)
- [ ] Secrets: Use Worker secrets (env vars), không hardcode
- [ ] CORS headers set correctly cho cross-origin requests

🟠 SHOULD:
- [ ] JWT validation at edge (không mọi request hit origin cho auth)
- [ ] Cache-Control headers đúng để edge cache hiệu quả
- [ ] Geo-routing nếu app có multi-region backend
- [ ] Rate limiting tại edge (không để DDoS reach origin)
- [ ] Monitoring: Worker error rate, CPU time percentiles
- [ ] wrangler.toml reviewed: environments, routes, bindings documented

🟡 NICE:
- [ ] Durable Objects cho stateful rate limiting (thay Redis round-trip)
- [ ] R2 thay S3 nếu egress costs significant
- [ ] WASM module cho CPU-heavy operations (image processing, parsing)
- [ ] A/B testing logic tại edge (không origin)
- [ ] Edge analytics (không sampling, full request data)

---

## 7. WASM Component Model

### What it solves

```
Current WASM problem:
  Each WASM module is an island — share memory via linear memory (unsafe, complex)
  No standard way to compose WASM modules
  Language-specific bindings needed per language pair

Component Model (W3C standard, 2024):
  Type-safe interfaces between WASM components
  Any language → any language (Rust component ↔ Python host ↔ Go component)
  Interface Types: Rich types (strings, records, variants) across boundary
  Composition: Wire components together like Unix pipes

```

### WIT — WebAssembly Interface Types

```wit
// world.wit — define component interface
package mycompany:image-processor@1.0.0;

interface transform {
  record resize-options {
    width: u32,
    height: u32,
    format: string,
    quality: u8,
  }

  resize: func(image-data: list<u8>, options: resize-options) -> list<u8>;
  watermark: func(image-data: list<u8>, text: string) -> list<u8>;
}

world image-processor {
  export transform;
}
```

```rust
// Rust component implementing the interface
use bindings::exports::mycompany::image_processor::transform::*;

struct Component;

impl Guest for Component {
    fn resize(image_data: Vec<u8>, options: ResizeOptions) -> Vec<u8> {
        let img = image::load_from_memory(&image_data).unwrap();
        let resized = img.resize(options.width, options.height, image::imageops::Lanczos3);
        // ... encode and return
    }
}

// Build: cargo component build --release
// Output: image-processor.wasm (self-describing component)
```

```typescript
// Consume Rust WASM component from JavaScript host (jco)
import { imageProcessor } from './image-processor.js'  // Generated bindings

const resized = imageProcessor.transform.resize(imageData, {
  width: 800, height: 600, format: 'webp', quality: 85
})
```

### Why Component Model matters for system design

```
Microservices but for functions (not services):
  Each function compiled to WASM component
  Compose at edge, in browser, on server
  Language-agnostic: Python ML component + Rust perf component + Go business logic

Use cases:
  Plugin systems: SaaS allow customers to run custom code (safe sandbox)
    Shopify Functions, Fastly Compute — already using this model
  Edge composition: Chain WASM components without network hops
  WebAssembly-native serverless: Spin (Fermyon) fully supports components
  
Current state (2025):
  Core spec stable, tooling maturing
  wasmtime 23+ has good component model support
  jco (JavaScript component tooling) v1.0 released
  Not yet mainstream but production-ready for early adopters
```

---

## 8. Testing Cloudflare Workers with Miniflare

### Miniflare — local Worker simulation

```typescript
// Local development and testing without deploying
// npm install -D miniflare wrangler

// vitest.config.ts
import { defineConfig } from 'vitest/config'

export default defineConfig({
  test: {
    environment: 'miniflare',
    environmentOptions: {
      bindings: { API_KEY: 'test-api-key' },       // Env vars
      kvNamespaces: ['CACHE'],                       // KV namespaces
      durableObjects: { RATE_LIMITER: 'RateLimiter' },
      r2Buckets: ['ASSETS'],
    },
  },
})

// worker.test.ts
import { describe, it, expect, beforeAll } from 'vitest'
import { unstable_dev } from 'wrangler'

describe('Worker', () => {
  let worker: UnstableDevWorker

  beforeAll(async () => {
    worker = await unstable_dev('src/index.ts', {
      experimental: { disableExperimentalWarning: true }
    })
  })

  afterAll(async () => await worker.stop())

  it('returns 200 for authenticated requests', async () => {
    const resp = await worker.fetch('/', {
      headers: { Authorization: 'Bearer valid-token' }
    })
    expect(resp.status).toBe(200)
  })

  it('returns 401 for unauthenticated requests', async () => {
    const resp = await worker.fetch('/')
    expect(resp.status).toBe(401)
  })

  it('rate limits after 10 requests', async () => {
    const requests = Array.from({ length: 11 }, () =>
      worker.fetch('/', { headers: { 'CF-Connecting-IP': '1.2.3.4' } })
    )
    const responses = await Promise.all(requests)
    const lastStatus = responses[10].status
    expect(lastStatus).toBe(429)
  })
})
```

### Testing KV and Durable Objects

```typescript
// KV testing
import { env } from 'cloudflare:test'

it('caches API responses in KV', async () => {
  // Pre-populate KV
  await env.CACHE.put('product:123', JSON.stringify({ name: 'Widget', price: 9.99 }))

  const resp = await worker.fetch('/products/123')
  const data = await resp.json()
  expect(data.name).toBe('Widget')

  // Verify no outgoing fetch (served from KV)
  // Use vi.spyOn(globalThis, 'fetch') to intercept
})

// Durable Object testing
it('enforces rate limits correctly', async () => {
  // Each test gets fresh DO state
  const id = env.RATE_LIMITER.idFromName('test-user')
  const stub = env.RATE_LIMITER.get(id)

  // Make 10 requests — all should succeed
  for (let i = 0; i < 10; i++) {
    const resp = await stub.fetch('https://do/', {
      method: 'POST',
      body: JSON.stringify({ key: 'test', limit: 10, windowMs: 60000 })
    })
    const { allowed } = await resp.json()
    expect(allowed).toBe(true)
  }

  // 11th request should be denied
  const resp = await stub.fetch('https://do/', {
    method: 'POST',
    body: JSON.stringify({ key: 'test', limit: 10, windowMs: 60000 })
  })
  const { allowed } = await resp.json()
  expect(allowed).toBe(false)
})
```
