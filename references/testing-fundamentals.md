# Testing Fundamentals — Reference

Phần 1/2 của testing skill. Cover: philosophy, unit, integration, E2E, contract,
performance, visual regression, mobile, security, frontend component testing, anti-patterns.
Phần 2 (automation process): `references/testing-automation.md`

---

# Testing — Reference

Testing không phải afterthought — là công cụ thiết kế. Tests tốt bắt bugs sớm,
enable refactoring tự tin, và document behavior chính xác hơn bất kỳ wiki nào.

---

## 1. Testing Philosophy

### Test Pyramid vs Test Trophy vs Test Honeycomb

```
Classic Pyramid (Michael Feathers, 2009):
         /E2E\              ← Ít, chậm, flaky
        /──────\
       /Integr. \           ← Vừa
      /──────────\
     / Unit Tests \         ← Nhiều, nhanh
    /──────────────\

Trophy (Kent C. Dodds, 2019) — phổ biến hơn với frontend:
           /E2E\            ← Ít
          /──────\
         /Integr. \         ← NHIỀU NHẤT (testing-library style)
        /──────────\
       /   Unit    \        ← Vừa (pure functions, utils)
      /──────────────\
     /    Static     \      ← TypeScript, ESLint (free)
    /────────────────────\

Honeycomb (Spotify, microservices):
  Nhiều Integration tests, ít Unit, rất ít E2E
  Vì: Unit tests microservice thường chỉ test mock, không realistic
```

**Rule thực tế**: Không có một pyramid "đúng". Chọn theo:
- Frontend app → Trophy (integration tests nhiều nhất)
- Backend service → Pyramid (unit nhiều, integration vừa)
- Microservices → Honeycomb (integration + contract nhiều)
- Mobile → Unit + Integration + thủ công exploratory

### Testing Confidence vs Speed trade-off

```
Speed (fast → slow):    Static → Unit → Integration → E2E → Manual
Confidence (low → high): Static → Unit → Integration → E2E → Manual

Mục tiêu: Maximize confidence với minimum time
→ Đẩy bugs lên pyramid càng cao càng tốn kém
→ Bug caught bởi unit test: 30 giây fix
→ Bug caught bởi QA: 2 ngày fix
→ Bug caught bởi user: 1 tuần + reputation damage
```

---

## 2. Unit Testing

### When to write unit tests

```
Nên unit test:
  ✅ Pure functions (input → output, no side effects)
  ✅ Business logic / domain rules
  ✅ Edge cases và error conditions
  ✅ Utility functions
  ✅ Algorithms, data transformations
  ✅ Validation logic

Không cần unit test:
  ❌ Trivial getters/setters
  ❌ Framework boilerplate (Express route wiring)
  ❌ Config files
  ❌ Database migrations
  ❌ Code chỉ gọi third-party library trực tiếp
```

### Test structure — AAA pattern

```ts
describe('OrderService.placeOrder', () => {
  it('should apply 10% discount for orders over 1,000,000 VND', () => {
    // ARRANGE: Setup
    const items = [
      { productId: 'p1', quantity: 2, price: 600_000 },
    ]

    // ACT: Call the thing
    const order = OrderService.calculateTotal(items)

    // ASSERT: Verify outcome
    expect(order.subtotal).toBe(1_200_000)
    expect(order.discount).toBe(120_000)  // 10%
    expect(order.total).toBe(1_080_000)
  })
})
```

### Naming conventions — test như documentation

```ts
// Pattern: "should [expected behavior] when [condition]"
it('should throw InvalidEmailError when email has no @ symbol')
it('should return empty array when no products match filter')
it('should not apply discount when order is below threshold')

// Hoặc Given-When-Then:
it('given premium user, when placing order, should waive shipping fee')
```

### Test doubles — phân biệt rõ

```ts
// STUB: Return canned value, không verify calls
const paymentGateway = {
  charge: jest.fn().mockResolvedValue({ success: true, transactionId: 'txn_123' })
}

// MOCK: Verify behavior (đã call gì, bao nhiêu lần, với args gì)
const emailService = { send: jest.fn() }
await orderService.placeOrder(order)
expect(emailService.send).toHaveBeenCalledOnce()
expect(emailService.send).toHaveBeenCalledWith(
  expect.objectContaining({ to: 'customer@example.com' })
)
// Chú ý: Mock verify calls, stub chỉ return value

// FAKE: Real implementation nhưng simplified
class InMemoryProductRepo implements ProductRepository {
  private products = new Map<string, Product>()
  async findById(id: string) { return this.products.get(id) ?? null }
  async save(p: Product) { this.products.set(p.id, p); return p }
  async findAll() { return [...this.products.values()] }
}

// SPY: Wrap real implementation, record calls
const consoleSpy = jest.spyOn(console, 'error').mockImplementation(() => {})
// ... run code that might log errors
expect(consoleSpy).toHaveBeenCalledWith(expect.stringContaining('validation'))
consoleSpy.mockRestore()  // QUAN TRỌNG: restore sau test

// DUMMY: Placeholder, không dùng thực sự
const dummyLogger = { info: () => {}, error: () => {}, warn: () => {} }
```

### Mocking pitfalls

