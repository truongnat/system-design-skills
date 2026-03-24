# Edge Case & Failure Mode Analysis

Dùng file này để ép AI tìm kiếm các kịch bản lỗi, tranh chấp dữ liệu và các trường hợp biên.

## 🛡️ Khung phân tích (Analysis Framework)

Mọi giải pháp kiến trúc phải được "stress test" qua 5 câu hỏi:
1. **Concurrency:** Điều gì xảy ra nếu 2 request cùng sửa 1 dữ liệu tại cùng 1 mili giây? (Race condition)
2. **Partial Failure:** Nếu Service A gọi Service B thành công nhưng Service B chết ngay trước khi trả về kết quả? (Zombie state)
3. **Network:** Điều gì xảy ra nếu mạng bị chậm (latency) hoặc đứt (partition)?
4. **Idempotency:** Nếu một request được gửi đi 2 lần (do user click 2 lần hoặc retry)?
5. **Data Integrity:** Nếu DB bị crash giữa chừng khi đang chạy transaction?

---

## 💣 Common Edge Cases by Domain

### 1. Payments & Transactions
- **Double Spend:** User nhấn "Thanh toán" 2 lần thật nhanh.
- **Insufficient Funds during capture:** Số dư đủ khi `authorize` nhưng thiếu khi `capture`.
- **Currency Fluctuation:** Tỷ giá thay đổi ngay giữa lúc checkout và payment.

### 2. Messaging & Events (Kafka/RabbitMQ)
- **Out of order:** Event B đến trước Event A dù A xảy ra trước.
- **Duplicate Delivery:** Một message được consume 2 lần (At-least-once delivery).
- **Poison Pill:** Một message bị lỗi làm crash toàn bộ consumer, gây ra lặp lại vô tận.

### 3. Caching (Redis)
- **Cache Stampede (Thundering Herd):** Cache hết hạn đồng thời, 1 triệu request cùng đổ vào DB.
- **Cache Penetration:** Request liên tục vào các key không tồn tại, xuyên qua cache vào DB.
- **Stale Data:** Update DB thành công nhưng xóa/update cache thất bại.

### 4. Distributed Systems
- **Clock Skew:** Thời gian trên Server A khác Server B, làm sai lệch thứ tự log/event.
- **Brain Split:** Cluster bị chia cắt, 2 node đều tự nhận là Master.
- **Hot Keys:** Một bản ghi (ví dụ: KOL) nhận 90% lượng traffic, làm quá tải 1 phân vùng DB.

---

## 🛠️ Kỹ thuật xử lý (Mitigation Patterns)

Khi phát hiện Edge Case, AI phải đề xuất ngay các pattern:
- **Idempotency Key:** Dùng Header `X-Idempotency-Key` cho mọi API ghi dữ liệu.
- **Optimistic Locking:** Dùng `version` field để chống race condition trong DB.
- **Circuit Breaker:** Ngắt kết nối khi service đích có dấu hiệu quá tải.
- **Dead Letter Queue (DLQ):** Cách ly các message lỗi để xử lý sau.
- **Exponential Backoff & Jitter:** Retry với thời gian chờ tăng dần và ngẫu nhiên.

---

## 📊 Ma trận rủi ro (FMEA Lite)

AI phải liệt kê Edge Cases dưới dạng bảng:
| Edge Case | Khả năng xảy ra | Mức độ nghiêm trọng | Cách xử lý (Mitigation) |
| :--- | :--- | :--- | :--- |
| Race condition | Cao | 🔴 Nghiêm trọng | Optimistic Locking |
| Network Timeout | Trung bình | 🟠 Trung bình | Idempotency + Retry |
| DB Crash | Thấp | 🔴 Cực cao | WAL + Replication |
| Hot Key | Trung bình | 🟠 Trung bình | Sharding + Local Cache |
