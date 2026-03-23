# Testing Automation & Process — Reference

Phần 2/2 của testing skill. Cover: TDD, BDD/Gherkin, mutation testing, property-based,
accessibility automation, cross-browser, API fuzz, chaos engineering, test strategy,
environment management, flaky tests, metrics, shift-left.
Phần 1 (fundamentals): `references/testing-fundamentals.md`

---

## 15. TDD — Test-Driven Development

### Red-Green-Refactor cycle

```
Red:    Viết test TRƯỚC — test fail vì chưa có code
Green:  Viết code tối thiểu để test pass — không gì hơn
Refactor: Clean up code — test vẫn phải pass

Lặp lại cho mỗi behavior nhỏ.
```

Nghe đơn giản, nhưng discipline quan trọng là: **viết test trước, code sau**.

### Hai trường phái TDD

```
Detroit school (Classic TDD — Kent Beck):
  → Test state: assert kết quả cuối (return value, DB state)
  → Mock ít, test real collaborators
  → Bottom-up: bắt đầu từ domain core, build ra ngoài
  → Phù hợp: business logic đơn giản, standalone functions

London school (Mockist TDD — Steve Freeman):
  → Test behavior: assert interactions giữa objects
  → Mock nhiều collaborators, chỉ test unit nhỏ
  → Outside-in: bắt đầu từ API boundary, drive design vào trong
  → Phù hợp: distributed systems, complex object graphs
```

### TDD thực tế — ví dụ step-by-step

```ts
// Feature: Áp dụng discount cho order > 1,000,000 VND

// Step 1 — Red: Viết test TRƯỚC, chạy → fail
test('applies 10% discount when order exceeds 1,000,000', () => {
  const result = calculateDiscount(1_200_000)
  expect(result.discountAmount).toBe(120_000)
  expect(result.finalPrice).toBe(1_080_000)
})
// Chạy: FAIL — calculateDiscount is not defined

// Step 2 — Green: Code tối thiểu để pass
function calculateDiscount(price: number) {
  if (price > 1_000_000) {
    return { discountAmount: price * 0.1, finalPrice: price * 0.9 }
  }
  return { discountAmount: 0, finalPrice: price }
}
// Chạy: PASS

// Step 3 — Red: Thêm test cho edge case
test('no discount when order equals threshold exactly', () => {
  const result = calculateDiscount(1_000_000)
  expect(result.discountAmount).toBe(0)
})
// Chạy: FAIL — 1,000,000 không > 1,000,000 nhưng code dùng >

// Step 4 — Green: Fix condition
function calculateDiscount(price: number) {
  const DISCOUNT_THRESHOLD = 1_000_000
  const DISCOUNT_RATE = 0.1
  if (price > DISCOUNT_THRESHOLD) {
    const discountAmount = price * DISCOUNT_RATE
    return { discountAmount, finalPrice: price - discountAmount }
  }
  return { discountAmount: 0, finalPrice: price }
}

// Step 5 — Refactor: Extract constants, rename cho rõ
// Tests vẫn pass → safe to refactor
```

### Khi nào TDD có giá trị thực sự

```
✅ Tốt cho:
  - Business rules phức tạp (pricing, discount, tax, workflow)
  - Algorithm (sorting, searching, parsing)
  - Bug fix: Viết test reproduce bug → fix → test pass = verified
  - API contract: design API từ consumer perspective
  - Pure functions với clear input/output

⚠ Khó áp dụng:
  - UI components (visual feedback loop tốt hơn TDD)
  - Exploratory code (chưa biết design sẽ như thế nào)
  - Infrastructure code (DB migration, config)
  - Performance optimization (cần measure trước)

❌ Anti-pattern:
  - Viết test SAU code rồi gọi là TDD
  - Test pass ngay lần đầu (không có Red phase)
  - Test quá chi tiết → brittle khi refactor
```

---

## 16. BDD — Behavior-Driven Development

### Gherkin syntax — ngôn ngữ business

```gherkin
# features/checkout.feature
Feature: Checkout process
  Người dùng có thể hoàn thành mua hàng và nhận xác nhận

  Background:
    Given user đã login với email "user@example.com"
    And giỏ hàng có sản phẩm "Laptop XYZ" với số lượng 1

  Scenario: Checkout thành công với thẻ hợp lệ
    When user điền thông tin thẻ hợp lệ
    And user nhấn "Đặt hàng"
    Then order được tạo với status "pending"
    And user nhận email xác nhận
    And giỏ hàng trở về trống

  Scenario: Checkout thất bại khi thẻ bị từ chối
    When user điền thẻ hết hạn
    And user nhấn "Đặt hàng"
    Then hiển thị lỗi "Thẻ không hợp lệ"
    And order không được tạo
    And giỏ hàng vẫn giữ nguyên

  Scenario Outline: Áp dụng discount theo giá trị đơn hàng
    Given order có giá trị <subtotal>
    When tính tổng tiền
    Then discount là <discount>

    Examples:
      | subtotal    | discount |
      | 500,000     | 0        |
      | 1,000,000   | 0        |
      | 1,200,000   | 120,000  |
      | 5,000,000   | 500,000  |
```