```ts
// Pitfall 1: Mock quá nhiều → test không test thực tế
// BAD:
jest.mock('./database')
jest.mock('./cache')
jest.mock('./emailService')
jest.mock('./paymentGateway')
// Khi đó test chỉ test "does it call the right functions" không phải business logic

// GOOD: Mock chỉ I/O boundaries, test real business logic
// Mock DB → dùng in-memory fake
// Test toàn bộ service logic với fake dependencies

// Pitfall 2: Mock implementation leak giữa tests
// BAD: mock không reset
const mockFn = jest.fn()
// Test 1: mockFn.mockReturnValue(1)
// Test 2: mockFn.mockReturnValue(2) -- nhưng Jest vẫn nhớ call từ test 1!

// GOOD:
beforeEach(() => {
  jest.clearAllMocks()  // clear calls/instances
  // hoặc jest.resetAllMocks() -- cũng reset implementations
  // hoặc jest.restoreAllMocks() -- restore spies về original
})

// Pitfall 3: Mock không match actual interface
jest.mock('./userService', () => ({
  getUser: jest.fn().mockReturnValue({ id: 1, name: 'Test' })
  // Thiếu field 'email' mà production code expect → test pass, prod fail
}))
// GOOD: Dùng TypeScript để enforce mock shape
const mockUserService = createMockUserService()  // typed factory
```

### Code coverage — đừng bị obsess

```
Coverage types:
  Line coverage:    % lines executed
  Branch coverage:  % branches (if/else, switch) taken
  Function:         % functions called
  Statement:        % statements executed

Targets thực tế:
  Business logic core: > 90%
  API handlers:        > 80%
  Utility functions:   > 85%
  UI components:       > 70% (integration test covers nhiều hơn)
  
  KHÔNG cần 100%: Config files, migrations, third-party wrappers, 
                  error handlers khó trigger, main entry files

Gamification trap:
  Developers viết tests chỉ để tăng số % 
  → Tests không meaningful, không assert bất kỳ điều gì quan trọng
  → "Tests that pass but prove nothing"

Better metric: Mutation testing score (mutmut, Stryker)
  → Thay đổi production code (đổi + thành -, true thành false)
  → Tests fail? Good mutation = tests catch the change
  → Tests still pass? Bad mutation = tests không catch → gap
```

---

## 3. Integration Testing

### Định nghĩa rõ ràng

```
Integration test = test multiple units working together
Không phải: test full system từ UI đến DB (đó là E2E)
Phải là: test 2+ real components cùng nhau, không mock

Ví dụ integration tests tốt:
  - API endpoint + database (real SQL, real transactions)
  - Service + repository (real DB queries)
  - Cache layer + underlying service
  - Event handler + message queue consumer
```

### Test containers — real dependencies, không mocks

```ts
// Testcontainers: spin up real Docker containers cho tests
import { PostgreSqlContainer } from '@testcontainers/postgresql'
import { RedisContainer } from '@testcontainers/redis'

let pgContainer: StartedPostgreSqlContainer
let redisContainer: StartedGenericContainer

beforeAll(async () => {
  pgContainer = await new PostgreSqlContainer('postgres:16-alpine')
    .withDatabase('testdb')
    .withUsername('test')
    .withPassword('test')
    .start()

  redisContainer = await new RedisContainer('redis:7-alpine').start()

  // Run migrations
  await runMigrations(pgContainer.getConnectionUri())
}, 30_000)  // timeout 30s cho container startup

afterAll(async () => {
  await pgContainer.stop()
  await redisContainer.stop()
})

describe('OrderRepository', () => {
  it('should persist order and retrieve by ID', async () => {
    const repo = new OrderRepository(pgContainer.getConnectionUri())
    const order = await repo.save(buildOrder({ status: 'pending' }))
    const found = await repo.findById(order.id)
    expect(found).toMatchObject({ id: order.id, status: 'pending' })
  })
})
```

### API integration tests — test HTTP layer thực sự

```ts
// Supertest (Node.js): HTTP requests against real app, real DB
import request from 'supertest'
import { app } from '../app'
import { db } from '../db'

describe('POST /api/orders', () => {
  beforeEach(async () => {
    await db.execute('TRUNCATE orders, order_items CASCADE')
    // Seed test data
    await db.execute(`INSERT INTO users (id, email) VALUES ('user-1', 'test@test.com')`)
  })

  it('should create order and return 201', async () => {
    const response = await request(app)
      .post('/api/orders')
      .set('Authorization', `Bearer ${generateTestToken('user-1')}`)
      .send({ items: [{ productId: 'p1', quantity: 2 }] })

    expect(response.status).toBe(201)
    expect(response.body).toMatchObject({
      id: expect.any(String),
      status: 'pending',
      userId: 'user-1'
    })

    // Verify DB state (không chỉ verify response)
    const dbOrder = await db.query('SELECT * FROM orders WHERE id = $1', [response.body.id])
    expect(dbOrder.rows).toHaveLength(1)
  })

  it('should return 422 when product does not exist', async () => {
    const response = await request(app)
      .post('/api/orders')
      .set('Authorization', `Bearer ${generateTestToken('user-1')}`)
      .send({ items: [{ productId: 'nonexistent', quantity: 1 }] })

    expect(response.status).toBe(422)
    expect(response.body.error.code).toBe('PRODUCT_NOT_FOUND')
  })

  it('should be idempotent with same Idempotency-Key', async () => {
    const idempotencyKey = crypto.randomUUID()
    const payload = { items: [{ productId: 'p1', quantity: 1 }] }

    const r1 = await request(app).post('/api/orders')
      .set('Idempotency-Key', idempotencyKey).send(payload)
    const r2 = await request(app).post('/api/orders')
      .set('Idempotency-Key', idempotencyKey).send(payload)

    expect(r1.status).toBe(201)
    expect(r2.status).toBe(201)
    expect(r1.body.id).toBe(r2.body.id)  // Same order returned

    const count = await db.query('SELECT COUNT(*) FROM orders')
    expect(Number(count.rows[0].count)).toBe(1)  // Only 1 order created
  })
})
```

