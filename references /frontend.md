# Frontend Web Architecture — Reference

---

## 1. Rendering Strategy Chi Tiết

### Real-world performance numbers (2025 benchmarks)

| Strategy | TTFB | FCP | Notes |
|----------|------|-----|-------|
| SSG + CDN cache hit | 20–50ms | ~50ms | Fastest possible |
| SSG + CDN cache miss | 50–200ms | ~200ms | Cold start CDN |
| Edge SSR (warm) | 37–60ms | ~100ms | Vercel Edge, Cloudflare |
| Edge SSR (cold start) | 60–250ms | ~300ms | Không phải 5ms như quảng cáo |
| Serverless SSR (warm) | 103–154ms | ~300ms | Vercel serverless |
| Traditional SSR (uncached) | 300–900ms | ~600ms | Server-dependent |
| CSR (JS download + execute) | ~100ms | 1.5–4s | Depends on bundle size |

### When to use what — with clear trade-offs

**CSR (Vite, Create React App)**:
- Dashboard sau login, app không cần SEO
- Real-time data (WebSocket, streaming)
- Trade-off: FCP chậm (blank screen cho đến khi JS load và execute)
- Với median JS bundle > 500KB (HTTP Archive 2024): TTI > 3s trên mobile 3G

**SSR (Next.js App Router, Remix)**:
- Product pages, blog, landing pages cần SEO
- Personalized content (cart, recommendations)
- Trade-off: Server phải render mỗi request → tốn CPU → cần scale server
- React hydration cost không negligible: Wix thấy INP kém do hydration toàn bộ page

**SSG (Next.js getStaticProps, Astro)**:
- Docs, marketing, blog không cần realtime
- Trade-off: Build time và stale content
- 60K pages × 100ms/page = 1.7 giờ build → cần ISR

**ISR (Next.js revalidate)**:
- E-commerce catalog, blog với frequent updates
- Hybrid: Pre-build popular pages, generate rest on demand
- Trade-off: User có thể thấy stale content trong revalidation window

**React Server Components (Next.js App Router)**:
- Zero JS gửi xuống client cho non-interactive components
- Data fetching trên server, không cần useEffect + loading states
- Trade-off: Flight payload overhead khi pass large data qua Server→Client boundary
- Phù hợp nhất khi: nhiều data fetching, ít interactivity trên page

**Partial Pre-rendering (Next.js 14+ experimental)**:
- Static shell (instant) + Dynamic holes (streamed)
- Best of SSG + SSR trên cùng 1 page

### Hydration — deep problems và solutions

**Hydration mismatch — nguyên nhân đầy đủ**:
```tsx
// Nguyên nhân 1: Date/timezone
// Server render: "Jan 15, 2024 UTC"
// Client render: "Jan 16, 2024 UTC+7" → mismatch
function PostDate({ date }) {
  return <time>{date.toLocaleDateString()}</time>  // BAD
}
// Fix:
function PostDate({ date }) {
  const [mounted, setMounted] = useState(false)
  useEffect(() => setMounted(true), [])
  if (!mounted) return <time dateTime={date.toISOString()}>{date.toISOString()}</time>
  return <time>{date.toLocaleDateString()}</time>  // only runs on client
}

// Nguyên nhân 2: Math.random(), Date.now() trong render
const id = Math.random()  // BAD: khác giữa server và client
// Fix: Dùng stable ID (useId() từ React 18)
const id = useId()  // stable, same trên server và client

// Nguyên nhân 3: localStorage/window access trong render
const theme = localStorage.getItem('theme')  // BAD: server không có localStorage
// Fix: 
const [theme, setTheme] = useState('light')
useEffect(() => setTheme(localStorage.getItem('theme') ?? 'light'), [])

// Nguyên nhân 4: Browser extension inject DOM
// suppressHydrationWarning trên element bị extension inject
<body suppressHydrationWarning>
```