### Step definitions — kết nối Gherkin với code

```ts
// TypeScript + Cucumber.js
import { Given, When, Then, Before, After } from '@cucumber/cucumber'
import { expect } from '@playwright/test'

let page: Page
let context: BrowserContext
let orderId: string

Before(async () => {
  context = await browser.newContext()
  page = await context.newPage()
})

After(async () => {
  await context.close()
})

Given('user đã login với email {string}', async (email: string) => {
  const token = await createTestUserAndGetToken(email)
  await context.addCookies([{ name: 'auth', value: token, domain: 'localhost', path: '/' }])
})

Given('giỏ hàng có sản phẩm {string} với số lượng {int}',
  async (productName: string, qty: number) => {
    await api.post('/cart/items', { productName, quantity: qty })
  }
)

When('user điền thông tin thẻ hợp lệ', async () => {
  await page.goto('/checkout')
  await page.getByLabel('Card number').fill('4111111111111111')
  await page.getByLabel('Expiry').fill('12/28')
  await page.getByLabel('CVV').fill('123')
})

When('user nhấn {string}', async (buttonText: string) => {
  await page.getByRole('button', { name: buttonText }).click()
})

Then('order được tạo với status {string}', async (status: string) => {
  await expect(page.getByTestId('order-confirmation')).toBeVisible()
  orderId = await page.getByTestId('order-id').textContent() ?? ''
  const order = await api.get(`/orders/${orderId}`)
  expect(order.status).toBe(status)
})

Then('user nhận email xác nhận', async () => {
  // Kiểm tra trong test email server (Mailhog/Mailpit)
  const emails = await mailpit.getEmails({ to: 'user@example.com' })
  expect(emails).toHaveLength(1)
  expect(emails[0].subject).toContain('Xác nhận đơn hàng')
})
```

### BDD — khi nào dùng và khi nào không

```
✅ Dùng khi:
  - BA và QA không viết code — Gherkin là ngôn ngữ chung
  - Feature phức tạp cần document rõ acceptance criteria
  - Regulatory compliance cần traceability (feature ↔ test)
  - Team muốn "living documentation" luôn up-to-date

❌ Không dùng khi:
  - Team nhỏ, toàn developers — over-engineering
  - Không có BA/QA tham gia viết Gherkin → developer viết Gherkin
    + step definitions = extra work không có business value
  - Gherkin chỉ wrap E2E tests → không có actual collaboration

Dấu hiệu BDD đang bị dùng sai:
  - Dev viết cả Gherkin lẫn step definitions một mình
  - Scenarios quá technical (chứa CSS selectors, API endpoints)
  - Scenarios quá dài (> 10 steps)
  - Không ai ngoài dev đọc feature files

3 Amigos meeting (trước khi code):
  Business Analyst: "What is the feature?"
  Developer:        "How should it work technically?"
  QA:               "What could go wrong? Edge cases?"
  → Viết Gherkin scenarios CÙNG NHAU → shared understanding
```

---

## 17. Mutation Testing

### Tại sao cần mutation testing

```
Code coverage 90% nghĩa là 90% code được execute trong tests.
Nhưng tests có thực sự verify behavior không?

Ví dụ:
  function calculateDiscount(price) {
    if (price > 1000000) {           ← Mutation: đổi > thành >=
      return price * 0.1
    }
    return 0
  }

  test('returns 0 for price 1000000', () => {
    expect(calculateDiscount(1000000)).toBe(0)
    // Test pass dù > bị đổi thành >= → test không catch bug!
  })

Mutation testing tự động tạo "mutants" (code bị thay đổi nhỏ)
và kiểm tra xem tests có fail không.
Mutant bị "killed" = tests catch the change = good
Mutant "survived" = tests miss the change = test gap
```

### Stryker — JavaScript/TypeScript

```ts
// stryker.config.mjs
export default {
  packageManager: 'npm',
  reporters: ['html', 'clear-text', 'progress'],
  testRunner: 'vitest',
  coverageAnalysis: 'perTest',
  mutate: [
    'src/**/*.ts',
    '!src/**/*.test.ts',
    '!src/migrations/**',
    '!src/config/**',
  ],
  thresholds: {
    high: 80,    // Score > 80% → green
    low: 60,     // Score < 60% → fail CI
    break: 50,   // Score < 50% → break build
  },
  // Chạy mutations trong parallel
  concurrency: 4,
}
// npx stryker run
```

### Mutation operators thường gặp

```
Arithmetic:    + → -,  * → /,  % → *
Comparison:    > → >=,  === → !==,  < → >
Logical:       && → ||,  ! removed
Statement:     return value đổi,  if condition đổi
String:        "" → "Stryker was here" (empty string mutations)
Array:         [] → [0] (empty array mutations)

Kết quả:
  Killed:   Test fail khi mutant applied → good coverage
  Survived: Test pass dù code bị mutate → test gap
  Timeout:  Infinite loop từ mutation → counted as killed
  No coverage: Code không được execute → không thể mutate
```

### Mutation testing targets và strategy

