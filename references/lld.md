# Low-Level Design — Reference

---

## 1. Design Patterns — Chi Tiết

### Creational

**Singleton — và khi nào KHÔNG dùng**:
```
Dùng: DB connection pool, config manager, logger, feature flag service
Không dùng: Mọi thứ (over-used pattern, tạo coupling ẩn)

Problems với Singleton:
  - Global mutable state → khó test (cần mock)
  - Thread safety trong multi-threaded env
  - Hard to parallelize tests

Alternative: Dependency injection — truyền instance vào thay vì global access
  Constructor injection > Singleton trong hầu hết cases
```

**Factory Method vs Abstract Factory**:
```
Factory Method: Tạo 1 loại object, subclass quyết định loại nào
  NotificationFactory.create('email') → EmailNotification
  NotificationFactory.create('sms') → SMSNotification

Abstract Factory: Tạo family of related objects
  ThemeFactory → tạo Button + Input + Card cùng theme
  LightThemeFactory: { createButton() → LightButton, createInput() → LightInput }
  DarkThemeFactory:  { createButton() → DarkButton, createInput() → DarkInput }

Khi nào dùng Abstract Factory: Khi cần đảm bảo objects "cùng family" được tạo cùng nhau
```

**Builder — với validation**:
```ts
class QueryBuilder {
  private table?: string
  private conditions: string[] = []
  private limitValue?: number

  from(table: string) { this.table = table; return this }
  where(condition: string) { this.conditions.push(condition); return this }
  limit(n: number) { this.limitValue = n; return this }

  build(): Query {
    if (!this.table) throw new Error('table is required')
    if (this.limitValue && this.limitValue > 1000)
      throw new Error('limit cannot exceed 1000')
    return new Query(this.table, this.conditions, this.limitValue)
  }
}

// Usage:
const q = new QueryBuilder().from('users').where('active = true').limit(10).build()
```

### Structural

**Adapter — real-world ví dụ**:
```ts
// Third-party payment SDK (không thể sửa)
class StripeSDK {
  createCharge(amountCents: number, currency: string) { ... }
}

// Internal interface cần
interface PaymentProvider {
  charge(amountDollars: number): Promise<Receipt>
}

// Adapter
class StripeAdapter implements PaymentProvider {
  constructor(private stripe: StripeSDK) {}

  async charge(amountDollars: number): Promise<Receipt> {
    const result = await this.stripe.createCharge(amountDollars * 100, 'usd')
    return { id: result.chargeId, amount: amountDollars }
  }
}

// Lợi ích: Đổi từ Stripe sang Braintree → chỉ tạo BraintreeAdapter mới
```

**Decorator vs Inheritance**:
```ts
// Inheritance (xấu): Explosive combinations
class LoggedCachedRetryingUserService extends UserService { ... }

// Decorator (tốt): Compose behaviors
const service = new RetryDecorator(
  new CacheDecorator(
    new LogDecorator(
      new UserService()
    )
  )
)
// Thêm bất kỳ combination nào mà không cần subclass mới
```

**Proxy — 3 loại**:
```
Virtual Proxy: Lazy loading
  ImageProxy load ảnh thực chỉ khi cần display (không phải khi khởi tạo)

Protection Proxy: Access control
  SecuredService kiểm tra permission trước khi delegate

Remote Proxy: Communication với remote service
  Stub trong RPC systems (gRPC client stub)
```

### Behavioral

**Observer — synchronous vs asynchronous**:
```ts
// Synchronous observer (mọi handler chạy trước khi return)
class EventEmitter {
  emit(event: string, data: any) {
    this.handlers[event]?.forEach(handler => handler(data))
    // Nếu 1 handler throw → toàn bộ chain bị break
  }
}

// Async (better for decoupled systems)
class AsyncEventBus {
  async emit(event: string, data: any) {
    await Promise.all(this.handlers[event]?.map(h => h(data)))
    // Cần handle individual failures (Promise.allSettled)
  }
}

// Message Queue (distributed systems)
await queue.publish('order.placed', { orderId: 123 })
// Decoupled hoàn toàn, handler chạy riêng
```