**React Server Components pitfalls**:
```tsx
// Flight payload overhead — hay bị bỏ qua
// BAD: Pass entire dataset qua Server→Client boundary
async function ServerPage() {
  const products = await db.getProducts()  // 10,000 rows
  return <ClientChart data={products} />   // toàn bộ serialize vào Flight payload
}

// GOOD: Filter/transform trên server, chỉ pass cần thiết
async function ServerPage() {
  const summary = await db.getProductSummary()  // chỉ aggregated data
  return <ClientChart data={summary} />
}

// Mistake: "use client" quá rộng
"use client"  // tất cả children cũng trở thành client components
export function Page() { ... }  // BAD: không cần thiết

// Good pattern: Client components nhỏ, server components lớn
// Server: fetch data, render structure
// Client: chỉ phần cần interactivity (button, form, animation)
```

**Selective hydration (React 18 Suspense)**:
```tsx
// Pattern: Lazy hydrate below-the-fold content
// Wix dùng approach này → 40% cải thiện INP
import { lazy, Suspense } from 'react'

function Page() {
  return (
    <>
      {/* Above fold: hydrate ngay */}
      <HeroSection />
      <Suspense fallback={<Skeleton />}>
        {/* Below fold: hydrate khi scroll tới */}
        <lazy.ProductReviews />
      </Suspense>
      <Suspense fallback={<Skeleton />}>
        <lazy.RelatedProducts />
      </Suspense>
    </>
  )
}
```

### Core Web Vitals — diagnosis và fix

```
LCP > 2.5s → diagnose theo thứ tự:
  1. Server TTFB > 600ms?
     → Fix: CDN, cache, server optimization
  2. LCP element là ảnh?
     → Fix: preload, priority prop, WebP/AVIF, CDN
  3. LCP element là text bị font blocking?
     → Fix: font-display: swap, preload font
  4. LCP element là background-image CSS?
     → Fix: Chuyển sang <img> (CSS background không preloadable)

INP > 200ms → diagnose:
  1. Long task trên main thread?
     → DevTools Performance: tìm tasks > 50ms
     → Fix: Break up với scheduler.yield() hoặc setTimeout
  2. JavaScript bundle quá lớn (parse cost)?
     → Fix: Code splitting, lazy loading
  3. React re-renders không cần thiết?
     → Fix: memo, useMemo, useCallback đúng chỗ
  4. Event handler expensive?
     → Fix: Debounce, throttle, move work off main thread (Worker)

CLS > 0.1 → diagnose:
  1. Images thiếu width/height?
     → Fix: Luôn set width/height hoặc aspect-ratio
  2. Font swap gây text shift?
     → Fix: font-display: optional (không swap nếu font chưa load)
  3. Dynamic content inject above existing content?
     → Fix: Reserve space với min-height, skeleton placeholders
  4. Ads inject sau khi render?
     → Fix: Reserve ad slots trước
```

---

## 2. State Management

### Mental model đầy đủ

```
Server state  → React Query / TanStack Query / SWR
  Tất cả data từ API
  Handle: caching, deduplication, background refetch, optimistic updates
  KHÔNG nhét vào Zustand/Redux

URL state  → useSearchParams (Next.js), React Router
  Filters: ?category=shoes&color=red
  Pagination: ?page=2&limit=20
  Sort: ?sort=-price
  Tab: ?tab=reviews
  Lợi ích: shareable URL, back button works, SSR-friendly

Form state  → React Hook Form (> 3 fields)
  RHF uncontrolled by default → performance tốt hơn
  Validation: Zod schema

Local UI state  → useState / useReducer
  Modal open/close, hover state, accordion
  Không lift up nếu không cần share

Global state  → Zustand / Jotai
  Auth user info, cart, theme, notifications
  Chỉ khi nhiều components xa nhau cần cùng state
```

### React Query edge cases

