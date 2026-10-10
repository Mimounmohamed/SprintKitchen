# SprintKitchen — Restaurant POS, KDS & Back-Office Ecosystem

> **Custom Client Solution**  
> **SprintKitchen** is a full-stack, multi-platform restaurant management ecosystem engineered for **Crêpe Time** (and modern fast-casual restaurant operations). Built from the ground up for a commercial client, it unifies Point of Sale (**Caisse POS**), Kitchen Display System (**KDS**), Floor Service, and Back-Office Administration (**Admin Panel**) around a centralized cloud API.

---

## 👨‍💻 Authors & Engineering Team

This project was designed, architected, and developed by:

- **Mimoun Mohamed Mahieddine** — *Full-Stack & Mobile Engineer* ([`om_mimoun@esi.dz`](mailto:om_mimoun@esi.dz))
- **Goudjil Yacine Abdelmadjid** — *Full-Stack & Mobile Engineer* ([`goudjil.yacine.abdelmadjid@gmail.com`](mailto:goudjil.yacine.abdelmadjid@gmail.com))

*Developed as a dedicated freelance solution tailored to real-world restaurant workflows, high-volume service speed, thermal printing hardware, and real-time kitchen-to-counter synchronization.*

---

## 🏗️ System Architecture

SprintKitchen is organized as a monorepo containing the backend API and four specialized frontend applications:

```text
SprintKitchen/
├── Back/                 # Node.js + Express 5 + MongoDB REST API
├── Front/
│   ├── admin/            # React 19 + Vite 8 Back-Office & Analytics Web App
│   ├── caisse/           # Flutter Point of Sale (POS) Tablet/Desktop App
│   ├── kitchen_d/        # Flutter Kitchen Display System (KDS) App
│   └── serveur_dash/     # Flutter Floor & Table Service Companion App
└── README.md             # Project Documentation
```

### End-to-End Workflow

1. **Menu & Inventory Configuration (`Front/admin`)**: The manager configures categories, products, customization groups (bases, supplements, sauces), and ingredient families. Toggling an ingredient to *Épuisé* (out of stock) automatically flags dependent products across the system.
2. **Order Taking & Live Menu Sync (`Front/caisse`)**: Cashiers take orders (*Sur Place*, *À Emporter*, *Livraison*) with deep product customization, customer lookup, and table assignment. Menu updates made in the Admin panel propagate automatically to active POS terminals without restarting the app.
3. **Real-Time Kitchen Preparation (`Front/kitchen_d`)**: Orders sent from the POS appear immediately on the KDS screen with color-coded urgency timers, modification highlights (*Ajouté*, *Modifié*, *Supprimé*), and item-by-item recipe cards. Kitchen staff advance orders from *En attente* $\rightarrow$ *En préparation* $\rightarrow$ *Prêt / Terminé*, recording exact preparation durations.
4. **Payment, Thermal Printing & Z-Report (`Front/caisse` & `Front/admin`)**: Orders are cashed out via cash or card, receipts and kitchen tickets (*Bons Cuisine*) are printed over ESC/POS network or USB thermal printers, and end-of-day *Clôture Z* reports and PDF financial summaries are generated.

---

## 📦 Modules Breakdown

### 1. Backend API (`Back/`)

Built with **Node.js**, **Express 5**, and **MongoDB / Mongoose 8**, deployed on **Microsoft Azure App Service**.

- **Authentication & RBAC**: JWT authentication (`bcryptjs` + `jsonwebtoken`) with role-based access control (`admin`, `manager`, `caissier`, `cuisinier`) and PIN/password login support.
- **Order Engine**: Automatic sequential ticket numbering (`#001`, `#002`, ...), HT/TVA/TTC calculation, percentage & fixed discounts, table occupancy locking/releasing, order modification tracking, and automatic payment refund flagging on cancellation.
- **KDS Engine**: Dedicated endpoints for kitchen queues, station filtering (`grill`, `friture`, `boissons`, `desserts`, `assemblage`, `general`), per-item readiness toggling, and preparation time tracking (`kdsSentAt` $\rightarrow$ `kdsReadyAt` / `completedAt`).
- **Inventory & Rupture Propagation**: Ingredient stock statuses (`disponible`, `stock_faible`, `epuise`) and bulk availability toggles that automatically compute product unavailability across POS and kiosk channels.
- **Financial & Kitchen Analytics**: Aggregated KPIs, hourly order distribution, revenue by order type and payment method, top-selling products, cancelled orders breakdown, and average/min/max kitchen preparation times.

### 2. Back-Office Admin Panel (`Front/admin/`)

Built with **React 19**, **Vite 8**, **React Router 7**, **Recharts**, and **Lucide Icons**.

