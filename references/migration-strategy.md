# Migration & Modernization Playbook

Dùng file này để hướng dẫn AI cách nâng cấp hệ thống cũ (Monolith) sang hiện đại (Microservices/Serverless/Bun).

## 🏗️ Chiến lược di chuyển (Core Patterns)

### 1. Strangler Fig Pattern (Ưu tiên số 1)
Thay thế hệ thống cũ dần dần bằng cách bọc các feature mới trong services mới.
- **Cách làm:** Đặt một **Reverse Proxy/API Gateway** phía trước. Chuyển hướng từng endpoint từ cũ (Old) sang mới (New).
- **Lợi ích:** Rủi ro thấp, rollback dễ dàng, có thể chạy song song.

### 2. Anti-corruption Layer (ACL)
Xây dựng một layer trung gian để hệ thống mới không bị "ô nhiễm" bởi data model cũ.
- **Cách làm:** Tạo một adapter service/library để map data giữa New API và Old Legacy System.

### 3. Database Migration (Zero-downtime)
Di chuyển data mà không dừng hệ thống (Online Migration).
- **Bước 1:** Dual Write (Ghi đồng thời vào cả DB cũ và DB mới).
- **Bước 2:** Background Sync (Đồng bộ data cũ sang mới via CDC/Debezium).
- **Bước 3:** Verify Data (So sánh dữ liệu 2 bên).
- **Bước 4:** Switch Reads (Bắt đầu đọc từ DB mới).
- **Bước 5:** Switch Writes (Chỉ ghi vào DB mới, tắt dual write).

---

## 🚦 Migration Checklists

### 🔴 MUST-DO
- [ ] Phải có cơ chế **Kill Switch** (Tắt nhanh service mới nếu có lỗi).
- [ ] Phải có **Shadow Traffic** (Gửi traffic thực vào service mới để test tải nhưng không dùng kết quả).
- [ ] Phải giữ được **Data Consistency** giữa 2 hệ thống trong suốt quá trình migrate.

### 🟠 SHOULD-DO
- [ ] Chia nhỏ quá trình migrate thành các pha (Phased rollout).
- [ ] Có hệ thống **Observability** chung cho cả cũ và mới để so sánh performance.

---

## 📊 Modernization Roadmap (Lộ trình điển hình)
- **Phase 1: Containerization.** Đưa legacy app vào Docker.
- **Phase 2: Database Extraction.** Tách database riêng cho từng domain.
- **Phase 3: Service Extraction.** Tách các module nặng/quan trọng ra Microservices.
- **Phase 4: Optimization.** Chuyển sang dùng các runtime hiện đại (Bun, Go, Rust) cho các phần chịu tải cao.