### Database isolation strategies

```ts
// Strategy 1: Transaction rollback (fastest, ~5ms overhead)
let tx: Transaction

beforeEach(async () => {
  tx = await db.beginTransaction()
  // Override db in DI container to use this transaction
  container.rebind('db').toConstantValue(tx)
})

afterEach(async () => {
  await tx.rollback()
})

// Limitation: Không test code that commits explicitly

// Strategy 2: Truncate + seed (moderate, ~50-100ms)
beforeEach(async () => {
  await db.execute(`
    TRUNCATE users, orders, products RESTART IDENTITY CASCADE
  `)
  await seedTestData(db)
})

// Strategy 3: Separate schema per test worker (parallel safe)
// Jest --maxWorkers=4 → 4 schemas: test_0, test_1, test_2, test_3
// Each worker uses its own schema → no conflicts
// Vitest natively supports this với parallel mode
```

---

## 4. End-to-End (E2E) Testing

### Playwright best practices (2025 standard)

```ts
// playwright.config.ts
import { defineConfig } from '@playwright/test'

export default defineConfig({
  testDir: './e2e',
  fullyParallel: true,
  retries: process.env.CI ? 2 : 0,
  reporter: [['html'], ['github']],
  use: {
    baseURL: 'http://localhost:3000',
    trace: 'on-first-retry',   // Capture trace khi retry → debug dễ hơn
    screenshot: 'only-on-failure',
    video: 'retain-on-failure',
  },
  projects: [
    { name: 'chromium', use: { ...devices['Desktop Chrome'] } },
    { name: 'mobile-safari', use: { ...devices['iPhone 14'] } },
  ],
})
```

### Page Object Model — tránh brittle tests

```ts
// pages/checkout.page.ts
export class CheckoutPage {
  constructor(private page: Page) {}

  // Locators: prefer getByRole, getByLabel, getByTestId
  // KHÔNG: page.locator('.btn-primary:nth-child(2)')
  private get placeOrderBtn() {
    return this.page.getByRole('button', { name: 'Place order' })
  }
  private get cardNumberInput() {
    return this.page.getByLabel('Card number')
  }
  private get orderConfirmation() {
    return this.page.getByTestId('order-confirmation')
  }

  async fillPayment(card: { number: string; expiry: string; cvv: string }) {
    await this.cardNumberInput.fill(card.number)
    await this.page.getByLabel('Expiry date').fill(card.expiry)
    await this.page.getByLabel('CVV').fill(card.cvv)
  }

  async placeOrder() {
    await this.placeOrderBtn.click()
    await this.orderConfirmation.waitFor({ state: 'visible', timeout: 10_000 })
  }

  async getOrderId() {
    return this.orderConfirmation.getAttribute('data-order-id')
  }
}

// e2e/checkout.spec.ts
test('complete checkout flow', async ({ page }) => {
  const checkout = new CheckoutPage(page)
  const cart = new CartPage(page)

  await cart.addProduct('product-123', 2)
  await cart.proceedToCheckout()
  await checkout.fillPayment(TEST_CARD)
  await checkout.placeOrder()

  const orderId = await checkout.getOrderId()
  expect(orderId).toBeTruthy()
})
```

### Test isolation cho E2E

```ts
// BAD: Share state giữa tests → flaky
test.describe('Checkout', () => {
  test('add to cart', async ({ page }) => { /* mutates shared state */ })
  test('checkout', async ({ page }) => { /* depends on previous test */ })
})

// GOOD: Mỗi test tự setup, không phụ thuộc lẫn nhau
test.beforeEach(async ({ page, request }) => {
  // Tạo fresh user via API (không qua UI = nhanh hơn)
  const user = await request.post('/api/test/users', {
    data: { email: `test-${Date.now()}@test.com` }
  })
  const { token } = await user.json()

  // Set auth state
  await page.context().addCookies([
    { name: 'auth_token', value: token, domain: 'localhost', path: '/' }
  ])
})

// API mocking cho slow/flaky third-party services
test('checkout with payment gateway', async ({ page }) => {
  await page.route('**/api/payment/charge', async route => {
    await route.fulfill({
      status: 200,
      contentType: 'application/json',
      body: JSON.stringify({ success: true, transactionId: 'mock-txn-123' })
    })
  })
  // Test checkout flow mà không cần real payment gateway
})
```

### E2E anti-patterns

```
❌ Hard waits: await page.waitForTimeout(2000)
   → Flaky và chậm. Test pass khi app fast, fail khi slow
   ✅ Condition waits: await element.waitFor({ state: 'visible' })
                      await expect(element).toBeVisible()

❌ Too many E2E tests
   → Slow CI, false negatives, maintenance burden
   ✅ E2E chỉ cho critical user paths: login, checkout, core features
   ✅ Use integration tests cho non-critical paths

❌ Test implementation details
   → Brittle: đổi class name/ID → test fail dù behavior không đổi
   ✅ Test user-visible behavior: text, roles, labels

❌ Không có retry logic cho network requests
   → Test fail do network blip, không phải real bug
   ✅ Playwright retry config + network idle waits

❌ Run E2E trên mọi PR
   → CI quá chậm (30+ phút)
   ✅ E2E chạy: merge to main, nightly, pre-production deploy
```