**Strategy — ví dụ thực tế**:
```ts
// Sort strategy
interface SortStrategy<T> {
  sort(items: T[], compareFn: (a: T, b: T) => number): T[]
}

class TimSort implements SortStrategy<any> { ... }  // Default JS
class MergeSort implements SortStrategy<any> { ... }  // Stable, predictable
class RadixSort implements SortStrategy<number> { ... }  // Fast for integers

// Compression strategy
interface CompressionStrategy {
  compress(data: Buffer): Buffer
  decompress(data: Buffer): Buffer
}
// Swap between gzip, brotli, lz4 depending on use case
```

**Command với Undo/Redo**:
```ts
interface Command {
  execute(): void
  undo(): void
}

class CommandHistory {
  private history: Command[] = []
  private index = -1

  execute(cmd: Command) {
    cmd.execute()
    this.history = this.history.slice(0, this.index + 1) // clear redo history
    this.history.push(cmd)
    this.index++
  }

  undo() {
    if (this.index >= 0) {
      this.history[this.index].undo()
      this.index--
    }
  }

  redo() {
    if (this.index < this.history.length - 1) {
      this.index++
      this.history[this.index].execute()
    }
  }
}
```

---

## 2. Architecture Patterns Chi Tiết

### Layered Architecture — phổ biến nhất

```
Controller (HTTP, input validation)
  → Service (business logic, orchestration)
    → Repository (data access abstraction)
      → Database

Rules:
  - Controller không có business logic
  - Service không biết về HTTP (không dùng req/res)
  - Repository không có business logic
  - Dependency injection để dễ test

Common mistake: "Fat service"
  Service gọi 5 other services, 3 repositories, emit 4 events
  → Khó test, khó maintain
  Solution: Chia nhỏ service, hoặc dùng Use Case pattern
```

### CQRS — khi nào phù hợp và edge cases

```
Use cases tốt:
  - Read và write model khác nhau nhiều
    Write: normalized relational data
    Read: denormalized JSON cho UI
  - Read cần scale riêng (read replicas)
  - Event sourcing (natural fit)
  - Complex reporting queries

Edge cases:
  1. Eventual consistency lag
     Write → Event → Update read model → 50-200ms lag
     User write rồi read ngay → thấy data cũ
     Solution: "Read your own writes" (poll cho đến khi see your write)
     hoặc: Return updated data trực tiếp từ command handler

  2. Read model out of sync
     Bug trong event handler → read model sai
     Solution: Replay events để rebuild read model từ đầu
     Cần: Event store immutable, events idempotent

  3. Race condition trong read model update
     2 events arrive simultaneously → update cùng read model record
     Solution: Optimistic locking hoặc serial processing per aggregate
```

### Saga Pattern — Choreography vs Orchestration

```
Choreography:
  OrderService emit "order.created"
  PaymentService listen → charge → emit "payment.processed"
  InventoryService listen → reserve → emit "inventory.reserved"
  ShipmentService listen → schedule

  Pros: Loose coupling, simple
  Cons: Hard to track overall flow, distributed debugging nightmare
  Dùng khi: Simple, ít steps, team nhỏ

Orchestration:
  OrderSaga (central orchestrator):
    1. Send "ChargePayment" to PaymentService
    2. Await "PaymentCharged" or "PaymentFailed"
    3. If success: Send "ReserveInventory" to InventoryService
    4. If failed: Send "CancelOrder" to OrderService (compensation)

  Pros: Easy to see overall flow, centralized error handling
  Cons: Orchestrator có thể trở thành bottleneck, coupling
  Dùng khi: Complex flows, nhiều compensation steps

Compensation transactions (undo):
  PlaceOrder saga fail tại step 3 (inventory):
    Compensate step 2: Refund payment
    Compensate step 1: Cancel order
  
  Important: Compensation phải idempotent
    RefundPayment(orderId) phải safe to call multiple times
```

---

## 3. Data Modeling Chi Tiết

### SQL Normalization vs Denormalization

```
3NF (normalized — tránh anomalies):
  users: id, name, email
  orders: id, user_id, created_at
  order_items: id, order_id, product_id, quantity, price_at_purchase

  Lợi ích: No data duplication, update 1 chỗ
  Nhược: JOIN chậm khi scale

Denormalized (cho read performance):
  orders: id, user_id, user_name, user_email, items: [{...}], total
  
  Lợi ích: 1 query lấy tất cả, không cần JOIN
  Nhược: Duplicate data (user_name ở cả users và orders)
  Acceptable khi: user_name ở orders là historical fact (không update)

When to denormalize:
  - Read >> Write (analytics, reporting)
  - JOIN performance không acceptable
  - Data is historical/immutable (price at time of purchase)
```

