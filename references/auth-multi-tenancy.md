# SaaS Multi-tenancy & Advanced Auth

Use this file to design multi-customer SaaS (Software-as-a-Service) systems and security.

## 🏗️ Multi-tenancy Architecture (Data Isolation)

### 1. Database-per-tenant (Siloed)
Each customer has their own database.
- **Pros:** Maximum security, easy to scale individual tenants.
- **Cons:** High cost, operational overhead (deploying migrations to 1000 DBs).

### 2. Schema-per-tenant (Bridge)
Shared database, but each customer has their own Schema (Postgres/MySQL).
- **Pros:** Balance between cost and security.
- **Cons:** Hard to scale if a single tenant grows massive (DB bottleneck).

### 3. Pooled Database (Shared)
Shared database and schema, distinguished by a `tenant_id` column.
- **Pros:** Cheapest, easiest to operate.
- **Cons:** High risk of data leakage between tenants. **Row-level Security (RLS) is mandatory**.

---

## 🔐 Advanced Authentication & Authorization

### 1. Authorization (AuthZ)
- **RBAC (Role-based):** Permissions by role (Admin, Manager, User).
- **ABAC (Attribute-based):** Permissions by attribute (e.g., "Manager" in "Hanoi" can view files).

### 2. Modern Auth Patterns
- **Passkeys (FIDO2/WebAuthn):** Passwordless login using fingerprints/FaceID.
- **OIDC (OpenID Connect):** For building SSO (Single Sign-On) systems.
- **MFA (Multi-factor):** Mandatory for Admin tenants (SMS/Email/Authenticator).

---

## 💰 SaaS Operations (Tiers & Limits)

### 1. Rate Limiting (By pricing plan)
Use Redis (Fixed Window, Sliding Window, or Token Bucket).
- Example: Free plan (10 req/min), Pro plan (100 req/min).

### 2. Quotas & Usage Tracking
Track storage, user count, and API calls for billing (Usage-based billing).
- **Tools:** Stripe Billing, Lago, or OpenMeter.

---

## 🔴 SaaS Checklist
- [ ] Is Tenant Data thoroughly isolated?
- [ ] Is there a **Tenant Provisioning** mechanism (Automatic when customers sign up)?
- [ ] Are **Privacy Policy** and **Data Residency** requirements (e.g., storing data in the user's region) met?
- [ ] Is sensitive data encrypted at rest?