---

## 5. Contract Testing

### Khi nào cần contract tests

```
Contract testing giải quyết vấn đề:
  Service A (consumer) gọi Service B (provider)
  Service B thay đổi response format
  Service A fail lúc runtime — không ai biết trước

Traditional approach: Integration tests với real B
  Chậm, flaky, B phải always-on trong CI

Contract testing: 
  A define "contract" (kỳ vọng về B's API)
  B verify contract trong CI của B
  Không cần A và B chạy cùng lúc
```

### Pact — consumer-driven contracts

```ts
// Consumer side (Service A) — define expectations
import { PactV3, MatchersV3 } from '@pact-foundation/pact'

const provider = new PactV3({
  consumer: 'OrderService',
  provider: 'ProductService',
  dir: './pacts',
})

describe('ProductService contract', () => {
  it('should return product details', async () => {
    await provider
      .given('product p1 exists')
      .uponReceiving('a request for product p1')
      .withRequest({ method: 'GET', path: '/products/p1' })
      .willRespondWith({
        status: 200,
        body: {
          id: MatchersV3.string('p1'),
          name: MatchersV3.string('Product Name'),
          price: MatchersV3.number(99000),
          stock: MatchersV3.integer(10),
        }
      })
      .executeTest(async (mockProvider) => {
        const client = new ProductClient(mockProvider.url)
        const product = await client.getProduct('p1')
        expect(product.id).toBe('p1')
      })
  })
})

// Provider side (Service B) — verify contract
import { Verifier } from '@pact-foundation/pact'

describe('ProductService provider verification', () => {
  it('should satisfy OrderService contract', async () => {
    await new Verifier({
      provider: 'ProductService',
      providerBaseUrl: 'http://localhost:3001',
      pactBrokerUrl: 'https://your-pact-broker.io',
      publishVerificationResult: true,
    }).verifyProvider()
  })
})
```

### Provider states — test fixtures

```ts
// Provider phải setup state trước khi verify
// "product p1 exists" → seed DB với product p1

app.post('/pact/provider-states', async (req, res) => {
  const { state } = req.body
  switch (state) {
    case 'product p1 exists':
      await db.execute(`
        INSERT INTO products (id, name, price, stock) 
        VALUES ('p1', 'Test Product', 99000, 10)
        ON CONFLICT DO NOTHING
      `)
      break
    case 'product p1 is out of stock':
      await db.execute(`UPDATE products SET stock = 0 WHERE id = 'p1'`)
      break
    case 'no products exist':
      await db.execute(`TRUNCATE products`)
      break
  }
  res.json({ description: `State '${state}' set up` })
})
```


### GraphQL testing patterns

```typescript
// Test GraphQL resolvers directly (unit test style)
import { createTestServer } from './test-utils'

describe('Order queries', () => {
  it('fetches order with line items', async () => {
    const server = createTestServer()
    const { body } = await server.executeOperation({
      query: `
        query GetOrder($id: ID!) {
          order(id: $id) {
            id
            status
            total
            items { productId quantity price }
          }
        }
      `,
      variables: { id: 'order-123' },
    })
    expect(body.singleResult.errors).toBeUndefined()
    expect(body.singleResult.data?.order.status).toBe('pending')
  })

  it('returns error for non-existent order', async () => {
    const server = createTestServer()
    const { body } = await server.executeOperation({
      query: `query { order(id: "nonexistent") { id } }`,
    })
    expect(body.singleResult.errors?.[0].extensions?.code).toBe('NOT_FOUND')
  })
})

// DataLoader N+1 detection
it('does not produce N+1 queries', async () => {
  const queryCount = trackDbQueryCount()
  await server.executeOperation({
    query: `query { orders { id user { name } } }`,  // 10 orders
  })
  // With DataLoader: 1 query for orders + 1 batch query for users
  // Without DataLoader: 1 + 10 = 11 queries
  expect(queryCount()).toBe(2)
})
```


---

## 6. Performance & Load Testing

### k6 — load testing as code

```js
// k6/load-test.js
import http from 'k6/http'
import { check, sleep } from 'k6'
import { Rate, Trend } from 'k6/metrics'

const errorRate = new Rate('errors')
const orderLatency = new Trend('order_latency')

export const options = {
  stages: [
    { duration: '2m', target: 50 },    // Ramp up: 0 → 50 VUs
    { duration: '5m', target: 50 },    // Steady state: 50 VUs
    { duration: '2m', target: 200 },   // Spike: 50 → 200 VUs
    { duration: '5m', target: 200 },   // Spike steady
    { duration: '2m', target: 0 },     // Ramp down
  ],
  thresholds: {
    http_req_duration: ['p95<500', 'p99<1000'],  // 95% < 500ms
    errors: ['rate<0.01'],                        // Error rate < 1%
    order_latency: ['p99<2000'],                  // Order creation p99 < 2s
  },
}

const BASE_URL = __ENV.BASE_URL || 'http://localhost:3000'

export function setup() {
  // Tạo test data trước khi load test
  const res = http.post(`${BASE_URL}/api/test/seed`, JSON.stringify({ products: 100 }), {
    headers: { 'Content-Type': 'application/json' },
  })
  return { token: res.json('token') }  // Pass data to VUs
}

export default function (data) {
  const headers = {
    'Content-Type': 'application/json',
    'Authorization': `Bearer ${data.token}`,
  }

  // Simulate user journey: browse → add to cart → checkout
  const browse = http.get(`${BASE_URL}/api/products?limit=20`, { headers })
  check(browse, { 'products listed': r => r.status === 200 })
  errorRate.add(browse.status !== 200)

  sleep(1)  // Think time: user reads product list

  const products = browse.json('data')
  if (!products?.length) return

  const productId = products[Math.floor(Math.random() * products.length)].id

  const startOrder = Date.now()
  const order = http.post(
    `${BASE_URL}/api/orders`,
    JSON.stringify({ items: [{ productId, quantity: 1 }] }),
    { headers }
  )
  orderLatency.add(Date.now() - startOrder)

  check(order, {
    'order created': r => r.status === 201,
    'has order id': r => r.json('id') !== undefined,
  })
  errorRate.add(order.status !== 201)

  sleep(2)
}
```