### Schema evolution — migrations

```
Strategies cho zero-downtime migrations:

Adding column (safe):
  ALTER TABLE users ADD COLUMN phone VARCHAR(20);
  → Không cần code change ngay, add column first

Removing column (risky):
  Step 1: Remove references in code (deploy)
  Step 2: Verify no code reads/writes column
  Step 3: ALTER TABLE users DROP COLUMN phone;
  Never: Drop column và deploy code cùng lúc

Renaming column (very risky):
  Step 1: Add new column
  Step 2: Dual write (write to both old and new)
  Step 3: Backfill new column từ old
  Step 4: Switch reads to new column
  Step 5: Remove writes to old column
  Step 6: Drop old column
  Bao giờ cũng cần nhiều deploys, không bao giờ atomic

Large table migration:
  ALTER TABLE big_table ADD COLUMN ... → lock table trong giờ
  Solution: pg_repack, pt-online-schema-change (Percona)
  Hoặc: Create new table, copy data batch by batch, rename tables
```

### Document DB — khi embed, khi reference

```
Embed (nested document):
  Dùng khi:
    - Data luôn đọc cùng nhau (order + order items)
    - Parent–child với 1 chiều (post → comments, nếu ít comments)
    - Dữ liệu không share giữa documents
  
  Limit MongoDB:
    - Document size max 16MB
    - Array lớn (> 1000 items) → performance xuống
    - Không thể query embedded document riêng lẻ efficiently

Reference (ID reference):
  Dùng khi:
    - Data có lifecycle riêng (user ≠ order)
    - Many-to-many (products ↔ categories)
    - Array có thể unbounded (user → followers, có thể triệu người)
    - Cần query embedded data riêng lẻ
```

---

## 4. API Contract Design Chi Tiết

### REST — đầy đủ hơn

```
Resource naming:
  /users                    → collection
  /users/123                → resource
  /users/123/orders         → sub-resource collection
  /users/123/orders/456     → sub-resource
  
  KHÔNG: /users/123/getOrders (verb trong URL)
  KHÔNG: /getUserById/123 (verb + query in path)

Idempotency:
  GET, HEAD, OPTIONS, PUT, DELETE → idempotent (safe to retry)
  POST → NOT idempotent (tạo resource mới mỗi call)
  PATCH → NOT idempotent by default (tùy implementation)

  Cho POST idempotent: Idempotency-Key header
  POST /payments
  Idempotency-Key: unique-uuid-per-payment
  Server store key 24h, return same response nếu duplicate

Status codes hay dùng sai:
  200: Success
  201: Created (POST tạo mới)
  204: No Content (DELETE, update không return body)
  400: Bad Request (validation error, malformed JSON)
  401: Unauthorized (chưa authenticate, cần login)
  403: Forbidden (đã authenticate, nhưng không có permission)
  404: Not Found
  409: Conflict (duplicate, version conflict)
  422: Unprocessable Entity (validation pass nhưng business rule fail)
  429: Too Many Requests (rate limited)
  500: Internal Server Error
  503: Service Unavailable (circuit open, maintenance)

Phân biệt 401 vs 403:
  401: "Bạn là ai? Chưa login"
  403: "Tôi biết bạn là ai, nhưng bạn không được phép làm điều này"
```

### GraphQL — best practices và N+1

```
N+1 problem:
  query { posts { author { name } } }
  → 1 query fetch posts
  → N queries fetch author per post
  
  Solution: DataLoader
    - Batch: Gom tất cả author IDs trong 1 tick → 1 SQL IN query
    - Cache: Không fetch cùng author 2 lần trong 1 request
    
  const userLoader = new DataLoader(async (userIds) => {
    const users = await db.query('SELECT * FROM users WHERE id IN (?)', [userIds])
    return userIds.map(id => users.find(u => u.id === id))
  })

Schema design:
  Connection pattern cho pagination:
  type UserConnection {
    edges: [UserEdge!]!
    pageInfo: PageInfo!
    totalCount: Int
  }
  type UserEdge {
    node: User!
    cursor: String!
  }

  Input types cho mutations:
  mutation CreatePost($input: CreatePostInput!) { ... }
  input CreatePostInput {
    title: String!
    content: String!
  }
  → Dễ extend input mà không break signature

  Error handling options:
  Option 1: errors array (GraphQL spec)
  Option 2: Union types (type safe)
    type CreatePostResult = CreatePostSuccess | ValidationError | NotFoundError
    mutation createPost($input: CreatePostInput!): CreatePostResult!
```

