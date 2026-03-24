# Architecture Decision Records (ADR) Guide

Dùng file này để ép AI xuất ra các bản ghi quyết định kiến trúc khi thực hiện các thay đổi lớn.

## 📝 ADR Template (Bắt buộc theo cấu trúc này)

```markdown
# ADR [Số]: [Tên quyết định]

- **Date:** [YYYY-MM-DD]
- **Status:** [Proposed / Accepted / Superseded]
- **Deciders:** [User, AI Assistant]

### Context (Bối cảnh)
Mô tả vấn đề đang gặp phải. Tại sao cần đưa ra quyết định này? Các ràng buộc (constraints) là gì?

### Decision (Quyết định)
Chúng tôi sẽ chọn [Tech/Architecture]. Chi tiết về cách triển khai.

### Options Considered (Các phương án đã cân nhắc)
- **Option A:** [Lợi/Hại]
- **Option B:** [Lợi/Hại]

### Consequences (Hậu quả / Kết quả)
- **Positive:** [Ví dụ: Tăng performance, giảm cost]
- **Negative:** [Ví dụ: Team cần học thêm ngôn ngữ mới, tăng độ phức tạp]

### Compliance Check (Kiểm tra tuân thủ)
- [x] Đã kiểm tra Anti-patterns?
- [x] Đã phù hợp với Scale yêu cầu?
```

---

## 🚦 Khi nào cần viết ADR?
AI phải tự động đề xuất viết ADR khi:
1. **Chọn Database mới** (SQL vs NoSQL).
2. **Chọn ngôn ngữ/runtime** (Node vs Go vs Bun).
3. **Thay đổi cấu trúc giao tiếp** (REST vs gRPC vs GraphQL).
4. **Thay đổi chiến lược lưu trữ/cache** (Redis vs CDN).
5. **Chọn Cloud Provider / Hosting.**

---

## 🔴 CÁCH QUẢN LÝ ADR
- Lưu file vào thư mục `docs/adr/`.
- Tên file dạng: `0001-choice-of-database.md`.
- File ADR cũ bị thay thế phải cập nhật trạng thái thành **Superseded** và trỏ đến ADR mới.