### Load testing strategies

```
Smoke test: 1-2 VUs, 1 phút
  Mục đích: Verify test script works, không tìm performance issues

Load test: Target load × 1.0, 30+ phút
  Mục đích: Verify system meets performance targets dưới normal load

Stress test: Tăng dần đến khi hệ thống degrade
  Mục đích: Tìm breaking point, bottlenecks

Spike test: Tăng đột ngột 10× trong 30s
  Mục đích: Test auto-scaling, circuit breakers

Soak test: Normal load trong 8-24 giờ
  Mục đích: Memory leaks, connection pool exhaustion, gradual degradation
  → Hay bị bỏ qua nhưng catches memory leaks tốt nhất

Breakpoint test: Tăng liên tục cho đến khi fail
  Mục đích: Capacity planning
```

### Performance test pitfalls

```
Pitfall 1: Test môi trường không giống production
  → Dev machine có 32GB RAM, prod có 4GB → kết quả vô nghĩa
  → Fix: Test trong staging environment giống production nhất có thể

Pitfall 2: Không warm up trước khi đo
  → JVM cold start, CPU cache cold, connection pool empty → kết quả sai
  → Fix: 2-3 phút warm up trước khi collect metrics

Pitfall 3: Coordinate omission (Coordinated Omission problem)
  → Client không gửi request khi server slow → undercount latency
  → k6 mặc định có vấn đề này với sleep()
  → Fix: dùng k6 executors với arrivalRate (constant-arrival-rate)

Pitfall 4: Test chỉ happy path
  → Không test authentication, pagination, error paths
  → Fix: Realistic user journey mix

Pitfall 5: Không monitor server side
  → Biết client thấy latency cao nhưng không biết tại sao
  → Fix: Collect DB queries, CPU, memory, connection pool metrics trong khi test
```

---

## 7. Visual Regression Testing

### Chromatic + Storybook

```ts
// Mỗi story = 1 visual test
// Chromatic chụp screenshot, so sánh với baseline

// stories/Button.stories.ts
export default {
  component: Button,
  chromatic: { delay: 300 },  // Wait for animations
}

export const Primary = { args: { variant: 'primary', children: 'Click me' } }
export const Disabled = { args: { variant: 'primary', disabled: true } }
export const Loading = { args: { variant: 'primary', loading: true } }
export const LongText = { args: { children: 'This is a very long button label' } }

// Viewport testing
export const MobileView = {
  parameters: {
    chromatic: { viewports: [320, 414, 768] }
  }
}
```

### Playwright visual comparison

```ts
// Snapshot testing với Playwright
test('product page matches baseline', async ({ page }) => {
  await page.goto('/products/sample-product')
  await page.waitForLoadState('networkidle')

  // Full page screenshot
  await expect(page).toHaveScreenshot('product-page.png', {
    maxDiffPixelRatio: 0.01,  // Allow 1% pixel diff
    animations: 'disabled',
  })

  // Element screenshot
  const hero = page.getByTestId('product-hero')
  await expect(hero).toHaveScreenshot('product-hero.png')
})

// Updating baseline: npx playwright test --update-snapshots
```

### Khi nào dùng visual regression

```
Dùng khi:
  - Design system components (pixels matter)
  - Marketing landing pages
  - PDF/report generation
  - Charts và data visualizations

Không cần:
  - Internal admin panels
  - Business logic testing
  - API testing

Gotchas:
  - Dynamic content (dates, user names) → mask trước khi compare
  - Animations → disable hoặc dùng delay
  - Font rendering khác OS → pin environment (Docker)
  - Anti-aliasing khác → threshold > 0
```

---

## 8. Testing trong CI/CD

### Pipeline design cho testing

```yaml
# Parallel strategy: fail fast, maximize speed
jobs:
  # Gate 1: Static analysis (< 2 min) — chạy song song
  typecheck:
    runs-on: ubuntu-latest
    steps:
      - run: npx tsc --noEmit
  
  lint:
    runs-on: ubuntu-latest
    steps:
      - run: npx eslint . --max-warnings 0

  # Gate 2: Unit tests (< 3 min) — chờ Gate 1
  unit-tests:
    needs: [typecheck, lint]
    runs-on: ubuntu-latest
    steps:
      - run: npx vitest run --coverage
      - uses: codecov/codecov-action@v3

  # Gate 3: Integration tests (< 10 min) — chạy song song với unit
  integration-tests:
    needs: [typecheck, lint]
    services:
      postgres: { image: 'postgres:16-alpine', env: { POSTGRES_PASSWORD: test } }
      redis: { image: 'redis:7-alpine' }
    steps:
      - run: npx vitest run --project integration

  # Gate 4: E2E — chỉ trên main branch (chậm)
  e2e:
    needs: [unit-tests, integration-tests]
    if: github.ref == 'refs/heads/main'
    steps:
      - run: npx playwright test
      - uses: actions/upload-artifact@v3
        if: failure()
        with: { path: playwright-report/ }
```