```
Không cần 100% mutation score — đắt về thời gian:
  Business logic core:  > 80% (pricing, validation, workflow)
  Utility functions:    > 70%
  API handlers:         > 60% (integration tests cover nhiều hơn)
  Infrastructure:       Không cần (config, migrations)

Workflow trong CI:
  1. Unit tests:       Run mỗi PR (fast)
  2. Mutation tests:   Run nightly (slow — 15-30 phút)
  3. Review survived mutants: Prioritize bằng coverage + business impact
  4. Thêm tests cho survived mutants có business value cao

Tối ưu thời gian chạy:
  - Chỉ mutate files changed trong PR (incremental mutation)
  - Stryker --since HEAD~1
  - Parallel execution trên CI
```

---

## 18. Property-Based Testing

### Tại sao vượt qua example-based testing

```
Example-based:  Bạn nghĩ ra inputs → test với inputs đó
  → Chỉ test cases bạn đã nghĩ tới

Property-based: Framework tự generate hàng trăm/nghìn inputs
  → Tìm bugs bạn KHÔNG nghĩ tới

Ví dụ tìm được bởi property-based testing mà developer bỏ qua:
  - Chuỗi rỗng "" → crash
  - Unicode characters "🎉" → wrong length calculation
  - Số âm → negative discount
  - Integer overflow với số lớn
  - Null ẩn trong array
  - Palindrome edge cases
```

### fast-check (TypeScript/JavaScript)

```ts
import fc from 'fast-check'

// Property: sắp xếp bất kỳ array nào → kết quả phải sorted
test('sort: output is always sorted', () => {
  fc.assert(
    fc.property(fc.array(fc.integer()), (arr) => {
      const sorted = mySort(arr)
      for (let i = 0; i < sorted.length - 1; i++) {
        expect(sorted[i]).toBeLessThanOrEqual(sorted[i + 1])
      }
    }),
    { numRuns: 1000 }  // 1000 random inputs
  )
})

// Property: sort không thay đổi length
test('sort: output has same length as input', () => {
  fc.assert(
    fc.property(fc.array(fc.integer()), (arr) => {
      expect(mySort(arr)).toHaveLength(arr.length)
    })
  )
})

// Property: formatPrice(parsePrice(str)) === str (round-trip)
test('price: round-trip encoding', () => {
  fc.assert(
    fc.property(
      fc.integer({ min: 0, max: 100_000_000 }),
      (price) => {
        expect(parsePrice(formatPrice(price))).toBe(price)
      }
    )
  )
})

// Custom arbitraries (domain objects)
const orderArbitrary = fc.record({
  userId: fc.uuid(),
  items: fc.array(fc.record({
    productId: fc.uuid(),
    quantity: fc.integer({ min: 1, max: 100 }),
    price: fc.integer({ min: 1000, max: 10_000_000 }),
  }), { minLength: 1, maxLength: 20 }),
  couponCode: fc.option(fc.string({ minLength: 6, maxLength: 12 })),
})

test('calculateTotal: result is always >= sum of items', () => {
  fc.assert(
    fc.property(orderArbitrary, (order) => {
      const itemsTotal = order.items.reduce((sum, i) => sum + i.price * i.quantity, 0)
      const result = calculateTotal(order)
      expect(result.total).toBeGreaterThanOrEqual(itemsTotal)
    })
  )
})
```

### Shrinking — tìm minimal failing case

```
Khi fast-check tìm thấy failing input:
  Input: [9999, -2, 0, 42, 1000001, -5, 3]
  → Tự động shrink → [1000001]  ← minimal case gây bug
  → Report cả original và shrunk input

Rất hữu ích: tìm ra chính xác edge case gây bug
Không cần manually binary search failing input
```

### Khi nào dùng property-based testing

```
✅ Tốt cho:
  - Serialization/deserialization (JSON, CSV, XML)
  - Encoding/decoding (base64, URL encode)
  - Mathematical operations (rounding, precision)
  - Sorting, filtering, searching algorithms
  - Data transformations
  - State machines (tất cả transitions)
  - APIs với complex input validation

⚠ Không phù hợp:
  - Business rules với external state (DB, API calls)
  - UI interactions
  - Tests cần predictable data để assert exact values
```

---

## 19. Accessibility Automation

### axe-core — automated a11y testing

```ts
// Playwright + axe-playwright
import { checkA11y, injectAxe } from 'axe-playwright'

test('homepage has no accessibility violations', async ({ page }) => {
  await page.goto('/')
  await injectAxe(page)

  // Check toàn bộ page
  await checkA11y(page, undefined, {
    detailedReport: true,
    detailedReportOptions: { html: true },
    // Chỉ check WCAG 2.1 AA
    runOnly: {
      type: 'tag',
      values: ['wcag2a', 'wcag2aa', 'wcag21a', 'wcag21aa'],
    },
  })
})

// Check chỉ 1 component
test('modal has proper focus management', async ({ page }) => {
  await page.goto('/products')
  await injectAxe(page)

  await page.getByRole('button', { name: 'Open modal' }).click()
  const modal = page.getByRole('dialog')

  await checkA11y(modal, undefined, {
    // Bỏ qua violations đã biết và đang fix
    axeOptions: {
      rules: {
        'color-contrast': { enabled: false },  // Đang fix, skip tạm
      },
    },
  })
})

// Storybook + axe addon — check từng component
// .storybook/preview.ts
import { withA11y } from '@storybook/addon-a11y'
export const decorators = [withA11y]
// → Mỗi story tự động có a11y panel
// → CI: npx storybook --ci → fail nếu có violations
```

