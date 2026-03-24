# Deployment & Release Engineering

Dùng file này để tư vấn về CI/CD, chiến lược Deploy và Release an toàn (Zero-downtime).

## 🚀 Chiến lược Deployment (Cấp độ Infra)

### 1. Rolling Update (Mặc định K8s)
Cập nhật từng instance một.
- **Ưu:** Tiết kiệm tài nguyên.
- **Nhược:** Hai phiên bản chạy song song lâu, khó rollback tức thì.

### 2. Blue/Green Deployment
Chạy song song 2 môi trường hoàn chỉnh.
- **Ưu:** Rollback trong 1 giây (chuyển hướng Traffic). An toàn tuyệt đối.
- **Nhược:** Tốn gấp đôi chi phí hạ tầng trong lúc deploy.

### 3. Canary Release (Tiêu chuẩn Big Tech)
Đẩy version mới cho 1-5% user trước khi roll out toàn bộ.
- **Ưu:** Phát hiện lỗi sớm với số ít user.
- **Nhược:** Cần hệ thống Metrics cực mạnh để tự động rollback nếu lỗi.

---

## 🛠 Release Patterns (Tách biệt Deploy và Release)

### 1. Feature Flags (Tắt/Mở tính năng)
Code đã deploy nhưng user chưa thấy cho đến khi bật "Cờ".
- **Tools:** LaunchDarkly, Flagsmith, Unleash, hoặc tự build với Redis.
- **Lợi ích:** Có thể test trên Production với user nội bộ.

### 2. Dark Launching
Gửi traffic thực vào backend mới nhưng không hiển thị kết quả cho user.
- **Mục tiêu:** Stress test hệ thống mới với tải thực tế.

---

## 🔄 Chiến lược Rollback & Database
- **Backward Compatibility:** Code mới PHẢI đọc được dữ liệu cũ.
- **Expand/Contract Pattern (Database):**
  - Bước 1: Add cột mới (Nullable).
  - Bước 2: Deploy code mới (Ghi cả 2 cột).
  - Bước 3: Migrate dữ liệu cũ sang cột mới.
  - Bước 4: Deploy code mới (Chỉ dùng cột mới).
  - Bước 5: Xóa cột cũ.

---

## 🔴 Deployment Checklist
- [ ] Đã có **Health Check** (Liveness/Readiness probes)?
- [ ] Đã cấu hình **Graceful Shutdown** (Đợi 30s trước khi kill process)?
- [ ] Đã có **Automated Rollback** dựa trên tỷ lệ lỗi (Error Rate > 5%)?
- [ ] Đã kiểm tra **Database Migrations** có gây khóa bảng (Table Lock) không?