### Test parallelization

```ts
// Vitest parallel config
// vitest.config.ts
export default defineConfig({
  test: {
    pool: 'threads',          // Worker threads (default)
    // pool: 'forks',         // Child processes (slower, more isolation)
    poolOptions: {
      threads: {
        maxThreads: 4,        // Limit để tránh resource contention
        minThreads: 2,
      }
    },
    // Separate pools for different test types
    projects: [
      {
        extends: true,
        test: {
          name: 'unit',
          include: ['src/**/*.test.ts'],
          exclude: ['**/*.integration.test.ts'],
        }
      },
      {
        extends: true,
        test: {
          name: 'integration',
          include: ['src/**/*.integration.test.ts'],
          maxWorkers: 2,       // Ít hơn vì cần real DB
          singleThread: true,  // Tuần tự để tránh DB conflicts
        }
      }
    ]
  }
})
```

### Test reporting và tracking

```
Metrics nên track theo thời gian:
  - Test execution time (total + per-suite)
  - Flaky test rate: tests fail intermittently
  - Coverage trend (tăng hay giảm?)
  - Test failure rate per PR

Flaky test detection:
  GitHub Actions: re-run failed jobs automatically
  Buildkite: flaky test detection built-in
  Custom: track test results in DB, flag tests failing > 5% without code changes

Xử lý flaky tests:
  1. Quarantine: move to separate suite, không block CI
  2. Fix root cause (thường: timing, external dependency, shared state)
  3. Delete nếu không fix được và value thấp
  KHÔNG: ignore indefinitely
```

---

## 9. Test Data Management

### Test data factories

```ts
// factories/user.factory.ts
import { faker } from '@faker-js/faker'

type UserOverrides = Partial<User>

export const buildUser = (overrides: UserOverrides = {}): User => ({
  id: faker.string.uuid(),
  email: faker.internet.email(),
  name: faker.person.fullName(),
  role: 'user',
  createdAt: faker.date.recent(),
  ...overrides,
})

export const buildAdmin = (overrides: UserOverrides = {}): User =>
  buildUser({ role: 'admin', ...overrides })

// Persist factory
export const createUser = async (overrides: UserOverrides = {}): Promise<User> => {
  const data = buildUser(overrides)
  return db.users.create(data)
}

// Usage:
const user = buildUser()                              // In-memory, no DB
const admin = await createUser({ role: 'admin' })    // Persisted to DB
const users = Array.from({ length: 10 }, buildUser)  // Bulk

// Complex nested objects
export const buildOrder = (overrides: Partial<Order> = {}): Order => ({
  id: faker.string.uuid(),
  userId: faker.string.uuid(),
  items: [buildOrderItem()],
  status: 'pending',
  total: faker.number.int({ min: 100_000, max: 10_000_000 }),
  createdAt: new Date(),
  ...overrides,
})
```

### Seed data vs factories

```
Seeds (static, committed):
  Dùng cho: Reference data (countries, currencies, categories)
  Không dùng cho: User-generated data, test-specific data
  File: db/seeds/reference-data.sql

Factories (dynamic, generated):
  Dùng cho: Test-specific entities, user data, orders
  Lợi ích: Random data catches edge cases không nghĩ tới
  Lợi ích: Không duplicate, mỗi test có isolated data

Fixtures (static JSON/TS files):
  Dùng cho: Complex domain objects cần exact values
  Ví dụ: Fixture cho payment webhook payload từ Stripe
  Không dùng cho: Simple CRUD test data (factory tốt hơn)

Snapshot fixtures (auto-generated):
  Jest/Vitest snapshots: serialized output
  Tốt cho: Large complex objects, CLI output
  Xấu khi: Over-snapshot → brittle tests
```

### Sensitive data trong tests

```
KHÔNG dùng production data trong tests:
  - PII violation (GDPR, HIPAA)
  - Security risk nếu test DB bị compromise
  - Inconsistent test results (production data thay đổi)

Thay thế:
  - Synthetic data: faker.js, mimesis (Python)
  - Anonymized data: production → anonymize → import vào staging
    Anonymization: hash emails, randomize names, mask cards
  - Subset: chỉ lấy schema + anonymized sample rows

Production data trong tests (acceptable exceptions):
  - Load testing với anonymized snapshot
  - Bug reproduction với anonymized example
  - Performance comparison với realistic data volume
```

---

## 10. Mobile Testing

### Unit và integration testing

```
React Native:
  Unit: Jest + @testing-library/react-native
  Component: render() + userEvent (không Enzyme — deprecated)
  
  import { render, screen, userEvent } from '@testing-library/react-native'
  
  test('Counter increments on press', async () => {
    render(<Counter initialCount={0} />)
    const user = userEvent.setup()
    
    await user.press(screen.getByRole('button', { name: 'Increment' }))
    
    expect(screen.getByText('Count: 1')).toBeTruthy()
  })

Flutter:
  Unit: flutter test
  Widget: WidgetTester
  Integration: integration_test package
  
  testWidgets('Counter increments', (tester) async {
    await tester.pumpWidget(const MyApp())
    expect(find.text('0'), findsOneWidget)
    await tester.tap(find.byIcon(Icons.add))
    await tester.pump()
    expect(find.text('1'), findsOneWidget)
  })
```

### E2E mobile testing