```tsx
// Stale time vs Cache time
useQuery({
  queryKey: ['user', userId],
  queryFn: fetchUser,
  staleTime: 5 * 60 * 1000,   // 5 phút: không refetch nếu data < 5 phút tuổi
  gcTime: 10 * 60 * 1000,     // 10 phút: xóa khỏi cache sau 10 phút unused
})

// Race condition với optimistic updates
const mutation = useMutation({
  mutationFn: updateTodo,
  onMutate: async (newData) => {
    // Cancel in-flight queries để tránh overwrite optimistic update
    await queryClient.cancelQueries({ queryKey: ['todos'] })
    const previous = queryClient.getQueryData(['todos'])
    queryClient.setQueryData(['todos'], old =>
      old.map(t => t.id === newData.id ? { ...t, ...newData } : t)
    )
    return { previous }
  },
  onError: (err, newData, context) => {
    queryClient.setQueryData(['todos'], context.previous)
    toast.error('Failed to update')
  },
  onSettled: () => queryClient.invalidateQueries({ queryKey: ['todos'] })
})

// Infinite scroll với cursor pagination
const { data, fetchNextPage, hasNextPage, isFetchingNextPage } = useInfiniteQuery({
  queryKey: ['posts'],
  queryFn: ({ pageParam }) => fetchPosts({ cursor: pageParam }),
  initialPageParam: undefined,
  getNextPageParam: (lastPage) => lastPage.nextCursor,
})

// Prefetching cho navigation
// Hover trên link → prefetch data → instant navigation
const queryClient = useQueryClient()
<Link
  href="/users/123"
  onMouseEnter={() => queryClient.prefetchQuery({
    queryKey: ['user', 123],
    queryFn: () => fetchUser(123),
  })}
>
```

### Zustand pitfalls

```tsx
// Selector không stable → unnecessary re-renders
// BAD:
const { user, cart } = useStore(state => ({ user: state.user, cart: state.cart }))
// Tạo object mới mỗi render → component luôn re-render

// GOOD: Tách selectors
const user = useStore(state => state.user)
const cart = useStore(state => state.cart)

// GOOD: shallow comparison
import { useShallow } from 'zustand/react/shallow'
const { user, cart } = useStore(useShallow(state => ({ user: state.user, cart: state.cart })))

// Middleware stack thường dùng
const useStore = create<Store>()(
  devtools(        // Redux DevTools
    persist(       // localStorage persistence
      immer(       // Immer cho immutable updates dễ hơn
        (set) => ({
          user: null,
          setUser: (user) => set(state => { state.user = user }),
          // Immer cho phép "mutate" state trực tiếp
        })
      ),
      { name: 'app-store' }
    )
  )
)
```

---

## 3. Performance Optimization

### Bundle analysis workflow

```
Step 1: Baseline
  next build --analyze  →  open .next/analyze/client.html
  Tìm: Modules > 50KB trong bundle (thường suspects: moment, lodash, chart.js)

Step 2: Common replacements
  moment.js (67KB gzipped) → dayjs (2KB) hoặc date-fns (tree-shakeable)
  lodash (72KB) → lodash-es + tree shaking hoặc native equivalents
  chart.js (60KB) → recharts (tree-shakeable) hoặc lightweight alternatives

Step 3: Code splitting
  // Route-level: mặc định trong Next.js App Router
  // Component-level:
  const HeavyEditor = dynamic(() => import('./Editor'), {
    ssr: false,
    loading: () => <Skeleton />
  })
  // Library:
  const handleExport = async () => {
    const { jsPDF } = await import('jspdf')
    // jsPDF chỉ load khi cần
  }

Step 4: Monitor regression
  .github/workflows/bundle-check.yml
  npx size-limit → fail CI nếu bundle tăng > 10KB
  Hoặc: Bundlemon, Compressed Size Action
```

### INP optimization (thay thế FID từ 2024)

```
INP đo: Worst interaction latency trong session (p98)
Target: < 200ms (good), < 500ms (needs improvement)

DoorDash: LCP giảm 65%, loại bỏ slow-loading URLs bằng SSR
Preply: INP giảm xuống < 200ms → +35K monthly Google impressions

Common INP killers:
1. Synchronous state updates blocking render
   Fix: useTransition để mark non-urgent updates
   const [isPending, startTransition] = useTransition()
   startTransition(() => setFilter(newFilter))  // render không block input

2. Long event handlers
   Fix: Yield to main thread
   button.addEventListener('click', async () => {
     processFirstPart()
     await scheduler.yield()  // yield → browser có thể render
     processSecondPart()
   })

3. Third-party scripts (analytics, ads, chat)
   Fix: Load async, defer, hoặc web worker
   <Script src="analytics.js" strategy="lazyOnload" />

4. Context value updates re-rendering too many components
   Fix: Split context, memo, Zustand (fine-grained subscriptions)
```

