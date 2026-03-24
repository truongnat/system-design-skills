# Technology Selection & Research Strategy

Use this file to evaluate, compare, and select Tech Stacks, Frameworks, and Libraries.

## 🧭 Evaluation Framework

Every new technology evaluation must pass through 4 filters:

### 1. Modernity & Momentum
- **Trend:** GitHub Stars growth, NPM/Docker downloads (check via Star-history/NPM-trends).
- **Velocity:** Commit frequency, issue closing time, date of the last stable release.
- **Ecosystem:** First-class TypeScript support, ESM, Bun/Node.js LTS, and Cloud-native compatibility.

### 2. Developer Experience (DX)
- **Documentation:** Is it readable? Does it have comprehensive "Getting Started" guides and recipes?
- **Tooling:** Strong support for CLI, DevTools, and VS Code Extensions.
- **Cold Start/Build Time:** Real-world development speed (e.g., Vite vs. Webpack, Bun vs. NPM).

### 3. Stability & Risk
- **Backing:** Supported by a major company (Vercel, Google, Meta) or a strong OSS community?
- **Maintenance:** Number of active maintainers. Is there a clear Roadmap?
- **Breaking Changes:** History of updates—does it frequently break legacy code?

### 4. Suitability
- **Learning Curve:** How long will it take for the current team to master it?
- **Cost:** Licensing (MIT/Apache vs. AGPL), Cloud resources (Memory/CPU footprint).

---

## 🏗️ Modern Stack Reference (2025-2026)

Recommended stacks for common scenarios:

### Web Frontend
- **Standard:** Next.js (App Router) + Tailwind CSS + TanStack Query.
- **High Perf:** Astro (Islands Architecture) for content-heavy sites.
- **State:** Zustand (Simple) | Jotai (Atomic).
- **Linter/Formatter:** Biome (Fast replacement for ESLint/Prettier).

### Backend / API
- **TypeScript:** Elysia.js or Hono (Ultra-lightweight, high-performance on Bun/Edge).
- **Go:** Gin or Echo (High performance, type safety).
- **Database Access:** Drizzle ORM (Type-safe, SQL-like) | Prisma (If high DX is priority).

### Infrastructure & Ops
- **Runtime:** Bun (Default for JS/TS unless legacy constraints exist).
- **Deployment:** Vercel/Fly.io (Serverless) | Hetzner + Coolify (Self-hosted/VPS).
- **CI/CD:** GitHub Actions with multi-stage Docker builds.

---

## 📊 Comparison Matrix (Trade-off Matrix)

When asked "X or Y?", provide a comparison table:
| Criterion | Option X | Option Y | Winner |
| :--- | :--- | :--- | :--- |
| **Performance** | Real-world benchmarks | Real-world benchmarks | X/Y |
| **Community** | Community size | Community size | X/Y |
| **DX** | Developer feel | Developer feel | X/Y |
| **Future-proof** | Maintainability | Maintainability | X/Y |

---

## 🔴 Tech Selection MUST-CHECK Checklist
- [ ] Check NPM Trends / GitHub Activity for the last 6 months.
- [ ] Check Bundle Size (for Frontend libraries).
- [ ] Verify TypeScript support level (Built-in types).
- [ ] Evaluate "Lock-in" risk (how easy is it to migrate?).
