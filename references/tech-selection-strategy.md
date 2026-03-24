# Technology Selection & Research Strategy

Dùng file này để đánh giá, so sánh và lựa chọn Tech Stack / Framework / Library.

## 🧭 Chiến lược đánh giá (Evaluation Framework)

Khi đánh giá một công nghệ mới, phải đi qua 4 bộ lọc:

### 1. Modernity & Momentum (Tính hiện đại)
- **Trend:** GitHub Stars growth, NPM/Docker downloads (check via Star-history/NPM-trends).
- **Velocity:** Tần suất commit, thời gian đóng issue, ngày release bản ổn định gần nhất.
- **Ecosystem:** Có hỗ trợ TypeScript (first-class), ESM, Bun/Node.js LTS, và Cloud-native không?

### 2. Developer Experience (DX)
- **Documentation:** Có dễ đọc không? Có đầy đủ "Getting Started" và "Recipes" không?
- **Tooling:** Hỗ trợ CLI, DevTools, VS Code Extensions mạnh không?
- **Cold Start/Build Time:** Tốc độ phát triển thực tế (ví dụ: Vite vs Webpack, Bun vs NPM).

### 3. Stability & Risk (Độ tin cậy)
- **Backing:** Được chống lưng bởi công ty nào (Vercel, Google, Meta) hay cộng đồng (OSS)?
- **Maintenance:** Số lượng maintainers active. Có lộ trình (Roadmap) rõ ràng không?
- **Breaking Changes:** Lịch sử update có hay làm break code cũ không?

### 4. Suitability (Sự phù hợp)
- **Learning Curve:** Team hiện tại mất bao lâu để master?
- **Cost:** License (MIT/Apache vs AGPL), Cloud resources (Memory/CPU footprint).

---

## 🏗️ Modern Stack Reference (2025-2026)

Đây là các bộ stack được khuyến nghị cho các bài toán phổ biến:

### Web Frontend
- **Standard:** Next.js (App Router) + Tailwind CSS + TanStack Query.
- **High Perf:** Astro (Islands Architecture) cho Content-heavy sites.
- **State:** Zustand (Simple) | Jotai (Atomic).
- **Linter/Formatter:** Biome (Fast replacement for ESLint/Prettier).

### Backend / API
- **TypeScript:** Elysia.js hoặc Hono (siêu nhẹ, chạy cực nhanh trên Bun/Edge).
- **Go:** Gin hoặc Echo (hiệu năng cao, type safety).
- **Database Access:** Drizzle ORM (Type-safe, SQL-like) | Prisma (nếu cần DX cao).

### Infrastructure & Ops
- **Runtime:** Bun (mặc định cho JS/TS nếu không có rào cản legacy).
- **Deployment:** Vercel/Fly.io (Serverless) | Hetzner + Coolify (Self-hosted/VPS).
- **CI/CD:** GitHub Actions với Docker multi-stage builds.

---

## 📊 Ma trận so sánh (Trade-off Matrix)

Khi user hỏi "X hay Y?", AI phải lập bảng so sánh dựa trên:
| Tiêu chí | Option X | Option Y | Winner |
| :--- | :--- | :--- | :--- |
| **Performance** | Benchmarks thực tế | Benchmarks thực tế | X/Y |
| **Community** | Community size | Community size | X/Y |
| **DX** | Cảm giác code | Cảm giác code | X/Y |
| **Future-proof** | Khả năng duy trì | Khả năng duy trì | X/Y |

---

## 🔴 MUST-CHECK Checklist khi chọn Tech
- [ ] Kiểm tra NPM Trends / GitHub Activity trong 6 tháng gần nhất.
- [ ] Kiểm tra Bundle Size (nếu là Frontend library).
- [ ] Xác nhận mức độ hỗ trợ TypeScript (Built-in types).
- [ ] Đánh giá khả năng "Lock-in" (có dễ migrate sang công cụ khác không?).