### Long Tasks và Main Thread

```
Quy tắc: Tasks > 50ms trên main thread → blocked UI → INP tăng

Detect: PerformanceObserver
const observer = new PerformanceObserver((list) => {
  for (const entry of list.getEntries()) {
    if (entry.duration > 50) {
      console.warn('Long task:', entry.duration, 'ms')
    }
  }
})
observer.observe({ type: 'longtask' })

Break up long tasks:
// BAD: 1 synchronous task xử lý 10,000 items
items.forEach(item => heavyProcess(item))

// GOOD: yield periodically
async function processItems(items) {
  for (let i = 0; i < items.length; i++) {
    heavyProcess(items[i])
    if (i % 100 === 0) {
      await scheduler.yield()  // yield every 100 items
    }
  }
}

// BETTER: Web Worker cho CPU-heavy work
const worker = new Worker('/heavy-worker.js')
worker.postMessage({ items })
worker.onmessage = (e) => setResults(e.data)
```

---

## 4. Micro-frontends

### Module Federation — edge cases chi tiết

```
Vấn đề 1: Shared dependency version conflict
  Host: React 18.2.0
  Remote: React 18.0.0
  → 2 React instances → hooks fail, context không work

  Fix trong webpack.config.js:
  shared: {
    react: {
      singleton: true,    // chỉ 1 instance
      requiredVersion: '^18.0.0',
      eager: true,        // load trong initial chunk
    },
    'react-dom': { singleton: true, requiredVersion: '^18.0.0', eager: true }
  }

Vấn đề 2: Type sharing
  Types không share qua Module Federation
  
  Solution A: Shared types npm package
    @company/shared-types → publish lên private registry
    
  Solution B: @module-federation/typescript plugin
    Tự động generate và share types

Vấn đề 3: CSS isolation
  Remote styles leak vào host
  
  Solution A: CSS Modules (scoped class names)
  Solution B: Shadow DOM cho remote
  Solution C: Strict naming convention + audit với CSS linter

Vấn đề 4: Error boundary tránh crash cascade
  <ErrorBoundary
    fallback={<div>Feature unavailable</div>}
    onError={(err) => monitoring.captureException(err)}
  >
    <Suspense fallback={<Skeleton />}>
      <RemoteProductSection />
    </Suspense>
  </ErrorBoundary>
  // Remote crash → fallback, không crash host

Vấn đề 5: Circular dependency
  Remote A dùng Remote B dùng Remote A → deadlock
  
  Fix: Extract shared code vào separate shared package
  A → shared-lib ← B  (no circular)
```

### Communication patterns giữa MFEs

```
1. URL / Route state — tốt nhất cho navigation
  Shell: /products/123 → ProductMFE nhận productId từ URL

2. Custom events — lightweight, native browser API
  // Publish
  window.dispatchEvent(new CustomEvent('cart:item:added', {
    detail: { productId: 123, quantity: 2 },
    bubbles: true
  }))
  // Subscribe
  window.addEventListener('cart:item:added', (e) => updateCartBadge(e.detail))
  // Limitation: Không typed, dễ typo

3. Typed event bus library
  import { createEventBus } from '@company/event-bus'
  type Events = {
    'cart:updated': { count: number }
    'user:logout': void
  }
  const bus = createEventBus<Events>()

4. Props từ shell app
  Shell cung cấp: user, permissions, config → truyền xuống MFEs
  Phù hợp cho: shared auth context, feature flags

5. Shared Zustand store — dùng cẩn thận
  Chỉ cho truly global state (auth, theme)
  Không cho domain state (cart, product catalog)
  → Coupling quá chặt → phá vỡ independence
```

---

## 5. Islands Architecture (2025 trend)

### Astro và partial hydration