---

## 5. SOLID Principles — Practical

```
S — Single Responsibility
  Class/function nên có 1 lý do để thay đổi
  
  BAD:
    class UserService {
      getUser() { ... }
      sendEmail() { ... }   // ← email không phải trách nhiệm của UserService
      generateReport() { ... }
    }
  
  GOOD:
    class UserService { getUser() }
    class EmailService { sendEmail() }
    class ReportService { generateReport() }

O — Open/Closed
  Mở để extend, đóng để modify
  Thêm feature mới → tạo class mới, không sửa class cũ
  
  BAD:
    function calculateShipping(type: string) {
      if (type === 'standard') { ... }
      if (type === 'express') { ... }
      // Thêm 'overnight' → phải sửa hàm này → risk break existing
    }
  
  GOOD:
    interface ShippingStrategy { calculate(): number }
    class StandardShipping implements ShippingStrategy { ... }
    class ExpressShipping implements ShippingStrategy { ... }
    class OvernightShipping implements ShippingStrategy { ... } // mới, không sửa code cũ

L — Liskov Substitution
  Subclass phải behave như parent class — không break assumptions
  
  BAD:
    class Rectangle { setWidth(w), setHeight(h) }
    class Square extends Rectangle {
      setWidth(w) { this.width = w; this.height = w } // ← break Rectangle contract
    }

I — Interface Segregation
  Interface nhỏ và focused, không force implement methods không dùng
  
  BAD:
    interface Animal { fly(); swim(); run() }
    class Dog implements Animal { fly() { throw Error('cannot fly') } ... }
  
  GOOD:
    interface Flyable { fly() }
    interface Swimmable { swim() }
    interface Runnable { run() }
    class Dog implements Runnable, Swimmable { ... }

D — Dependency Inversion
  Depend on abstractions (interfaces), not concretions
  
  BAD:
    class OrderService {
      private db = new PostgresDatabase() // ← hard coupling
    }
  
  GOOD:
    class OrderService {
      constructor(private db: DatabaseInterface) {} // ← inject
    }
    // Test: inject MockDatabase
    // Prod: inject PostgresDatabase
```

---

## 6. Algorithms & Data Structures

### When to use what — decision tree

```
Cần fast lookup by key? → HashMap O(1) avg
  → Nhiều collision? → trie (prefix keys) hoặc perfect hashing

Cần ordered data + range query? → Sorted structure
  → In-memory: TreeMap/SortedMap O(log n)
  → DB: B-tree index

Cần top-K (largest/smallest)? → Heap O(log k)
  → Min-heap size K cho top-K largest
  → Max-heap size K cho top-K smallest

Cần BFS (shortest path, level order)? → Queue
Cần DFS (all paths, cycle detection)? → Stack (hoặc recursion)
Cần prefix search? → Trie
Cần count frequency? → HashMap
Cần unique items? → HashSet
Cần sorted unique? → TreeSet

Sliding window (subarray):
  → Contiguous subarray với condition → sliding window + deque
  → Count distinct elements in window → HashMap

Two pointers:
  → Sorted array: pair sum, merge, remove duplicates
  → In-place array manipulation
```

### Bài toán hay gặp trong system design

**Consistent hashing**:
```
Problem: Hash(request) % N servers → add 1 server → N-1 servers phải remapped
Solution: Consistent hashing ring
  - Mỗi server có nhiều virtual nodes trên ring
  - Request hash → find nearest server clockwise
  - Add 1 server → chỉ 1/N data remapped
  
Used by: Cassandra, Amazon Dynamo, Redis Cluster, CDN
```

**Bloom filter**:
```
Problem: Kiểm tra "đã từng thấy chưa" với millions of items
  Full set lookup: tốn memory/time
  
Solution: Bloom filter
  - Space-efficient probabilistic data structure
  - False positive possible (say "yes" when actually "no")
  - No false negative (never say "no" when actually "yes")
  - Cannot delete (use Counting Bloom Filter nếu cần)

Use cases:
  - CDN: Đã có cache chưa? (false positive = extra origin request, OK)
  - DB: Key exists? (tránh disk read cho không tồn tại)
  - Spam filter: Email từng gặp chưa?
```