### Automated vs manual a11y

```
Automated tools catch ~30-40% of a11y issues:
  ✅ Missing alt text
  ✅ Color contrast failures
  ✅ Missing form labels
  ✅ Duplicate IDs
  ✅ Empty buttons/links
  ✅ Missing landmark regions
  ✅ Invalid ARIA attributes

Manual testing cần cho:
  ❌ Focus order (logical? Makes sense?)
  ❌ Screen reader announcements (là gì, khi nào)
  ❌ Keyboard interaction patterns (đúng model không?)
  ❌ Cognitive load và clarity
  ❌ Motion sensitivity
  ❌ Zoom (400%) behavior

Rule of thumb:
  Automated → catch obvious violations trước khi merge
  Manual với real users → catch UX issues automated tools miss
  Screen reader test mỗi major release (VoiceOver, NVDA)
```

### A11y trong CI pipeline

```yaml
# Chạy trong staging, không block PR (tránh false positives)
- name: Accessibility audit
  run: |
    npx playwright test --grep @a11y
    # Hoặc: npx axe-cli https://staging.example.com --exit
  continue-on-error: true  # Warn, không fail
  # Sau khi team có process fix violations → đổi thành fail
```

---

## 20. Cross-Browser & Cross-Device Testing

### Browser matrix — thực tế 2025

```
Không cần test 100% browsers. Focus theo analytics của app.

Minimum viable matrix (web app):
  Chrome (latest):         ~65% market share → MUST
  Safari (latest):         ~19% → MUST (đặc biệt iOS Safari)
  Firefox (latest):        ~3% → SHOULD
  Edge (latest):           ~5% → SHOULD (same Blink engine, tương tự Chrome)
  Chrome Android:          Top mobile → MUST
  iOS Safari:              iPhone users → MUST

Extended matrix (nếu có enterprise users):
  + Chrome -1 version
  + Safari -1 version
  + Samsung Internet

KHÔNG cần:
  IE11 (Microsoft dropped 2022)
  Legacy Edge (pre-Chromium)
  Opera Mini (< 0.5% global, not webkit)
```

### Playwright cross-browser config

```ts
// playwright.config.ts — multi-browser matrix
import { defineConfig, devices } from '@playwright/test'

export default defineConfig({
  projects: [
    // Desktop browsers
    {
      name: 'Chrome',
      use: { ...devices['Desktop Chrome'] },
    },
    {
      name: 'Safari',
      use: { ...devices['Desktop Safari'] },
    },
    {
      name: 'Firefox',
      use: { ...devices['Desktop Firefox'] },
    },
    // Mobile browsers
    {
      name: 'iPhone 15',
      use: { ...devices['iPhone 15'] },
    },
    {
      name: 'Pixel 7',
      use: { ...devices['Pixel 7'] },
    },
    // Tablet
    {
      name: 'iPad Pro',
      use: { ...devices['iPad Pro 11'] },
    },
  ],

  // Chỉ critical tests chạy cross-browser (expensive)
  // Non-critical: chỉ Chrome
  grep: /@critical/,
})
```

### Real device testing — khi nào cần

```
Simulator/Emulator (local, CI):
  → Đủ cho: Layout, functionality, most interactions
  → Không catch: Rendering quirks, GPU issues, camera, NFC, haptics

Real devices (BrowserStack, AWS Device Farm):
  → Cần khi: App có hardware features, performance-sensitive, 
             accessibility (screen reader behaves differently)
  → Cost: ~$400-800/tháng (BrowserStack)
  
Strategy:
  CI:          Emulators (Chrome, Safari, Firefox)
  Pre-release: BrowserStack (top 5 real devices)
  Major launch: Manual QA trên thực tế với 10+ real devices
```

---

## 21. API Fuzz Testing

### Schemathesis — auto-generate từ OpenAPI spec

```bash
# Install
pip install schemathesis

# Fuzz API tự động từ OpenAPI spec
schemathesis run http://localhost:3000/openapi.json \
  --checks all \           # Kiểm tra: status codes, schema validation, server errors
  --stateful=links \       # Follow API links (pagination, related resources)
  --max-examples=200 \     # Số examples per endpoint
  --hypothesis-phases=generate,shrink \
  --report schemathesis-report.html

# Tích hợp CI
schemathesis run $API_URL/openapi.json \
  --checks not_a_server_error \  # Đơn giản nhất: không có 5xx
  --exit-zero-on-failures        # CI không fail (warn only khi mới setup)
```

### Schemathesis tìm được gì

```
500 Internal Server Error khi:
  - Integer field nhận string input
  - Required field thiếu
  - Null value trong non-nullable field
  - Boundary values (Integer.MAX_VALUE, negative numbers)
  - Đặc biệt: Unicode trong string fields thường crash regex

Security issues:
  - SQL injection qua fuzzing
  - Path traversal (../../../etc/passwd trong path params)
  - Large payload DoS (string dài 100,000 ký tự)

Schema violations:
  - API trả về fields không có trong schema
  - Type mismatch (schema: integer, actual: string)
  - Required fields thiếu trong response
```

