# SaaS Multi-tenancy & Advanced Auth

Dùng file này để thiết kế hệ thống SaaS (Software-as-a-Service) đa khách hàng và Bảo mật.

## 🏗️ Kiến trúc Multi-tenancy (Cô lập dữ liệu)

### 1. Database-per-tenant (Siloed)
Mỗi khách hàng một DB riêng.
- **Ưu:** Bảo mật tuyệt đối, dễ scale riêng từng tenant.
- **Nhược:** Chi phí cao, khó vận hành (deploy migration cho 1000 DB).

### 2. Schema-per-tenant (Bridge)
Dùng chung 1 DB nhưng mỗi khách hàng 1 Schema riêng (Postgres/MySQL).
- **Ưu:** Cân bằng giữa chi phí và bảo mật.
- **Nhược:** Khó scale nếu một tenant cực lớn (DB bottleneck).

### 3. Pooled Database (Shared)
Dùng chung DB và Schema, phân biệt bằng cột `tenant_id`.
- **Ưu:** Rẻ nhất, vận hành dễ nhất.
- **Nhược:** Rủi ro lộ dữ liệu giữa các tenant cao. **Bắt buộc dùng RLS (Row-level Security)**.

---

## 🔐 Advanced Authentication & Authorization

### 1. Phân quyền (AuthZ)
- **RBAC (Role-based):** Phân quyền theo vai trò (Admin, Manager, User).
- **ABAC (Attribute-based):** Phân quyền theo thuộc tính (Ví dụ: "Manager" ở "Hà Nội" mới được xem file).

### 2. Modern Auth Patterns
- **Passkeys (FIDO2/WebAuthn):** Đăng nhập không mật khẩu bằng vân tay/FaceID.
- **OIDC (OpenID Connect):** Dùng để build hệ thống SSO (Single Sign-On).
- **MFA (Multi-factor):** Bắt buộc cho Admin tenants (SMS/Email/Authenticator).

---

## 💰 SaaS Operations (Tiers & Limits)

### 1. Rate Limiting (Giới hạn theo gói cước)
Dùng Redis (Fixed Window, Sliding Window, hoặc Token Bucket).
- Ví dụ: Gói Free (10 req/min), Pro (100 req/min).

### 2. Quotas & Usage Tracking
Theo dõi dung lượng lưu trữ, số lượng user, số lượng API calls để tính tiền (Usage-based billing).
- **Tool:** Stripe Billing, Lago, hoặc OpenMeter.

---

## 🔴 SaaS Checklist
- [ ] Dữ liệu Tenant đã được cô lập (Isolating) triệt để chưa?
- [ ] Có cơ chế **Tenant Provisioning** (Tạo tự động khi khách hàng đăng ký) không?
- [ ] Có **Privacy Policy** và **Data Residency** (Lưu data tại khu vực của user)?
- [ ] Đã mã hóa dữ liệu nhạy cảm (Encryption-at-rest)?