```
Detox (React Native — Black-box, real device/simulator):
  Pros: Real user interaction, true E2E
  Cons: Slow (5-15 min per test), complex setup
  
  describe('Login flow', () => {
    it('should login successfully', async () => {
      await element(by.id('email-input')).typeText('user@test.com')
      await element(by.id('password-input')).typeText('password')
      await element(by.id('login-button')).tap()
      await expect(element(by.id('home-screen'))).toBeVisible()
    })
  })

Maestro (2024 recommended — YAML-based, simpler):
  - Không cần code: YAML flows
  - Nhanh setup hơn Detox
  - Cross-platform: iOS + Android + Web
  
  # login.yaml
  appId: com.example.app
  ---
  - launchApp
  - tapOn: "Email"
  - inputText: "user@test.com"
  - tapOn: "Password"
  - inputText: "password"
  - tapOn: "Log In"
  - assertVisible: "Welcome back"

Device farms:
  BrowserStack App Automate: Real devices, nhiều OS versions
  AWS Device Farm: AWS-native
  Firebase Test Lab: Free tier, Android focus
  Phù hợp: Release testing trên multiple real devices
```

---

## 11. Security Testing

### Static Application Security Testing (SAST)

```yaml
# Semgrep — fast, accurate, open source
# .github/workflows/security.yml
- name: Semgrep
  uses: semgrep/semgrep-action@v1
  with:
    config: >-
      p/security-audit
      p/secrets
      p/nodejs
      p/typescript
      p/jwt
  env:
    SEMGREP_APP_TOKEN: ${{ secrets.SEMGREP_APP_TOKEN }}

# Catches:
# - Hardcoded secrets
# - SQL injection patterns
# - XSS vulnerabilities
# - Insecure crypto (MD5, SHA1)
# - Dangerous functions (eval, exec)
# - Missing input validation
```

### Dependency vulnerability scanning

```bash
# npm audit (built-in)
npm audit --audit-level=high   # Fail nếu có HIGH/CRITICAL vulns

# Snyk (more detailed, CI integration)
npx snyk test --severity-threshold=high

# OWASP Dependency Check
# Checks against NVD (National Vulnerability Database)

# Trivy (container images)
trivy image myapp:latest --severity HIGH,CRITICAL --exit-code 1
# Checks: OS packages, language deps, misconfigurations

# GitHub Dependabot: Auto PRs khi dependency có vulnerability
# .github/dependabot.yml
version: 2
updates:
  - package-ecosystem: npm
    directory: /
    schedule: { interval: weekly }
    open-pull-requests-limit: 10
```

### Dynamic security testing

```
DAST (Dynamic Application Security Testing):
  OWASP ZAP: Free, mature, active scan
  Burp Suite: Industry standard (expensive)
  Nuclei: Template-based, fast
  
  Integrate trong CI (non-blocking scan first):
  zap-baseline.py -t http://staging.example.com -r report.html
  
  Kiểm tra:
  - Injection vulnerabilities
  - Broken authentication
  - Security misconfiguration
  - Exposed sensitive data
  - Outdated components với known vulns

Secrets scanning:
  TruffleHog: Scan git history cho secrets
  Gitleaks: Pre-commit hook
  GitHub Advanced Security: Built-in secret scanning
  
  Pre-commit hook:
  # .pre-commit-config.yaml
  repos:
    - repo: https://github.com/gitleaks/gitleaks
      hooks:
        - id: gitleaks
```

---

## 12. Frontend Component Testing

### React Testing Library — best practices

```tsx
// testing-library/react: Simulate user behavior, không implementation
import { render, screen, within } from '@testing-library/react'
import userEvent from '@testing-library/user-event'

describe('ProductCard', () => {
  it('should add product to cart when button clicked', async () => {
    const user = userEvent.setup()
    const onAddToCart = jest.fn()

    render(
      <ProductCard
        product={{ id: 'p1', name: 'Laptop', price: 15_000_000 }}
        onAddToCart={onAddToCart}
      />
    )

    // Query by accessible name, not CSS class
    const addButton = screen.getByRole('button', { name: /add to cart/i })
    await user.click(addButton)

    expect(onAddToCart).toHaveBeenCalledWith({ productId: 'p1', quantity: 1 })
  })

  it('should show sold out when stock is 0', () => {
    render(<ProductCard product={{ id: 'p1', name: 'Laptop', stock: 0 }} />)

    expect(screen.getByText(/sold out/i)).toBeInTheDocument()
    expect(screen.queryByRole('button', { name: /add to cart/i })).not.toBeInTheDocument()
  })

  it('should display formatted price', () => {
    render(<ProductCard product={{ id: 'p1', name: 'Laptop', price: 15_000_000 }} />)

    // Không test implementation (formatPrice function)
    // Test output mà user thấy
    expect(screen.getByText('15.000.000 ₫')).toBeInTheDocument()
  })
})

// Testing async behavior
it('should show loading state while fetching', async () => {
  server.use(
    rest.get('/api/products', async (req, res, ctx) => {
      await delay(100)
      return res(ctx.json([]))
    })
  )

  render(<ProductList />)

  expect(screen.getByRole('status', { name: /loading/i })).toBeInTheDocument()
  await waitForElementToBeRemoved(() => screen.queryByRole('status'))
  expect(screen.getByText(/no products found/i)).toBeInTheDocument()
})
```

### MSW (Mock Service Worker) — API mocking cho component tests