### Custom fuzzing với Playwright

```ts
// Fuzz test form inputs
test('form handles unexpected inputs gracefully', async ({ page }) => {
  const maliciousInputs = [
    '<script>alert("xss")</script>',
    "'; DROP TABLE users; --",
    '../../../etc/passwd',
    'A'.repeat(10_000),  // Very long string
    '\0\0\0',            // Null bytes
    '𝓗𝓮𝓵𝓵𝓸',            // Unicode surrogate pairs
    '   ',               // Only whitespace
  ]

  for (const input of maliciousInputs) {
    await page.goto('/profile/edit')
    await page.getByLabel('Display name').fill(input)
    await page.getByRole('button', { name: 'Save' }).click()

    // App không crash, không expose raw error
    await expect(page.getByRole('alert')).not.toHaveText(/error|exception|stack/i)
    await expect(page).not.toHaveURL('/500')
  }
})
```

---

## 22. Chaos Engineering — Automated

### Principles

```
Traditional testing:  Verify system works correctly trong known conditions
Chaos engineering:    Discover how system fails in UNKNOWN conditions

Hypothesis-driven:
  1. Define steady state (normal behavior metrics)
  2. Hypothesize: "System remains stable when X fails"
  3. Inject failure X in production (or staging)
  4. Observe: steady state maintained?
  5. Fix nếu không maintained

Start nhỏ, staging trước, production sau:
  Staging:    Kill 1 pod, disconnect DB, add network latency
  Production: Only after proven stable in staging
              Start với canary group, not all users
```

### Chaos tools

```yaml
# Chaos Mesh (Kubernetes) — YAML-defined experiments
apiVersion: chaos-mesh.org/v1alpha1
kind: PodChaos
metadata:
  name: kill-order-service-pod
  namespace: testing
spec:
  action: pod-kill
  mode: one              # Kill 1 pod at a time
  selector:
    namespaces: [production]
    labelSelectors:
      app: order-service
  scheduler:
    cron: "@every 30m"   # Mỗi 30 phút kill 1 pod → test auto-recovery

---
apiVersion: chaos-mesh.org/v1alpha1
kind: NetworkChaos
metadata:
  name: payment-service-latency
spec:
  action: delay
  mode: all
  selector:
    labelSelectors:
      app: payment-service
  delay:
    latency: "200ms"
    correlation: "25"    # 25% jitter
    jitter: "50ms"
  duration: "5m"

---
apiVersion: chaos-mesh.org/v1alpha1
kind: IOChaos
metadata:
  name: disk-io-fault
spec:
  action: latency
  volumePath: /var/lib/postgresql/data
  delay: "100ms"
  percent: 50            # 50% of I/O operations bị delay
```

### GameDay — structured chaos

```
GameDay là scheduled event để practice failure response:

1. Announce trước (1 tuần): "Thứ 6 2pm, chúng ta sẽ kill DB primary"
2. Team chuẩn bị: Review runbooks, check monitoring, assign roles
3. Execute experiment: Kill DB primary
4. Observe: Bao lâu để detect? Bao lâu để recover? Alerts fire?
5. Post-mortem: Ghi lại findings, action items

Experiment ideas theo độ khó:
  Beginner:  Kill 1 pod, DNS failure cho 1 dependency
  Medium:    Kill entire deployment, inject 500ms latency
  Advanced:  DB primary failover, AZ failure simulation
  Expert:    Region-level failure (only in mature orgs)

Steady state metrics cần monitor:
  - Error rate < 0.1% baseline
  - p99 latency < 500ms baseline
  - Order creation success rate > 99.9%
  → Chaos experiment pass nếu metrics stay within threshold
```

---

## 23. Test Strategy Document

### Template — dùng ngay cho project mới

