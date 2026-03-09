# Food Desk — Wireframe & Navigation Diagrams

This document provides wireframe-style diagrams and navigation flows for the Food Desk mobile app. Use a Mermaid-compatible viewer (e.g. VS Code with “Mermaid” extension, GitHub, or [mermaid.live](https://mermaid.live)) to render the diagrams.

---

## 1. High-Level App Flow

```mermaid
flowchart TB
    subgraph entry[" "]
        A[Splash Screen]
    end
    subgraph auth["Pre-Auth"]
        B[Login / Register]
        C[Forgot Password]
    end
    subgraph roles["Post-Login by Role"]
        D[Customer Dashboard]
        E[Supplier Dashboard]
        F[Admin Dashboard]
    end

    A -->|"~1.5s"| B
    B -->|Login success| D
    B -->|Login success| E
    B -->|Login success| F
    B -->|Forgot password link| C
    C --> B
    D -->|Logout| B
    E -->|Logout| B
    F -->|Logout| B
```

---

## 2. Full Application Sitemap (All Screens)

```mermaid
flowchart TB
    subgraph pre["Pre-Authentication"]
        SPLASH[Splash]
        LOGIN[Login / Register]
        FORGOT[Forgot Password]
    end

    subgraph customer["Customer"]
        C_DASH[Customer Dashboard]
        C_ORDER_HIST[Order History]
        C_ORDER_DET[Order Details]
        C_PLACE[Place Order]
        C_POOL[Food Pool]
    end

    subgraph supplier["Supplier"]
        SUP_DASH[Supplier Dashboard]
        SUP_PROD[My Products]
        SUP_ADD_EDIT[Add / Edit Meal]
        SUP_OB[Order Before]
        SUP_ORD[My Orders]
        SUP_LATE[Late Orders]
        SUP_SUM[Order Summary]
    end

    subgraph admin["Admin"]
        ADM_DASH[Admin Dashboard]
        ADM_PEND[Pending Registrations]
        ADM_APPR[Approved Registrations]
        ADM_SETT[Admin Settings]
        ADM_PROD[View All Products]
        ADM_ORD[View All Orders]
    end

    LOGIN --> C_DASH
    LOGIN --> SUP_DASH
    LOGIN --> ADM_DASH
    FORGOT --> LOGIN

    C_DASH --> C_ORDER_HIST
    C_DASH --> C_PLACE
    C_DASH --> C_POOL
    C_ORDER_HIST --> C_ORDER_DET
    C_PLACE --> C_DASH
    C_POOL --> C_DASH
    C_ORDER_DET --> C_ORDER_HIST

    SUP_DASH --> SUP_PROD
    SUP_DASH --> SUP_OB
    SUP_DASH --> SUP_ORD
    SUP_DASH --> SUP_LATE
    SUP_DASH --> SUP_SUM
    SUP_PROD --> SUP_ADD_EDIT
    SUP_ADD_EDIT --> SUP_PROD
    SUP_OB --> SUP_DASH
    SUP_ORD --> SUP_DASH
    SUP_LATE --> SUP_DASH
    SUP_SUM --> SUP_DASH

    ADM_DASH --> ADM_PEND
    ADM_DASH --> ADM_APPR
    ADM_DASH --> ADM_SETT
    ADM_DASH --> ADM_PROD
    ADM_DASH --> ADM_ORD
    ADM_SETT --> ADM_APPR
    ADM_PEND --> ADM_DASH
    ADM_APPR --> ADM_SETT
    ADM_PROD --> ADM_DASH
    ADM_ORD --> ADM_DASH
```

---

## 3. Customer Flow (Wireframe Navigation)

```mermaid
flowchart LR
    subgraph customer_screens["Customer Screens"]
        direction TB
        DASH["🖥️ Customer Dashboard<br/>─────────────<br/>Welcome<br/>[Order History] [Place Order] [Food Pool]"]
        HIST["📋 Order History<br/>─────────────<br/>List: date, meal, type, status"]
        DET["📄 Order Details<br/>─────────────<br/>Back | Move to Pool | Cancel | Complete"]
        PLACE["🛒 Place Order<br/>─────────────<br/>Meal type, Date, Product, Qty"]
        POOL["📦 Food Pool<br/>─────────────<br/>Pool items · Allocate"]
    end

    DASH --> HIST
    DASH --> PLACE
    DASH --> POOL
    HIST --> DET
    DET --> HIST
    PLACE --> DASH
    POOL --> DASH
```

---

## 4. Supplier Flow (Wireframe Navigation)

```mermaid
flowchart LR
    subgraph supplier_screens["Supplier Screens"]
        direction TB
        SD["🖥️ Supplier Dashboard<br/>─────────────<br/>Stats | My Products | Order Before | My Orders | Late Orders | Order Summary"]
        MP["📦 My Products<br/>─────────────<br/>List + FAB Add Meal"]
        AE["✏️ Add / Edit Meal<br/>─────────────<br/>Name, types, price, stock, image"]
        OB["⏰ Order Before<br/>─────────────<br/>Breakfast | Lunch | Dinner hour"]
        MO["📋 My Orders<br/>─────────────<br/>List · Cancel pending"]
        LO["⚠️ Late Orders<br/>─────────────<br/>Approve | Reject"]
        OS["📊 Order Summary<br/>─────────────<br/>Period filter · Stats"]
    end

    SD --> MP
    SD --> OB
    SD --> MO
    SD --> LO
    SD --> OS
    MP --> AE
    AE --> MP
    OB --> SD
    MO --> SD
    LO --> SD
    OS --> SD
```

---

## 5. Admin Flow (Wireframe Navigation)

```mermaid
flowchart LR
    subgraph admin_screens["Admin Screens"]
        direction TB
        AD["🖥️ Admin Dashboard<br/>─────────────<br/>Total Users | Pending Reg | Orders | Cost | Quick Access"]
        PR["📝 Pending Registrations<br/>─────────────<br/>List · Approve / Reject"]
        AR["✅ Approved Registrations<br/>─────────────<br/>List · Activate / Deactivate"]
        SET["⚙️ Admin Settings<br/>─────────────<br/>User Mgmt | Meal Display | Meal Limits"]
        VP["📦 View All Products<br/>─────────────<br/>Read-only list"]
        VO["📋 View All Orders<br/>─────────────<br/>Read-only · Date filter"]
    end

    AD --> PR
    AD --> SET
    AD --> VP
    AD --> VO
    SET --> AR
    PR --> AD
    AR --> SET
    VP --> AD
    VO --> AD
```

---

## 6. Screen Wireframe Sketches (Layout)

### 6.1 Login / Register

```mermaid
block-beta
    columns 1
    block:header["App Bar: FoodDesk"]
    block:body["Body
    ─────────────
    [Login] [Register] toggle
    ─────────────
    Email: [____________]
    Password: [____________]
    Name: [____________]  (Register only)
    Role: [Customer ▼]    (Register only)
    ─────────────
    [    Login / Register    ]
    ─────────────
    Forgot password?
    Don't have account? Register"]
```

### 6.2 Customer Dashboard

```mermaid
block-beta
    columns 1
    block:appbar["App Bar: Dashboard | [History] [Logout]"]
    block:welc["Welcome, [Name]! | Choose an option below"]
    block:tiles["Card: Order History | View past and current orders"]
    block:tiles2["Card: Place Order | Browse and place new order"]
    block:tiles3["Card: Food Pool | X items in pool"]
```

### 6.3 Place Order Screen (Simplified)

```mermaid
block-beta
    columns 1
    block:bar["App Bar: Place Order"]
    block:meal["Meal type: [Breakfast ▼] [Lunch] [Dinner]"]
    block:date["Delivery date: [Date picker]"]
    block:countdown["Order before: HH:MM (countdown)"]
    block:prod["Product list | [Product 1] [Product 2] ..."]
    block:qty["Quantity: [ - ] 1 [ + ]"]
    block:btn["[ Place Order ]"]
```

### 6.4 Order History → Order Details

```mermaid
flowchart TB
    subgraph list["Order History List"]
        L1["Card: Meal A · Date · Pending"]
        L2["Card: Meal B · Date · Completed"]
        L3["Card: Meal C · Date · Cancelled"]
    end

    subgraph detail["Order Details (on tap)"]
        D["Product name, type, qty, dates
        Status
        ─────────────
        [Back]
        [Move to Pool] or [Cancel Order]
        [Complete]
        [Move back to Pending] (if Completed & date ok)"]
    end

    L1 --> D
    L2 --> D
    L3 --> D
```

### 6.5 Supplier Dashboard Tiles

```mermaid
block-beta
    columns 2
    block:s1["My Products: N"]
    block:s2["My Orders: N"]
    block:s3["Total Stock: N"]
    block:s4["Revenue: Rs.X"]
    block:menu["Quick Access: My Products | Order Before | My Orders | Late Orders | Order Summary"]
```

### 6.6 Admin Dashboard Tiles

```mermaid
block-beta
    columns 2
    block:a1["Total Users: N"]
    block:a2["Pending Reg: N"]
    block:a3["Total Orders: N"]
    block:a4["Total Cost: Rs.X"]
    block:amenu["Order food | Pending Reg | Approved Reg | Settings | All Products | All Orders"]
```

---

## 7. Key User Journey: Customer Places Order

```mermaid
sequenceDiagram
    participant U as Customer
    participant D as Dashboard
    participant P as Place Order
    participant F as Firestore

    U->>D: Login → Dashboard
    U->>D: Tap Place Order
    D->>P: Open Place Order
    U->>P: Select meal type, date, product, qty
    P->>F: Check Order Before / stock
    alt Normal order
        U->>P: Tap Place Order
        P->>F: Create order (Pending)
    else Late reservation
        U->>P: Tap Submit (today, past deadline)
        P->>F: Create order (LateOrderPending)
    end
    P->>D: Back to Dashboard
```

---

## 8. Key User Journey: Supplier Handles Late Order

```mermaid
sequenceDiagram
    participant S as Supplier
    participant D as Dashboard
    participant L as Late Orders
    participant F as Firestore

    S->>D: Login → Dashboard
    S->>D: Tap Late Orders
    D->>L: Open Late Orders list
    L->>F: Stream orders (LateOrderPending, today)
    F->>L: Show list
    S->>L: Tap Approve or Reject
    alt Approve
        L->>F: Decrement stock, status → Pending
    else Reject
        L->>F: status → Rejected, optional comment
    end
```

---

## How to View / Export

- **VS Code / Cursor:** Install “Mermaid” or “Markdown Preview Mermaid Support” and open this file in preview (e.g. `Ctrl+Shift+V`).
- **GitHub:** Push the repo and view this file; Mermaid renders in the preview.
- **Online:** Copy a code block into [mermaid.live](https://mermaid.live) to view, edit, or export as PNG/SVG/PDF. Best for `block-beta` diagrams if your viewer doesn’t support them.
- **PDF:** Use “Markdown PDF” on this file, or export diagrams from mermaid.live and add to a document.

---

*Food Desk Wireframe & Navigation — February 2025*