**HyperLogLog**:
```
Đếm unique elements với sai số nhỏ (~0.81%), dùng cực ít memory
  1M unique users → HyperLogLog chỉ dùng ~12KB vs 4MB exact set

Redis PFADD, PFCOUNT
Use cases: DAU, unique visitors, cardinality estimation
```

**Rate limiting với Redis**:
```
Fixed window counter:
  key = "rate:{userId}:{minute}"
  INCR key → count
  EXPIRE key 60
  if count > limit: reject

Sliding window (accurate):
  key = "rate:{userId}"
  ZADD key (timestamp, timestamp)  → sorted set
  ZREMRANGEBYSCORE key 0 (now - window)  → remove old
  count = ZCARD key
  if count > limit: reject

Token bucket:
  Dùng Lua script hoặc Redis module để atomic operation
  refill_rate = tokens/second
  current_tokens = HGET bucket tokens
  time_elapsed = now - last_refill
  new_tokens = min(max_tokens, current_tokens + elapsed * refill_rate)
```

---

---

## 7. Domain-Driven Design (DDD)

### Tại sao DDD quan trọng

```
Traditional layered architecture:
  DB schema → drives everything (data-centric)
  → Business logic scattered, anemic domain models

DDD: Model business domain explicitly trong code
  → Ubiquitous language: developer + domain expert dùng same terms
  → Complex business logic tập trung, testable, maintainable
```

### Strategic Design — Big Picture

**Bounded Context:**
```
Mỗi Bounded Context là autonomous model với clear boundary:
  E-commerce:
    Order Context:    "Order", "LineItem", "Shipping address"
    Catalog Context:  "Product", "Category", "SKU"
    Inventory Context:"Stock", "Warehouse", "Reservation"
    Billing Context:  "Invoice", "Payment", "Discount"

  "Product" trong Catalog ≠ "Product" trong Inventory
  → Khác model, khác attributes, khác behavior
  → Không share database tables giữa Bounded Contexts

Bounded Context mapping:
  Shared Kernel:    2 contexts share a small common model (agreeable to both)
  Customer/Supplier: Upstream (supplier) / downstream (customer) dependency
  Conformist:        Downstream conform to upstream model (no power to change)
  Anti-Corruption Layer (ACL): Translate between two incompatible models
  Open Host Service: Published language (API) for many consumers
  Published Language: Well-documented integration format (e.g. events schema)
```

**Ubiquitous Language:**
```
Code phải reflect business language — không technical jargon trong domain:

BAD:
  class UserRecord { data: Dict }
  def process_user_record(record) → update_db(record)

GOOD:
  class Customer { subscribe(plan: Plan) }
  class Order { confirm() | cancel(reason) | fulfill() }
  class Payment { charge() | refund(amount: Money) }

Rule: Nếu domain expert đọc code của bạn, họ hiểu được không?
```

### Tactical Design — Building Blocks

**Entity:**
```typescript
// Có identity (ID), có lifecycle, mutable
class Order {
  private id: OrderId
  private status: OrderStatus
  private items: OrderItem[]

  // Business behavior trong entity, không anemic DTO
  addItem(product: Product, qty: number): void {
    if (this.status !== 'draft') throw new OrderNotEditableError()
    const existing = this.items.find(i => i.productId === product.id)
    if (existing) existing.increaseQuantity(qty)
    else this.items.push(new OrderItem(product, qty))
  }

  confirm(): DomainEvent[] {
    if (this.items.length === 0) throw new EmptyOrderError()
    this.status = 'confirmed'
    return [new OrderConfirmed(this.id, this.total())]
  }

  total(): Money {
    return this.items.reduce((sum, i) => sum.add(i.subtotal()), Money.zero())
  }
}
```

**Value Object:**
```typescript
// Không có identity, immutable, equality by value
class Money {
  constructor(
    private readonly amount: number,
    private readonly currency: Currency
  ) { Object.freeze(this) }

  add(other: Money): Money {
    if (other.currency !== this.currency) throw new CurrencyMismatchError()
    return new Money(this.amount + other.amount, this.currency)
  }

  equals(other: Money): boolean {
    return this.amount === other.amount && this.currency === other.currency
  }
}

// Other value objects: Address, Email, PhoneNumber, DateRange, Percentage
// Rule: Nếu replace toàn bộ fields → same thing → Value Object
```

