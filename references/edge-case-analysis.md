# Edge Case & Failure Mode Analysis

Use this file to enforce AI search for failure modes, race conditions, and boundary cases.

## 🛡️ Analysis Framework

Every architecture solution must be "stress tested" with 5 questions:
1. **Concurrency:** What happens if two requests modify the same record at the same millisecond? (Race condition)
2. **Partial Failure:** If Service A calls Service B successfully, but Service B dies just before returning the result? (Zombie state)
3. **Network:** What happens if the network is slow (latency) or disconnected (partition)?
4. **Idempotency:** What if a request is sent twice (due to a double-click or retry)?
5. **Data Integrity:** What if the database crashes in the middle of a transaction?

---

## 💣 Common Edge Cases by Domain

### 1. Payments & Transactions
- **Double Spend:** User hits the "Pay" button twice very quickly.
- **Insufficient Funds during capture:** Sufficient balance during `authorize`, but missing during `capture`.
- **Currency Fluctuation:** Exchange rate changes between checkout and actual payment.

### 2. Messaging & Events (Kafka/RabbitMQ)
- **Out of order:** Event B arrives before Event A even though A happened first.
- **Duplicate Delivery:** A message is consumed twice (At-least-once delivery).
- **Poison Pill:** A faulty message crashes the consumer, leading to an infinite retry loop.

### 3. Caching (Redis)
- **Cache Stampede (Thundering Herd):** Cache expires simultaneously, sending 1 million requests to the DB.
- **Cache Penetration:** Constant requests for non-existent keys, bypassing the cache to hit the DB.
- **Stale Data:** DB update is successful, but the cache clear/update fails.

### 4. Distributed Systems
- **Clock Skew:** Time on Server A differs from Server B, causing out-of-order logs/events.
- **Split Brain:** The cluster is partitioned, and two nodes both claim to be the Master.
- **Hot Keys:** A single record (e.g., a celebrity) receives 90% of the traffic, overloading a specific DB shard.

---

## 🛠️ Mitigation Patterns

When an Edge Case is detected, the AI must propose these patterns:
- **Idempotency Key:** Use the `X-Idempotency-Key` header for all write APIs.
- **Optimistic Locking:** Use a `version` field to prevent race conditions in the DB.
- **Circuit Breaker:** Disconnect when the target service shows signs of overload.
- **Dead Letter Queue (DLQ):** Isolate faulty messages for later processing.
- **Exponential Backoff & Jitter:** Retry with increasing and randomized wait times.

---

## 📊 Risk Matrix (FMEA Lite)

List Edge Cases in a table:
| Edge Case | Probability | Severity | Mitigation |
| :--- | :--- | :--- | :--- |
| Race condition | High | 🔴 Critical | Optimistic Locking |
| Network Timeout | Medium | 🟠 Medium | Idempotency + Retry |
| DB Crash | Low | 🔴 Critical | WAL + Replication |
| Hot Key | Medium | 🟠 Medium | Sharding + Local Cache |