```markdown
# Test Strategy: [Project Name]
Version: 1.0 | Owner: [QA Lead / Tech Lead] | Last updated: [Date]

## 24. Scope
In scope:
  - [Feature A, Feature B, Core API]
Out of scope:
  - [Third-party integrations — tested by vendor]
  - [Legacy module X — scheduled for deprecation]

## 25. Test Levels & Ownership

| Level       | Owner      | Tools              | When          | Target          |
|-------------|------------|--------------------|--------------:|-----------------|
| Static      | Developer  | ESLint, TypeScript | Every commit  | 0 errors        |
| Unit        | Developer  | Vitest             | Every PR      | > 80% coverage  |
| Integration | Developer  | Supertest, TC      | Every PR      | All endpoints   |
| Contract    | Developer  | Pact               | Every PR      | All providers   |
| E2E         | Dev + QA   | Playwright         | Merge to main | Critical paths  |
| Performance | Dev + SRE  | k6                 | Pre-release   | p95 < 500ms     |
| Security    | Dev + SecOps| Semgrep, DAST     | Every PR      | 0 HIGH/CRITICAL |
| Exploratory | QA         | Manual             | Per sprint    | Risk areas      |

## 26. Entry & Exit Criteria

Entry (bắt đầu test giai đoạn mới):
  - Code review đã approve
  - Build thành công
  - Unit tests pass
  - Feature branch deployed to staging

Exit (done testing):
  - 0 open P1/P2 bugs
  - All automated tests pass
  - Performance baseline met
  - Security scan clean

## 27. Risk-Based Testing
High risk areas → more testing:
  - Payment flow (revenue impact)
  - Authentication (security impact)
  - Data migration (data integrity)

Low risk areas → less testing:
  - Admin UI (internal users only)
  - Help/FAQ pages (static content)

## 28. Test Environments

| Environment | Purpose              | Data             | Reset policy    |
|-------------|----------------------|------------------|-----------------| 
| local       | Developer testing    | Seeded + fixtures| Per developer   |
| CI          | Automated tests      | Containers       | Per pipeline run|
| staging     | Integration, E2E     | Anonymized subset| Weekly          |
| production  | Smoke tests only     | Real             | Never           |

## 29. Defect Management
Severity:
  P1 Critical: System down, data loss, security breach → Fix < 4h
  P2 High:     Core feature broken → Fix same sprint
  P3 Medium:   Feature degraded → Fix next sprint
  P4 Low:      Cosmetic, minor UX → Backlog

## 30. Automation Strategy
Automate:  Repeatable, stable, high-value tests
Manual:    Exploratory, usability, one-off investigations

Automation first candidates:
  - Happy path of every feature
  - Regression tests for P1/P2 bugs fixed
  - Data-driven tests (many input combinations)
```

---

## 31. Test Environment Management

### Environment parity — mục tiêu và thực tế

```
Lý tưởng: staging = production (same config, same data volume)
Thực tế:  Staging thường nhỏ hơn, data khác

Phải giống production:
  ✅ OS, runtime versions (Node 20, Python 3.11, PostgreSQL 16)
  ✅ Network topology (same services, same routing)
  ✅ Auth flow (real OAuth, không mock)
  ✅ Third-party integrations (Stripe test mode, không mock)
  ✅ Infrastructure config (K8s resource limits, nginx config)

Có thể khác:
  ⚡ Scale: 2 pods thay 20 pods
  ⚡ Data: Anonymized subset thay production data
  ⚡ Cost-optimized instances (t3.medium thay c6i.xlarge)

Nguy hiểm nhất: "Works in staging, fails in production"
  Nguyên nhân thường gặp:
  - Environment variable khác (missing var in prod)
  - Race condition chỉ xuất hiện dưới load cao
  - Memory limit khác (staging không OOM, prod OOM)
  - SSL/TLS certificate issues (staging dùng self-signed)
  - Clock skew giữa instances (chỉ thấy dưới real scale)
```

### Test data isolation

```
Environment isolation:
  Dev:     Mỗi developer có schema riêng (schema-per-developer)
  CI:      Mỗi pipeline run có database riêng (tự tạo, tự xóa)
  Staging: 1 shared database, truncate trước mỗi test run
  Prod:    Không test data, chỉ smoke tests với real accounts

Data anonymization pipeline:
  1. Export production snapshot (weekly)
  2. Anonymize: hash emails, randomize names, mask payment data
  3. Subset: lấy 5% rows (giữ referential integrity)
  4. Import vào staging
  → Staging có realistic data volume và shape, không có PII
```

---

## 32. Flaky Test Management

### Definition and classification

```
Flaky test: Test fail intermittently mà không có code changes
  Loại 1: Timing-dependent (async không wait đúng)
  Loại 2: Order-dependent (phụ thuộc test chạy trước)
  Loại 3: Environment-dependent (CI vs local)
  Loại 4: Data-dependent (random data conflict, race condition)
  Loại 5: External dependency (third-party API timeout)
```

### Flaky test workflow

```
Step 1: Detect
  Phương pháp A: Chạy test 10 lần liên tiếp
    npx vitest run --reporter=verbose --retry=0 2>&1 | grep -E "FAIL|PASS"
  Phương pháp B: Track CI results trong 30 ngày
    Test fail trong > 5% runs mà không có code changes = flaky
  Phương pháp C: GitHub Actions re-run: 
    Test fail → re-run automatically → pass = flaky indicator

Step 2: Triage
  High business value + easy fix   → Fix this sprint (P1)
  High business value + hard fix   → Quarantine + fix next sprint
  Low business value                → Delete (bold but effective)

Step 3: Quarantine (không để block CI)
  // Vitest
  test.skip('flaky: timing issue with payment webhook', () => { ... })
  // Playwright
  test.fixme('flaky: race condition in cart update', async () => { ... })
  // Tag để track
  test('@flaky should update inventory after order', async () => { ... })
  // Run separately: npx playwright test --grep @flaky

Step 4: Fix root cause (không chỉ add retry)
  Timing: await element.waitFor() thay waitForTimeout
  Order:  beforeEach cleanup, không share state
  Data:   Unique data per test (UUID, timestamp)
  Network: Mock external calls, không hit real APIs

Step 5: Monitor
  Dashboard: Flaky rate per test, per suite, trend over time
  Alert: Nếu flaky rate > 5% → block release process
  SLA: Quarantined tests phải fix trong 2 sprints
```

