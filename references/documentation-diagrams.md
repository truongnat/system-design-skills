# Documentation & Visualization Standards (Mermaid.js)

Dùng file này để hướng dẫn AI vẽ sơ đồ kiến trúc hệ thống bằng Mermaid.js.

## 📐 C4 Model (Cấp độ Architecture)

### C1: System Context (Bức tranh tổng quan)
```mermaid
graph TD
    User((User))
    System[Your System]
    ExternalSystem[External API/Service]
    
    User -- Uses --> System
    System -- Integration --> ExternalSystem
```

### C2: Container Diagram (Services & DBs)
```mermaid
graph LR
    subgraph Client
        Web[Web App - Next.js]
        Mobile[Mobile App - Flutter]
    end
    
    subgraph Server
        LB[Load Balancer]
        API[API Gateway - Hono/Bun]
        ServiceA[Service A - Go]
        ServiceB[Service B - Node.js]
    end
    
    subgraph Storage
        DB[(PostgreSQL)]
        Cache[(Redis)]
    end
    
    Web & Mobile --> LB
    LB --> API
    API --> ServiceA & ServiceB
    ServiceA --> DB
    ServiceB --> Cache
```

## 🔄 Sequence Diagram (Luồng dữ liệu)
Dùng để mô tả flow Auth, Order, Payment...
```mermaid
sequenceDiagram
    participant U as User
    participant A as Auth Service
    participant D as Database
    
    U->>A: Login Request (Credentials)
    A->>D: Find User
    D-->>A: User Data/Hashed Password
    A->>A: Validate & Generate JWT
    A-->>U: 200 OK (Token)
```

## 🕸️ State Machine (Trạng thái đơn hàng/workflow)
```mermaid
stateDiagram-v2
    [*] --> Pending
    Pending --> Processing: Payment Confirmed
    Processing --> Shipped: Pick & Pack
    Shipped --> Delivered: Carrier Update
    Pending --> Cancelled: Timeout/User Action
    Shipped --> Returned: Customer Rejection
```

## 🔴 CÁCH VẼ ĐÚNG (Guidelines)
- **Top-Down:** Ưu tiên vẽ từ trên xuống dưới cho kiến trúc.
- **Left-Right:** Ưu tiên vẽ từ trái sang phải cho data flow.
- **Annotations:** Luôn thêm chú thích về công nghệ (ví dụ: `[PostgreSQL]`, `[gRPC]`) vào các node.
- **Simplicity:** Không vẽ quá 15-20 nodes trong một sơ đồ. Nếu quá phức tạp, hãy tách nhỏ.