```ts
// mocks/handlers.ts
import { http, HttpResponse } from 'msw'

export const handlers = [
  http.get('/api/products', () => {
    return HttpResponse.json([
      { id: 'p1', name: 'Laptop', price: 15_000_000 },
    ])
  }),
  http.post('/api/orders', async ({ request }) => {
    const body = await request.json()
    return HttpResponse.json({ id: 'order-1', ...body }, { status: 201 })
  }),
]

// Intercepts real fetch/XHR in tests AND browser
// No need to mock individual fetch calls
// Same handlers work in Jest (node) và browser (development)

// Override per test:
test('handles API error', async () => {
  server.use(
    http.get('/api/products', () => {
      return new HttpResponse(null, { status: 500 })
    })
  )
  // ...
})
```

---

## 13. Testing Anti-patterns

```
❌ Test implementation details, không behavior
  expect(component.state.isLoading).toBe(true)  // BAD
  expect(screen.getByRole('status')).toBeInTheDocument()  // GOOD

❌ Over-mocking (mock everything including code under test)
  Khi mock quá nhiều → test chỉ verify "function X calls function Y"
  → Không có real value, không catch real bugs

❌ Snapshot testing cho everything
  Large snapshots → fail vì thay đổi nhỏ không quan trọng
  Developers just update snapshot mà không review
  ✅ Snapshot chỉ cho complex serialized output, không cho JSX

❌ Tests phụ thuộc vào nhau (test ordering)
  test 2 cần test 1 chạy trước mới pass → nguy hiểm
  ✅ Mỗi test setup và teardown độc lập

❌ Magic numbers trong tests
  expect(result).toBe(42)  // 42 là gì?
  ✅ Named constants hoặc explicit calculation:
  const DISCOUNT_RATE = 0.1
  expect(result.discount).toBe(subtotal * DISCOUNT_RATE)

❌ Không test error cases
  Chỉ test happy path → production bugs trong edge cases
  ✅ Test: null/undefined input, empty arrays, max values, network errors

❌ Tests quá fine-grained (một test cho mỗi function)
  → Brittle: refactor → tất cả tests fail dù behavior không đổi
  ✅ Test behavior/contracts, không implementation

❌ Assert quá nhiều trong 1 test
  expect(result.id).toBe('123')
  expect(result.name).toBe('test')
  expect(result.email).toBe('test@test.com')
  expect(result.role).toBe('user')
  expect(result.createdAt).toBeDefined()
  // Nếu id sai → tất cả fail, không rõ root cause
  ✅ 1 test = 1 logical assertion (có thể nhiều expect nếu cùng concept)
```

---

## 14. Testing Checklist

> 🔴 MUST = block ship | 🟠 SHOULD = fix trước prod | 🟡 NICE = tech debt

### Unit Tests

🔴 MUST:
- [ ] Business logic core có unit tests (discount rules, validation, calculations)
- [ ] Tests không hardcode secrets hoặc production URLs
- [ ] Tests chạy được isolated (không phụ thuộc lẫn nhau, không cần internet)

🟠 SHOULD:
- [ ] Coverage > 80% cho business logic
- [ ] Error cases được test (not just happy path)
- [ ] Test doubles dùng đúng loại (mock/stub/fake/spy)
- [ ] `beforeEach` cleanup mocks: `jest.clearAllMocks()`

🟡 NICE:
- [ ] Mutation testing score > 70% (Stryker/mutmut)
- [ ] Property-based testing cho algorithms (fast-check)

### Integration Tests

🔴 MUST:
- [ ] API endpoints có integration tests với real DB
- [ ] Auth middleware tested (valid token, invalid token, expired)

🟠 SHOULD:
- [ ] Test containers thay vì mocked DB cho integration tests
- [ ] DB isolation per test (transaction rollback hoặc truncate)
- [ ] Idempotency tested cho POST endpoints với side effects
- [ ] Error responses tested (4xx, 5xx) không chỉ 2xx

🟡 NICE:
- [ ] Contract tests (Pact) cho service boundaries
- [ ] Consumer-driven contract tests published to broker

### E2E Tests

🔴 MUST:
- [ ] Critical user flows có E2E: login, checkout, core feature
- [ ] E2E không share state giữa tests

🟠 SHOULD:
- [ ] Page Object Model, không brittle CSS selectors
- [ ] Third-party APIs mocked (payment gateway, email, SMS)
- [ ] Mobile viewport tested cho responsive
- [ ] Trace/screenshot/video khi E2E fail trong CI

🟡 NICE:
- [ ] Visual regression tests cho design system components
- [ ] A11y automated check trong E2E (axe-playwright)

### Performance Tests

🟠 SHOULD:
- [ ] Load test trước major releases (k6/Locust)
- [ ] Thresholds defined: p95 < 500ms, error rate < 1%
- [ ] Test chạy trong staging, không production

🟡 NICE:
- [ ] Soak test (8h+) detect memory leaks
- [ ] Spike test detect auto-scaling behavior
- [ ] Performance regression: fail nếu p99 tăng > 20% so với baseline

### Security Tests

🔴 MUST:
- [ ] Dependency audit trong CI (fail nếu HIGH/CRITICAL vulns)
- [ ] Secrets scanning trong CI (gitleaks/TruffleHog)
- [ ] Container image scanning cho Docker images

🟠 SHOULD:
- [ ] SAST (Semgrep/CodeQL) trong CI
- [ ] DAST scan trong staging (OWASP ZAP)
- [ ] Auth edge cases tested: expired token, invalid token, missing token

🟡 NICE:
- [ ] Penetration testing trước major launches
- [ ] Bug bounty program

---