### Anti-patterns khi handle flaky tests

```
❌ Thêm retry mà không fix root cause
  retry: 3 → test fail 2 lần rồi pass = "works" nhưng chậm
  → Root cause vẫn còn, sẽ fail production

❌ Disable test mãi mãi
  skip('TODO: fix this someday') → never gets fixed
  → Coverage gap, bugs slip through

❌ "Rerun failed tests" làm thành default CI policy
  → Team không cần fix flaky tests → số flaky tăng dần

✅ Flaky test = bug in test code
  Fix như fix production bugs: severity, SLA, owner
```

---

## 33. Test Metrics & Reporting

### Metrics cần track

```
Test health metrics:
  Pass rate:         % tests pass per run (target > 99%)
  Flaky rate:        % tests fail intermittently (target < 1%)
  Execution time:    Trend theo thời gian (tăng = vấn đề)
  Coverage:          % code covered (track trend, không chỉ absolute)

Quality metrics:
  Defect escape rate:   Bugs found in production / total bugs
  MTTR (Mean Time to Recover): Sau khi test fail, bao lâu fix?
  Test debt ratio:      Manual tests / (Manual + Automated)

DORA metrics liên quan đến testing:
  Change failure rate:  % deployments gây rollback/incident
    → Testing tốt → CFR thấp (target < 5%)
  Lead time for changes: Commit → production
    → Testing speed là bottleneck lớn nhất
```

### Test reporting trong CI

```yaml
# GitHub Actions — test results summary
- name: Run tests
  run: npx vitest run --reporter=junit --outputFile=test-results.xml

- name: Publish test results
  uses: EnricoMi/publish-unit-test-result-action@v2
  if: always()
  with:
    files: test-results.xml
    # Shows: pass/fail counts, flaky tests, slowest tests

# Playwright report
- uses: actions/upload-artifact@v3
  if: always()
  with:
    name: playwright-report
    path: playwright-report/
    retention-days: 30
```

### Dashboard tools

```
Allure Report: Rich HTML reports, history, trends
  npx allure generate allure-results --clean
  npx allure open

Test Rail: Test case management + automation results
  Phù hợp: Teams có QA department, compliance requirements

Grafana dashboard custom:
  Metric: test_suite_duration_seconds{suite="e2e"}
  Alert:  duration tăng > 50% so với 7-day average

BuildPulse / Trunk.io:
  Specialized flaky test detection
  CI integration, auto-quarantine
```

---

## 34. Shift-Left Testing

### What it means

```
Traditional (Shift-Right):
  Dev codes → QA tests → Deploy → Monitor
  → Bugs found late = expensive to fix

Shift-Left:
  → Bugs found EARLY = cheap to fix
  → Testing activities moved LEFT in SDLC (earlier)

Shift-Left practices:
  Requirement level:  3 Amigos (BA + Dev + QA) review stories
  Design level:       Architecture review checklist
  Code level:         TDD, code review với security mindset
  Build level:        Unit + integration tests in CI
  Not just QA's job:  Every developer owns test quality
```

### 3 Amigos — trước khi sprint bắt đầu

```
Participants:
  Product Owner / BA: "Đây là feature tôi muốn"
  Developer:          "Đây là cách tôi sẽ implement"
  QA:                 "Đây là những gì có thể sai"

Output: Acceptance criteria → Gherkin scenarios → stories estimable

Questions QA raises:
  "Điều gì xảy ra nếu user submit form 2 lần?"
  "Nếu payment timeout ở 29 giây (limit 30s)?"
  "User có thể upload file 0 bytes không?"
  "Concurrent users edit cùng record?"

Benefits:
  → Dev understands edge cases BEFORE coding
  → QA understands technical constraints BEFORE testing
  → Fewer surprises, less rework
```

### Definition of Done — bao gồm testing

```
Code không "done" cho đến khi:
  ✅ Feature works theo acceptance criteria
  ✅ Unit tests cover business logic
  ✅ Integration tests cover API endpoints
  ✅ No new security vulnerabilities (npm audit clean)
  ✅ Code reviewed và approved
  ✅ E2E test cho critical paths (nếu applicable)
  ✅ Documentation updated (nếu API thay đổi)
  ✅ Performance: không regress p99 > 20%
  ✅ No new console errors/warnings

QA Definition of Done (additional):
  ✅ Exploratory testing completed
  ✅ Cross-browser check (Chrome + Safari minimum)
  ✅ Regression suite pass
  ✅ Sign-off từ Product Owner
```

---

## Checklist — Cập Nhật Đầy Đủ

> 🔴 MUST = block ship | 🟠 SHOULD = fix trước prod | 🟡 NICE = tech debt

### Unit & Integration

🔴 MUST:
- [ ] Business logic có unit tests (coverage > 70%)
- [ ] Tests isolated — không phụ thuộc nhau, không cần internet
- [ ] Không hardcode production URLs, secrets trong test files