**Aggregate:**
```typescript
// Cluster of entities/VOs treated as unit, có Aggregate Root
// Tất cả access qua Root — không trực tiếp manipulate inner entities

// Order là Aggregate Root
// OrderItem là entity TRONG aggregate (không có repository riêng)
class Order {  // Aggregate Root
  private items: OrderItem[]  // Inner entity

  // External code không gọi items.push() trực tiếp
  // Phải qua Order.addItem()
}

// Aggregate boundaries = transaction boundaries
// 1 aggregate = 1 transaction
// Cross-aggregate → eventual consistency hoặc domain events

// Rule: Thiết kế aggregates nhỏ (1-4 entities)
// Large aggregates → concurrency conflicts, slow transactions
```

**Domain Events:**
```typescript
// Capture something that happened in domain
// Communicate across Bounded Contexts, trigger side effects

interface DomainEvent {
  occurredAt: Date
  aggregateId: string
  aggregateType: string
}

class OrderConfirmed implements DomainEvent {
  constructor(
    readonly orderId: OrderId,
    readonly customerId: CustomerId,
    readonly total: Money,
    readonly occurredAt = new Date(),
    readonly aggregateId = orderId.value,
    readonly aggregateType = 'Order'
  ) {}
}

// Handler (trong same context):
class OrderConfirmedHandler {
  handle(event: OrderConfirmed): void {
    emailService.sendConfirmation(event.customerId, event.orderId)
    analyticsService.track('order_confirmed', { total: event.total })
  }
}

// Published to message bus (cross-context):
// Inventory context subscribes → reserve stock
// Billing context subscribes → create invoice
```

**Repository:**
```typescript
// Abstract persistence, collection-like interface
interface OrderRepository {
  findById(id: OrderId): Promise<Order | null>
  save(order: Order): Promise<void>
  findByCustomer(customerId: CustomerId): Promise<Order[]>
}

// Implementation trong infrastructure layer:
class PostgresOrderRepository implements OrderRepository {
  async findById(id: OrderId): Promise<Order | null> {
    const row = await db.query('SELECT * FROM orders WHERE id = $1', [id.value])
    return row ? OrderMapper.toDomain(row) : null
  }
  async save(order: Order): Promise<void> {
    const data = OrderMapper.toPersistence(order)
    await db.upsert('orders', data)
    // Also publish domain events collected in order
    for (const event of order.pullDomainEvents()) {
      await eventBus.publish(event)
    }
  }
}

// Domain layer chỉ biết interface, KHÔNG biết PostgreSQL
```

**Domain Service:**
```typescript
// Logic không thuộc về 1 entity hay VO cụ thể
class PricingService {
  calculateOrderTotal(order: Order, customer: Customer, promos: Promotion[]): Money {
    const base = order.subtotal()
    const customerDiscount = customer.loyaltyDiscount()
    const promoDiscount = promos.reduce((d, p) => d.add(p.apply(order)), Money.zero())
    return base.subtract(customerDiscount).subtract(promoDiscount)
  }
}

// Không: order.calculateTotal(customer, promos) → Order không nên biết Customer/Promo
// Không: pricing logic trong service layer → không testable independently
```

### Clean Architecture — Dependency Rule

```
                    ┌──────────────────────┐
                    │   Frameworks & Drivers│
                    │  (DB, Web, UI, Devices)│
                    ├──────────────────────┤
                    │   Interface Adapters  │
                    │ (Controllers, Gateways,│
                    │    Presenters, Repos) │
                    ├──────────────────────┤
                    │   Application Business│
                    │       Rules           │
                    │    (Use Cases)        │
                    ├──────────────────────┤
                    │   Enterprise Business │
                    │       Rules           │
                    │ (Entities, Domain)    │
                    └──────────────────────┘

The Dependency Rule: Source code dependencies must point
ONLY INWARD toward higher-level policies.
Inner layers know NOTHING about outer layers.

Concrete:
  Domain entities → không import Express, không import TypeORM
  Use cases → không import Express, CAN import domain entities
  Controllers → không import domain directly (via use case interfaces)
  Repositories → implement domain interfaces, use TypeORM/Postgres
```