```
Islands: Chỉ hydrate interactive components, phần còn lại là static HTML
Tốt cho: Content-heavy sites với ít interactivity (docs, blogs, marketing)
Không phù hợp: App-like interfaces (dashboard, editor, social)

Astro directives:
  client:load     → hydrate ngay khi page load
  client:idle     → hydrate khi browser idle
  client:visible  → hydrate khi enter viewport (lazy)
  client:media    → hydrate khi media query matches

Kết quả thực tế:
  0 JS gửi cho non-interactive content
  Interactive islands hydrate independently
  Performance: LCP, INP excellent vì ít JS
```

---

---

## 6. Web Workers & Off-Main-Thread

### Tại sao quan trọng cho INP

```
Main thread = chỉ 1 thread cho: JS execution + layout + paint + user events
Long task (> 50ms) trên main thread → blocked input → INP tăng

Web Workers: Background threads cho CPU-heavy work
  Worker KHÔNG có access: DOM, window, document
  Worker CÓ access: fetch, WebSockets, IndexedDB, crypto, canvas offscreen

Use cases thực tế:
  Image processing: resize, compress, filter
  Large data parsing: CSV/JSON parsing, data transformation
  Cryptography: hashing, encryption
  Search indexing: build local search index
  Complex calculations: financial, scientific
```

### Comlink — ergonomic Worker API

```typescript
// worker.ts — runs in background thread
import * as Comlink from 'comlink'

const api = {
  async processCSV(csvString: string): Promise<ParsedRow[]> {
    // This runs off main thread — no UI blocking
    const rows: ParsedRow[] = []
    const lines = csvString.split('
')
    for (const line of lines) {
      rows.push(parseRow(line))
    }
    return rows
  },

  async searchProducts(query: string, products: Product[]): Promise<Product[]> {
    // Fuzzy search — CPU intensive
    return fuzzysort.go(query, products, { key: 'name' })
      .map(r => r.obj)
  }
}

Comlink.expose(api)

// main.ts — clean async interface
const worker = new Worker(new URL('./worker.ts', import.meta.url))
const workerApi = Comlink.wrap<typeof api>(worker)

// Feels like async function, actually runs in worker thread
const results = await workerApi.processCSV(largeCsvData)
```

### scheduler.yield() — cooperative multitasking

```typescript
// Break long synchronous work into chunks, yield to browser between each
async function processLargeList(items: Item[]) {
  const CHUNK_SIZE = 100

  for (let i = 0; i < items.length; i++) {
    processItem(items[i])

    // Yield to main thread every 100 items
    // Browser can handle input events, repaint, etc.
    if (i % CHUNK_SIZE === 0) {
      await scheduler.yield()
    }
  }
}

// Even simpler: setTimeout 0
async function yieldToMain() {
  return new Promise(resolve => setTimeout(resolve, 0))
}
```

---

## 7. Next.js Server Actions

### Pattern và khi nào dùng

```typescript
// app/actions.ts — "use server" marks server-only code
'use server'

import { revalidatePath } from 'next/cache'
import { redirect } from 'next/navigation'
import { db } from '@/lib/db'

// Server Action: runs on server, callable from client
export async function createOrder(formData: FormData) {
  const items = JSON.parse(formData.get('items') as string)
  const userId = await getCurrentUserId()  // Server-only (auth session)

  // Direct DB access — no API layer needed
  const order = await db.orders.create({
    data: { userId, items, status: 'pending' }
  })

  // Revalidate cached pages
  revalidatePath('/orders')

  // Redirect (server-side)
  redirect(`/orders/${order.id}`)
}

// Component: calls server action directly
export default function CheckoutForm() {
  return (
    <form action={createOrder}>   {/* Next.js wires this up */}
      <input type="hidden" name="items" value={JSON.stringify(cartItems)} />
      <button type="submit">Place Order</button>
    </form>
  )
}

// Or: call from useTransition for loading state
function CheckoutButton({ items }: { items: Item[] }) {
  const [isPending, startTransition] = useTransition()

  const handleCheckout = () => {
    startTransition(async () => {
      const formData = new FormData()
      formData.set('items', JSON.stringify(items))
      await createOrder(formData)
    })
  }

  return (
    <button onClick={handleCheckout} disabled={isPending}>
      {isPending ? 'Processing...' : 'Place Order'}
    </button>
  )
}
```

