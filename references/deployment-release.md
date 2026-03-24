# Deployment & Release Engineering

Use this file to advise on CI/CD, deployment strategies, and safe release (Zero-downtime).

## 🚀 Deployment Strategies (Infra Level)

### 1. Rolling Update (K8s Default)
Update one instance at a time.
- **Pros:** Resource-efficient.
- **Cons:** Two versions run simultaneously for a while; immediate rollback can be slow.

### 2. Blue/Green Deployment
Run two identical environments side-by-side.
- **Pros:** 1-second rollback (traffic redirection). Extremely safe.
- **Cons:** Double infrastructure cost during deployment.

### 3. Canary Release (Big Tech Standard)
Push the new version to 1-5% of users before a full rollout.
- **Pros:** Early bug detection with a small audience.
- **Cons:** Requires strong metrics and monitoring for automated rollback.

---

## 🛠 Release Patterns (Separating Deploy from Release)

### 1. Feature Flags
Code is deployed but invisible to users until the "Flag" is toggled.
- **Tools:** LaunchDarkly, Flagsmith, Unleash, or custom-built with Redis.
- **Benefit:** Allows testing on production with internal users.

### 2. Dark Launching
Send real traffic to the new backend but don't show results to the user.
- **Goal:** Stress test the new system with real-world load.

---

## 🔄 Rollback & Database Strategy
- **Backward Compatibility:** New code MUST be able to read old data.
- **Expand/Contract Pattern (Database):**
  - Step 1: Add a new column (Nullable).
  - Step 2: Deploy new code (Writes to both columns).
  - Step 3: Migrate old data to the new column.
  - Step 4: Deploy new code (Uses only the new column).
  - Step 5: Remove the old column.

---

## 🔴 Deployment Checklist
- [ ] Are **Health Checks** (Liveness/Readiness probes) configured?
- [ ] Is **Graceful Shutdown** configured (Wait 30s before killing the process)?
- [ ] Is **Automated Rollback** based on Error Rate (e.g., Error Rate > 5%) in place?
- [ ] Have **Database Migrations** been checked for potential table locks?