- **Tableau de Bord (`DashboardPage.jsx`)**: Live daily snapshot of revenue (TTC/HT), total orders, kitchen queue load, stock alerts, and recent activity.
- **Historique des Commandes (`HistoriquePage.jsx`)**:
  - Multi-tab order filtering (*Toutes*, *Sur place*, *À emporter*, *Livraison*, *À encaisser*, *Payées*, *Annulées*).
  - Custom single-day and date-range calendar picker.
  - Slide-over order details drawer displaying customer info, preparation duration, itemized customizations, thermal receipt preview (*Ticket de Caisse*), kitchen ticket preview (*Bon Cuisine*), and 1-click order cancellation with reason tracking.
- **Menu & Articles (`MenuPage.jsx`)**:
  - Full CRUD for products and categories with drag-free ordering and category assignment.
  - Visual *Rupture* badges indicating which specific ingredient is out of stock on each product.
  - Instant availability toggles and price management.
- **Inventaire & Ingrédients (`InventairePage.jsx`)**:
  - Organized by customizable ingredient families (*Bases*, *Fromages*, *Viandes*, *Sauces*, *Fruits & Légumes*, *Suppléments*, etc.).
  - 1-click *Disponible / Épuisé* toggle and bulk family availability actions.
- **Statistiques & Rapports (`StatistiquesPage.jsx`)**:
  - Responsive full-width analytics suite with KPI cards, revenue & order charts, order mode distribution, payment method breakdown, top products ranking, kitchen preparation time metrics, cancelled orders audit, and full **PDF Report Export**.

### 3. Caisse POS Application (`Front/caisse/`)

Built with **Flutter** for Android tablets and Windows POS terminals.

- **Fast Order Entry (`pos_screen.dart`)**:
  - Category tabs, instant product search, and visual stock-rupture indicators.
  - Automatic background menu synchronization (detects Admin menu edits every 5s and on app resume without interrupting active carts).
- **Rich Product Customization (`customization_modal.dart`)**:
  - Multi-group selection (sweet/savory bases, sizes, meats, sauces, extras) with min/max constraints, price modifiers, ingredient removal (*Sans ...*), and per-item kitchen notes.
- **Order Modes & Customer/Table Management (`order_details_modal.dart`)**:
  - Supports *Sur place* (with table number), *À emporter*, and *Livraison* (with client name, phone, and delivery address).
- **Order History, Live Editing & Encaissement (`history_screen.dart`, `order_edit_panel.dart`, `order_details_panel.dart`)**:
  - Filter orders by status (*En cours*, *À encaisser*, *Payées*, *Annulées*) and order mode.
  - Edit live orders already sent to the kitchen — automatically generates a diff summary (*Ajouté*, *Modifié*, *Supprimé*) for the KDS.
  - Settle unpaid orders (*À encaisser*) with cash change calculation or card payment.
  - Reprint *Ticket de Caisse* or *Bon Cuisine*, or cancel orders with a reason.
- **Clôture de Caisse / Z-Report (`cloture_dialog.dart`)**:
  - End-of-shift financial summary matching the Admin stats layout, including revenue breakdown, payment methods, order types, and full itemized order list.
- **Thermal Printing (`receipt_printer_service.dart`, `printer_settings_dialog.dart`)**:
  - Dual printer configuration (Cashier Receipt Printer + Kitchen Network Printer) supporting ESC/POS over TCP/IP network sockets and USB/OS printing via `printing` & `pdf`.

### 4. Kitchen Display System — KDS (`Front/kitchen_d/`)

Built with **Flutter** for kitchen wall-mounted screens and tablets.

- **Live Kitchen Board (`kds_screen.dart`)**:
  - Real-time polling of active and completed orders for the current service day.
  - Filter tabs with live counters: *Toutes*, *En attente*, *En préparation*, and *Terminées*.
  - Color-coded urgency headers based on elapsed wait time (*Normal*, *Warning*, *Critical*, *Ready*).
  - Prominent *MODIFIÉE* banners displaying exact changes when a cashier modifies an active order.
- **Interactive Order & Recipe Modal (`kitchen_order_details_dialog.dart`)**:
  - Split-view dialog showing the full kitchen ticket on the left and the interactive item list + technical recipe sheet (ingredients, customizations, *Sans* removals, and kitchen notes) on the right.
  - Individual item readiness toggling (*Marquer Prêt* $\rightarrow$ *Article Prêt ✓*) that automatically completes the order when all items are ready.
  - Displays completion timestamp and total preparation duration (`prepDurationString`) on finished orders.
  - Direct kitchen ticket printing (*Bon Cuisine*) with preview (`kitchen_receipt_preview_dialog.dart`).

---

## 🗄️ Database Models (`Back/models/`)