### Server Actions vs API Routes

```
Server Actions:
  ✅ Less boilerplate: No separate API route file
  ✅ Direct DB access from form
  ✅ Type-safe: TypeScript end-to-end
  ✅ Progressive enhancement: Works without JS
  ❌ Only works với Next.js App Router
  ❌ Cannot be called from mobile app or external services

API Routes (app/api/...):
  ✅ Works from any client (mobile, external services, scripts)
  ✅ Fine-grained control over HTTP methods, headers
  ✅ Better for public APIs
  ❌ More boilerplate

Rule: Server Actions cho internal form submissions + data mutations.
      API Routes cho anything consumed outside Next.js app.
```


---

## 8. Progressive Web Apps (PWA) & Service Workers

### When PWA makes sense

```
PWA = Web app that can be installed and works offline
Not every app needs PWA — evaluate before investing

Use PWA when:
  App used on mobile but App Store distribution overhead too high
  Offline or intermittent connectivity critical (field workers, travel)
  Push notifications needed without native app
  Fast second visit load critical (Service Worker caches assets)

Skip PWA when:
  Need deep hardware access (ARKit, Bluetooth, NFC)
  App Store presence / discoverability important
  iOS Safari limitations block required features (PWA still limited on iOS)

iOS PWA limitations (2025):
  No background sync
  No push notifications via Web Push (added iOS 16.4+ but unreliable)
  No splash screen customization
  App removed from home screen after 60 days of non-use (iOS 17.4+ partially fixed)
  → If iOS is primary platform: build native app instead
```

### Service Worker fundamentals

```typescript
// public/sw.js — service worker runs in background thread
// Lifecycle: Install → Activate → Fetch intercept

const CACHE_NAME = 'app-v1.2.0'
const STATIC_ASSETS = ['/index.html', '/app.js', '/app.css', '/offline.html']

// Install: Cache static assets
self.addEventListener('install', (event: ExtendableEvent) => {
  event.waitUntil(
    caches.open(CACHE_NAME)
      .then(cache => cache.addAll(STATIC_ASSETS))
      .then(() => self.skipWaiting())  // Activate immediately
  )
})

// Activate: Clean up old caches
self.addEventListener('activate', (event: ExtendableEvent) => {
  event.waitUntil(
    caches.keys()
      .then(keys => Promise.all(
        keys
          .filter(key => key !== CACHE_NAME)
          .map(key => caches.delete(key))
      ))
      .then(() => self.clients.claim())  // Take control of all pages
  )
})

// Fetch: Serve from cache or network
self.addEventListener('fetch', (event: FetchEvent) => {
  const { request } = event

  // Strategy: Stale-while-revalidate for API, Cache-first for static
  if (request.url.includes('/api/')) {
    // Network first, fallback to cache
    event.respondWith(
      fetch(request)
        .then(response => {
          const cloned = response.clone()
          caches.open(CACHE_NAME).then(c => c.put(request, cloned))
          return response
        })
        .catch(() => caches.match(request))
    )
  } else {
    // Cache first, fallback to network
    event.respondWith(
      caches.match(request)
        .then(cached => cached ?? fetch(request))
        .catch(() => caches.match('/offline.html'))
    )
  }
})
```

### Cache strategies

```
Cache first (static assets):
  CSS, JS, images → cache first, network fallback
  Pros: Fastest load, works offline
  Cons: Stale content until version bump

Network first (API data):
  Fresh data first, cache fallback when offline
  Pros: Always current when online
  Cons: Slow on bad connections

Stale-while-revalidate (best for most content):
  Return cache immediately, update cache in background
  User sees: Instant (cached) then updated on next visit
  Best for: News, product lists, any content that can be slightly stale

Network only (auth, payments):
  Never cache sensitive endpoints
  Pros: Always current, no stale auth state
```

### Workbox — production SW library

