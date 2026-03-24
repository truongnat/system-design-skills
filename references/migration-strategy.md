# Migration & Modernization Playbook

Use this file to guide the AI on how to upgrade legacy systems (Monolith) to modern ones (Microservices/Serverless/Bun).

## 🏗️ Core Migration Patterns

### 1. Strangler Fig Pattern (Priority #1)
Replace legacy features gradually by wrapping them in new services.
- **Method:** Place a Reverse Proxy/API Gateway in front. Route individual endpoints from Old to New.
- **Benefits:** Low risk, easy rollback, can run in parallel.

### 2. Anti-corruption Layer (ACL)
Build an intermediary layer so the new system isn't "polluted" by legacy data models.
- **Method:** Create an adapter service/library to map data between the New API and the Legacy System.

### 3. Zero-downtime Database Migration
Migrate data without stopping the system (Online Migration).
- **Step 1:** Dual Write (Write to both old and new DBs simultaneously).
- **Step 2:** Background Sync (Synchronize legacy data via CDC/Debezium).
- **Step 3:** Verify Data (Compare data on both sides).
- **Step 4:** Switch Reads (Start reading from the new DB).
- **Step 5:** Switch Writes (Only write to the new DB, turn off dual write).

---

## 🚦 Migration Checklists

### 🔴 MUST-DO
- [ ] Must have a **Kill Switch** (Quickly disable the new service if errors occur).
- [ ] Must use **Shadow Traffic** (Send real traffic to the new service for load testing without using the results).
- [ ] Must maintain **Data Consistency** between both systems during the migration.

### 🟠 SHOULD-DO
- [ ] Break the migration into phases (Phased rollout).
- [ ] Implement shared **Observability** for both legacy and new systems to compare performance.

---

## 📊 Modernization Roadmap
- **Phase 1: Containerization.** Wrap the legacy app in Docker.
- **Phase 2: Database Extraction.** Separate databases per domain.
- **Phase 3: Service Extraction.** Separate heavy/critical modules into Microservices.
- **Phase 4: Optimization.** Switch to modern runtimes (Bun, Go, Rust) for high-load components.
