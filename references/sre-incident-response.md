# SRE & Incident Management

Dùng file này để thiết kế hệ thống Giám sát (Observability) và Quy trình Ứng phó Sự cố (Incidents).

## 📊 Observability (3 trụ cột)

### 1. Metrics (Con số)
Giám sát tình trạng hệ thống qua các thông số.
- **Tools:** Prometheus + Grafana, Datadog.
- **Chỉ số RED:** Requests (Rate), Errors, Duration (Latency).

### 2. Logs (Nhật ký)
Dùng để gỡ lỗi và phân tích nguyên nhân.
- **Tools:** ELK Stack (Elasticsearch, Logstash, Kibana), Loki.
- **Structured Logging:** Ghi log dạng JSON để dễ dàng query.

### 3. Tracing (Dấu vết)
Theo dõi một request đi qua nhiều microservices.
- **Tools:** Jaeger, Tempo.
- **Tiêu chuẩn:** OpenTelemetry (Vendor-neutral).

---

## 📈 SRE Principles (Hợp đồng độ tin cậy)

### 1. SLI / SLO / SLA
- **SLI (Indicator):** Chỉ số đo lường thực tế (Ví dụ: Tỷ lệ 200 OK).
- **SLO (Objective):** Mục tiêu hướng tới (Ví dụ: 99.9% thành công).
- **SLA (Agreement):** Cam kết kinh doanh với khách hàng (Ví dụ: 99.5% - bồi thường nếu vi phạm).

### 2. Error Budget (Ngân sách lỗi)
Khoảng sai sót cho phép trong một tháng (Ví dụ: 1-99.9% = 0.1%).
- **Nếu hết ngân sách:** Dừng deploy feature mới, tập trung vào fix bug/Reliability.

---

## 🚒 Incident Response (Khi hệ thống sập)

### 1. Quy trình 4 bước
1. **Detection (Phát hiện):** Hệ thống Alerting (Slack/PagerDuty) cảnh báo.
2. **Triage (Phân loại):** Đánh giá mức độ ưu tiên (P0, P1, P2).
3. **Mitigation (Giảm nhẹ):** Rollback code ngay lập tức (Ưu tiên số 1: Giảm thiểu thiệt hại).
4. **Resolution (Giải quyết):** Sửa lỗi và đẩy code vá (Hotfix).

### 2. Post-mortem (Rút kinh nghiệm)
Viết báo cáo sau sự cố với tinh thần **"Blameless"** (Không đổ lỗi cá nhân).
- **Nội dung:** Chuyện gì đã xảy ra? Tại sao? Làm sao để không lặp lại? Bài học rút ra?

---

## 🔴 SRE Checklist
- [ ] Đã cấu hình **Alerting** (Slack/Email/Call)?
- [ ] Đã có **Dashboard** giám sát các chỉ số quan trọng (Golden Signals)?
- [ ] Có quy trình **On-call** (Ai trực ca đêm/cuối tuần)?
- [ ] Có bản ghi **Post-mortem** cho mọi sự cố P0/P1?