```typescript
// Don't write Service Worker from scratch — use Workbox
// vite-plugin-pwa (for Vite), next-pwa (for Next.js)

// vite.config.ts
import { VitePWA } from 'vite-plugin-pwa'

export default defineConfig({
  plugins: [
    VitePWA({
      registerType: 'autoUpdate',
      workbox: {
        globPatterns: ['**/*.{js,css,html,ico,png,svg}'],
        runtimeCaching: [
          {
            urlPattern: /^https:\/\/api\.myapp\.com\//,
            handler: 'StaleWhileRevalidate',
            options: {
              cacheName: 'api-cache',
              expiration: { maxEntries: 100, maxAgeSeconds: 60 * 60 },  // 1h
            },
          },
          {
            urlPattern: /^https:\/\/cdn\.myapp\.com\//,
            handler: 'CacheFirst',
            options: {
              cacheName: 'cdn-cache',
              expiration: { maxEntries: 500, maxAgeSeconds: 7 * 24 * 60 * 60 },  // 1w
            },
          },
        ],
      },
      manifest: {
        name: 'My App',
        short_name: 'App',
        theme_color: '#4f46e5',
        background_color: '#ffffff',
        display: 'standalone',        // Hides browser UI when installed
        start_url: '/',
        icons: [
          { src: 'icon-192.png', sizes: '192x192', type: 'image/png' },
          { src: 'icon-512.png', sizes: '512x512', type: 'image/png', purpose: 'maskable' },
        ],
      },
    }),
  ],
})

// Register SW in main.tsx
if ('serviceWorker' in navigator) {
  navigator.serviceWorker.register('/sw.js')
}
```

### Background sync

```typescript
// Queue failed requests → replay when back online
self.addEventListener('sync', (event: SyncEvent) => {
  if (event.tag === 'sync-orders') {
    event.waitUntil(syncPendingOrders())
  }
})

async function syncPendingOrders() {
  const pending = await getPendingOrdersFromIndexedDB()
  for (const order of pending) {
    try {
      await fetch('/api/orders', { method: 'POST', body: JSON.stringify(order) })
      await removePendingOrder(order.id)
    } catch {
      throw new Error('Sync failed — will retry')  // SW retries automatically
    }
  }
}

// Trigger sync registration from app code
async function placeOrder(order: Order) {
  await savePendingOrderToIndexedDB(order)
  if ('serviceWorker' in navigator && 'sync' in ServiceWorkerRegistration.prototype) {
    const reg = await navigator.serviceWorker.ready
    await reg.sync.register('sync-orders')
  } else {
    // Fallback: Try immediately if background sync not supported
    await submitOrder(order)
  }
}
```


## Checklist trước khi ship

> 🔴 MUST = block ship | 🟠 SHOULD = fix trước prod | 🟡 NICE = tech debt

🔴 MUST:
- [ ] Không có XSS vectors (`dangerouslySetInnerHTML` với user content → `DOMPurify`)
- [ ] Không lưu token trong `localStorage` — dùng `httpOnly` cookie
- [ ] Error boundaries tồn tại cho critical sections
- [ ] App không crash hoàn toàn khi API fail (graceful degradation)

🟠 SHOULD:
- [ ] Bundle analyzed — không có chunks > 200KB gzipped unexpected
- [ ] LCP image preloaded (`priority` prop hoặc `<link rel="preload">`)
- [ ] CLS = 0 — images có `width`/`height`, dynamic content không shift layout
- [ ] INP < 200ms — không có long tasks > 100ms trên main thread
- [ ] Server state dùng React Query/SWR (không Redux/Zustand cho API data)
- [ ] URL state cho filters, pagination, sort (shareable, bookmarkable)
- [ ] Hydration mismatches handled (timezone, IDs, browser-only APIs)
- [ ] Code splitting: route-level tối thiểu, heavy libs lazy loaded
- [ ] A11y: keyboard navigation, focus management, color contrast ≥ 4.5:1
- [ ] Lighthouse CI trong pipeline

🟡 NICE:
- [ ] RSC: không pass large datasets qua Server→Client boundary
- [ ] `useTransition` cho non-urgent updates (filter, search)
- [ ] `scheduler.yield()` trong long synchronous operations
- [ ] `<link rel="prefetch">` cho likely next routes
- [ ] Bundle size budget enforced trong CI (`size-limit`)
- [ ] Visual regression tests (Chromatic) cho components