**Folder structure:**
```
src/
  domain/           ← Entities, Value Objects, Domain Events, Repo interfaces
    order/
      Order.ts
      OrderItem.ts
      Money.ts         (Value Object)
      OrderRepository.ts  (interface only)
      events/
        OrderConfirmed.ts

  application/      ← Use Cases, Application Services
    order/
      PlaceOrderUseCase.ts
      CancelOrderUseCase.ts
      GetOrderUseCase.ts

  infrastructure/   ← DB, HTTP, external services
    persistence/
      PostgresOrderRepository.ts  (implements domain interface)
      OrderMapper.ts
    http/
      OrderController.ts
      OrderRouter.ts
    messaging/
      KafkaEventBus.ts

  shared/           ← Cross-cutting: logging, errors, DI container
```

### Event Storming — Workshop Tool

```
Event Storming: Collaborative domain discovery workshop
  Participants: Developers + Domain Experts + Product Owners
  Duration: 4–8 hours cho complex domain
  Output: Shared understanding, bounded context map, aggregate boundaries

Steps:
  1. Domain Events (orange stickies): "Order Placed", "Payment Failed"
     → Start with events, not data or processes
  2. Commands (blue): What triggers events? "Place Order", "Process Payment"
  3. Aggregates (yellow): Which entity handles command → emits event?
  4. Policies (purple): "When X happens, then do Y" (automated reactions)
  5. Read Models (green): What views does the UI need?
  6. External Systems (pink): Stripe, Warehouse system

Output feeds directly into:
  → Bounded Context identification
  → Aggregate design
  → Domain Event naming (Ubiquitous Language)
  → Microservice boundaries (1 BC = 1 candidate service)
```

### Khi nào dùng DDD

```
✅ Phù hợp:
  - Complex domain với intricate business rules
  - Many domain experts với deep knowledge
  - Long-lived system (5+ years)
  - Large team cần clear module boundaries

❌ Không phù hợp:
  - CRUD app (data in → data out, minimal logic)
  - Short-lived project
  - Small team (2-3 devs)
  - Tech-centric problem (data pipeline, infra tool)

Lightweight DDD:
  Không cần dùng ALL building blocks
  Minimum viable DDD: Ubiquitous Language + Aggregates + Domain Events
  Add more building blocks as complexity grows
```

---

## 8. Hexagonal Architecture (Ports & Adapters)

```
Core idea: Application có "ports" (interfaces) và "adapters" (implementations)
  → Application không care về input/output mechanism
  → Same business logic, driven by HTTP OR CLI OR message queue

          ┌─────────────────────────────────┐
 HTTP →   │  ┌──────────────────────────┐   │
 CLI →    │  │   Application Core        │   │
 Tests →  │  │   (Domain + Use Cases)    │   │
          │  └──────────┬───────────────┘   │
          │             │                   │
          │  Driven ports:                  │
          │    OrderRepository (interface)  │
          │    EmailSender (interface)      │
          │    PaymentGateway (interface)   │
          └─────────────────────────────────┘
               ↑            ↑
          PostgresRepo  StripeAdapter
          (adapter)     (adapter)

Benefit: Swap adapters without touching core
  Test: InMemoryRepo (fast)
  Dev:  LocalPostgres
  Prod: RDS PostgreSQL
  Test payment: MockPaymentGateway
  Prod payment: StripeAdapter
```


## Checklist LLD

> 🔴 MUST = block ship | 🟠 SHOULD = fix trước prod | 🟡 NICE = tech debt

🔴 MUST:
- [ ] Không expose internal error details / stack traces ra ngoài client
- [ ] Parameterized queries — không string concat trong SQL
- [ ] Idempotency cho queue consumers (message có thể đến 2 lần)
- [ ] Schema migration backward compatible (không DROP + deploy đồng thời)

🟠 SHOULD:
- [ ] Dependency Injection thay vì Singleton (dễ test, dễ swap)
- [ ] Repository pattern tách data access khỏi business logic
- [ ] API error response: `code` + `message` + `details` (không raw exception)
- [ ] Idempotency key cho POST endpoints có side effects (payment, order)
- [ ] DataLoader nếu dùng GraphQL (tránh N+1)
- [ ] Pagination strategy documented (cursor vs offset, và tại sao)

🟡 NICE:
- [ ] SOLID principles — đặc biệt Open/Closed và Dependency Inversion
- [ ] Single Responsibility: mỗi class/function có 1 lý do thay đổi
- [ ] ADR (Architecture Decision Records) cho major decisions
- [ ] Domain events thay vì direct coupling giữa modules