| Model | File | Description |
| :--- | :--- | :--- |
| **Order** | [`Order.js`](file:///c:/Users/Mou7/Freelance/SprintKitchen/Back/models/Order.js) | Orders with `ticketNumber`, `orderType`, `status`, `kdsStatus`, `items`, `subtotalHT`, `tvaAmount`, `totalTTC`, `kdsSentAt`, `kdsReadyAt`, `completedAt`, `modificationSummary`, and cancellation metadata. |
| **Product** | [`Product.js`](file:///c:/Users/Mou7/Freelance/SprintKitchen/Back/models/Product.js) | Menu items with `name`, `categoryId`, `basePrice`, `ingredients`, `customizationGroups`, `kdsStation`, `available`, and channel flags. |
| **Category** | [`Category.js`](file:///c:/Users/Mou7/Freelance/SprintKitchen/Back/models/Category.js) | Menu categories with auto-normalized slugs, icons, colors, and `displayOrder`. |
| **Ingredient** | [`Ingredient.js`](file:///c:/Users/Mou7/Freelance/SprintKitchen/Back/models/Ingredient.js) | Raw ingredients linked to a `family` slug with `status` (`disponible`, `stock_faible`, `epuise`) and `available` boolean. |
| **IngredientFamily** | [`IngredientFamily.js`](file:///c:/Users/Mou7/Freelance/SprintKitchen/Back/models/IngredientFamily.js) | Groupings for inventory ingredients with custom labels, slugs, colors, and sort order. |
| **Payment** | [`Payment.js`](file:///c:/Users/Mou7/Freelance/SprintKitchen/Back/models/Payment.js) | Payment transactions (`especes`, `carte`, `sans_contact`, `mixte`), change given, and `isRefunded` status. |
| **Customer** | [`Customer.js`](file:///c:/Users/Mou7/Freelance/SprintKitchen/Back/models/Customer.js) | Customer directory indexed by phone number with saved delivery addresses and order stats. |
| **Table** | [`Table.js`](file:///c:/Users/Mou7/Freelance/SprintKitchen/Back/models/Table.js) | Dining room tables with capacity, zone,occupancy status, and active `currentOrderId`. |
| **Register** | [`Register.js`](file:///c:/Users/Mou7/Freelance/SprintKitchen/Back/models/Register.js) | POS register sessions (`open` / `close`), opening/closing cash amounts, and session sales counters. |
| **User** | [`User.js`](file:///c:/Users/Mou7/Freelance/SprintKitchen/Back/models/User.js) | Staff accounts with hashed passwords, PIN codes, and role permissions. |

---

## 🔌 REST API Endpoints (`Back/routes/`)

| Base Route | Key Endpoints | Description |
| :--- | :--- | :--- |
| `/api/auth` | `POST /login`, `POST /register`, `GET /me` | Staff authentication & session verification |
| `/api/orders` | `GET /`, `GET /summary`, `POST /`, `PUT /:id`, `PATCH /:id/status`, `PATCH /:id/cancel` | Full order lifecycle, live edits, status transitions & cancellations |
| `/api/kds` | `GET /orders`, `PATCH /orders/:id/kds-status`, `PATCH /orders/:orderId/items/:itemId/kds-status` | Real-time KDS queue and per-item kitchen status updates |
| `/api/products` | `GET /`, `POST /`, `PUT /:id`, `PATCH /:id/availability`, `DELETE /:id` | Product catalog & availability management |
| `/api/categories` | `GET /`, `POST /`, `PUT /:id`, `DELETE /:id` | Menu category management |
| `/api/ingredients` | `GET /`, `POST /`, `PUT /:id`, `PATCH /:id/availability`, `PATCH /bulk-availability` | Ingredient inventory & rupture toggles |
| `/api/ingredient-families` | `GET /`, `POST /`, `PUT /:id`, `DELETE /:id` | Ingredient family management |
| `/api/payments` | `POST /`, `GET /`, `GET /order/:orderId`, `POST /:id/refund` | Order payment recording & refunds |
| `/api/stats` | `GET /summary`, `GET /orders-by-hour`, `GET /top-products`, `GET /by-order-type`, `GET /by-payment-method`, `GET /cloture` | Comprehensive analytics, kitchen prep duration stats & Z-report data |
| `/api/dashboard` | `GET /` | Real-time daily overview for the Admin dashboard |
| `/api/customers` | `GET /search`, `POST /`, `PUT /:id` | Customer lookup and delivery profile management |
| `/api/tables` | `GET /`, `POST /`, `PATCH /:id/status` | Restaurant table status management |

---

## 🚀 Getting Started

### Prerequisites

- **Node.js** $\ge 18$ and **npm**
- **MongoDB** (local instance or MongoDB Atlas URI)
- **Flutter SDK** $\ge 3.10$ (for `caisse`, `kitchen_d`, and `serveur_dash`)

### 1. Run the Backend (`Back/`)

```bash
cd Back
npm install
# Configure your .env file with MONGO_URI, JWT_SECRET, and PORT=5000
npm run dev
```

### 2. Run the Admin Web Panel (`Front/admin/`)

```bash
cd Front/admin
npm install
npm run dev
```

Build for production:

```bash
npm run build
```

### 3. Run the Caisse POS App (`Front/caisse/`)

```bash
cd Front/caisse
flutter pub get
flutter run
```

### 4. Run the Kitchen Display App (`Front/kitchen_d/`)

```bash
cd Front/kitchen_d
flutter pub get
flutter run
```

---

## 📄 License & Credits

Proprietary client project developed by **Mimoun Mohamed Mahieddine** & **Goudjil Yacine Abdelmadjid**. All rights reserved.
