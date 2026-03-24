# Documentation & Visualization Standards (Mermaid.js)

Use this file to guide the AI in drawing system architecture diagrams using Mermaid.js.

## 📐 C4 Model (Architecture Level)

### C1: System Context (Overview)
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

## 🔄 Sequence Diagram (Data Flow)
Used to describe flows for Auth, Orders, Payments, etc.
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

## 🕸️ State Machine (Order Status/Workflow)
```mermaid
stateDiagram-v2
    [*] --> Pending
    Pending --> Processing: Payment Confirmed
    Processing --> Shipped: Pick & Pack
    Shipped --> Delivered: Carrier Update
    Pending --> Cancelled: Timeout/User Action
    Shipped --> Returned: Customer Rejection
```

## 🔴 Drawing Guidelines
- **Top-Down:** Preferred for overall architecture.
- **Left-Right:** Preferred for data flow.
- **Annotations:** Always add technology notes (e.g., `[PostgreSQL]`, `[gRPC]`) to the nodes.
- **Simplicity:** Do not exceed 15-20 nodes per diagram. If too complex, split them into smaller diagrams.