🟠 SHOULD:
- [ ] AAA pattern: Arrange, Act, Assert trong mỗi test
- [ ] `jest.clearAllMocks()` trong `beforeEach`
- [ ] Error paths tested (4xx, 5xx, empty, null, boundary values)
- [ ] Integration tests dùng real DB qua Testcontainers
- [ ] DB isolation per test (transaction rollback hoặc truncate)
- [ ] Test factories với faker.js (không hardcode fixtures)
- [ ] Coverage > 80% cho business logic

🟡 NICE:
- [ ] Mutation testing score > 70% (Stryker)
- [ ] Property-based tests cho algorithms, serialization
- [ ] Contract tests (Pact) cho service boundaries

### E2E & Visual

🔴 MUST:
- [ ] Critical paths có E2E (login, checkout, core feature)
- [ ] E2E không share state giữa tests

🟠 SHOULD:
- [ ] Page Object Model, không brittle CSS selectors
- [ ] Third-party APIs mocked (payment, email, SMS)
- [ ] Mobile viewport tested (iPhone + Android minimum)
- [ ] Trace/screenshot/video khi fail trong CI
- [ ] Cross-browser: Chrome + Safari minimum

🟡 NICE:
- [ ] Visual regression (Chromatic / Playwright screenshots)
- [ ] a11y automation (axe-core) trong E2E
- [ ] BDD/Gherkin nếu có BA/QA non-technical stakeholders

### Performance & Security

🔴 MUST:
- [ ] Dependency audit trong CI (`npm audit --audit-level=high`)
- [ ] Secrets scanning (gitleaks) trong CI
- [ ] Container image scanning (Trivy)

🟠 SHOULD:
- [ ] Load test trước major releases (k6)
- [ ] Thresholds: p95 < 500ms, error rate < 1%
- [ ] SAST (Semgrep/CodeQL) trong CI
- [ ] API fuzz testing (Schemathesis từ OpenAPI spec)
- [ ] Auth edge cases: expired, invalid, missing token

🟡 NICE:
- [ ] Chaos engineering trong staging (Chaos Mesh)
- [ ] Soak test (8h+) detect memory leaks
- [ ] Performance regression tracking trong CI

### Process & Strategy

🔴 MUST:
- [ ] Flaky tests không block CI indefinitely (quarantine policy)
- [ ] CI pipeline có test gates theo thứ tự (lint → unit → integration → E2E)

🟠 SHOULD:
- [ ] Test strategy document (scope, levels, environments, ownership)
- [ ] Definition of Done bao gồm testing criteria
- [ ] Flaky test tracking (< 1% flaky rate target)
- [ ] Test environments tách biệt (CI, staging, production)
- [ ] Anonymized data trong staging (không dùng production PII)

🟡 NICE:
- [ ] 3 Amigos sessions trước khi sprint bắt đầu
- [ ] Test metrics dashboard (pass rate, flaky rate, coverage trend)
- [ ] DORA metrics tracking (Change Failure Rate)
- [ ] GameDay exercises mỗi quý


---

## 35. AI-Assisted Test Generation

### Practical workflow (2025)

```typescript
// Using GitHub Copilot / Cursor / Claude to generate tests
// Best practice: Generate as starting point, review and refine

// 1. Write the function first
function calculateDiscount(price: number, loyaltyYears: number): number {
  if (price <= 0) throw new Error('Price must be positive')
  const baseDiscount = price > 1_000_000 ? 0.10 : 0
  const loyaltyBonus = Math.min(loyaltyYears * 0.01, 0.05)
  return price * (baseDiscount + loyaltyBonus)
}

// 2. Prompt to AI: "Write comprehensive tests for this function including edge cases"
// AI generates (review before accepting):
describe('calculateDiscount', () => {
  it('applies 10% base discount for orders over 1M VND', () => {
    expect(calculateDiscount(1_500_000, 0)).toBe(150_000)
  })
  it('applies loyalty bonus (1% per year, max 5%)', () => {
    expect(calculateDiscount(1_000_000, 3)).toBe(30_000)  // 3% loyalty
    expect(calculateDiscount(1_000_000, 10)).toBe(50_000)  // capped at 5%
  })
  it('combines base discount and loyalty bonus', () => {
    expect(calculateDiscount(2_000_000, 5)).toBe(300_000)  // 10% + 5%
  })
  it('throws for non-positive price', () => {
    expect(() => calculateDiscount(0, 0)).toThrow('Price must be positive')
    expect(() => calculateDiscount(-100, 0)).toThrow()
  })
})

// 3. Always verify: Does the test actually test what we care about?
//    AI may miss: boundary conditions, concurrent access, specific business rules
```

### When AI test generation helps vs hurts

```
Helps:
  Generating test boilerplate quickly (describe blocks, it statements)
  Suggesting edge cases you might not have thought of
  Writing parameterized test data (test.each tables)
  Converting existing tests to new framework syntax

Hurts (review carefully):
  AI may test implementation, not behavior (test internals)
  Generated tests may be redundant (test same thing multiple ways)
  Missing domain-specific edge cases (business rules AI doesn't know)
  Hallucinated test assertions that seem correct but aren't

Rule: AI generates the structure, you verify the assertions.
      Never merge AI tests without running them AND reviewing each assertion.
```
