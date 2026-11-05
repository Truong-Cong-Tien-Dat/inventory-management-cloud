# PROJECT REQUIREMENTS — INVENTORY MANAGEMENT SYSTEM

> Specification and implementation instructions for OpenCode. Version 1.0 — 2026-11-03.

## 1. Academic context and mandatory requirements

- Course: Cloud Computing (Điện toán đám mây).
- Team: 4 students.
- Assignment (verbatim): "Develop a NodeJS + PostgreSQL + Render application with three functions (e.g., adding and searching for products). Write a step-by-step guide on deploying the website to Render and connecting it to PostgreSQL."
- Selected topic: **Inventory Management System — Hệ thống quản lý kho hàng**.
- Selected frontend: **Flutter Web (Dart)**, NOT React/EJS.
- Mandatory backend: **Node.js + Express.js**.
- Mandatory persistent database: **PostgreSQL**.
- Mandatory deployment: **Render**; website must be accessible via a public HTTPS URL and work against the deployed database.
- At least three demonstrable business functions, and a detailed deployment tutorial with screenshots/placeholders for evidence.
- Build a responsive **web** application. Android build is out of scope.

## 2. Scope and priorities

### P0 — mandatory MVP

1. **Product management:** list, create, view, edit, delete products. Fields: SKU, name, category, description (optional), unit price, quantity in stock, reorder threshold, created/updated timestamps. SKU must be unique. Product deletion must be safe when inventory history exists (prefer soft deletion).
2. **Product search:** search by name or SKU; filter by category; pagination or reasonable result limits; clear empty/loading/error states.
3. **Inventory management:** record stock-in and stock-out transactions, show current quantity and transaction history. Reject stock-out when insufficient stock. All stock changes and transaction creation must be atomic database operations.

### P1 — useful polish, only after P0

- Dashboard: total active products, total units in stock, low-stock product count, latest transactions.
- Category CRUD or initial seed categories.
- Confirmation dialog for destructive actions; success/error notifications.

### Out of scope for MVP

- Payments, online orders, barcode scanners, multi-warehouse, supplier purchasing, real-time collaboration, AI, mobile app, role-based authorization, and full authentication unless explicitly requested later.
- If no authentication is implemented, explain that the public demo is an educational prototype; do not claim it is production-secure. Avoid putting sensitive real business data in the demo.

## 3. Technology stack

| Layer | Technology | Notes |
|---|---|---|
| Frontend | Flutter Web, Dart | Material 3, responsive desktop/mobile browser layout |
| API | Node.js (active LTS), Express.js | REST over HTTPS, JSON |
| Database | PostgreSQL | Hosted on Render when feasible |
| DB client | `pg` (node-postgres) | Parameterized SQL queries; transactions |
| Validation | `zod` or `express-validator` | Validate every mutation and query parameter |
| Security basics | `helmet`, configured `cors`, environment variables | No secrets in source control |
| Deployment | Render Static Site + Render Web Service + PostgreSQL | Or serve compiled Flutter Web from Express on one Web Service if simpler |
| Version control | Git/GitHub | `.gitignore`, `.env.example` |
| API testing | Postman or curl | Include repeatable smoke tests |

Do not replace the mandatory backend/database with Firebase, Supabase, SQLite, or browser-local storage.

## 4. Proposed system architecture

```text
Browser
  |
  v
Flutter Web (Render Static Site, HTTPS)
  | REST API / JSON / HTTPS
  v
Node.js + Express API (Render Web Service)
  | pg + DATABASE_URL
  v
PostgreSQL (Render database)
```

- Flutter never connects directly to PostgreSQL or receives DB credentials.
- Flutter API base URL is configured at build time using `--dart-define=API_BASE_URL=...` (or equivalent). Document local and Render values.
- Backend reads `process.env.PORT` and listens on `0.0.0.0`.
- Backend DB connection uses `DATABASE_URL`; document Render internal vs external connection strings and appropriate TLS/SSL handling per current Render guidance. Do not disable TLS verification indiscriminately.
- CORS allows only known frontend origins in deployment; allow localhost for development.

## 5. Database design (minimum schema)

### `categories`

- `id` BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY
- `name` VARCHAR(100) NOT NULL UNIQUE
- `created_at` TIMESTAMPTZ NOT NULL DEFAULT NOW()

### `products`

- `id` BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY
- `sku` VARCHAR(50) NOT NULL UNIQUE
- `name` VARCHAR(200) NOT NULL
- `category_id` BIGINT NOT NULL REFERENCES categories(id)
- `description` TEXT NULL
- `unit_price` NUMERIC(12,2) NOT NULL CHECK (unit_price >= 0)
- `quantity` INTEGER NOT NULL DEFAULT 0 CHECK (quantity >= 0)
- `reorder_level` INTEGER NOT NULL DEFAULT 5 CHECK (reorder_level >= 0)
- `is_active` BOOLEAN NOT NULL DEFAULT TRUE
- `created_at` TIMESTAMPTZ NOT NULL DEFAULT NOW()
- `updated_at` TIMESTAMPTZ NOT NULL DEFAULT NOW()

### `inventory_transactions`

- `id` BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY
- `product_id` BIGINT NOT NULL REFERENCES products(id)
- `type` VARCHAR(10) NOT NULL CHECK (type IN ('IN', 'OUT'))
- `quantity` INTEGER NOT NULL CHECK (quantity > 0)
- `note` TEXT NULL
- `created_at` TIMESTAMPTZ NOT NULL DEFAULT NOW()

**Consistency rules:**
- Stock-in/out must be the **only** normal way to change `products.quantity` after product creation; do not permit arbitrary stock edits in generic update API.
- Simplest approach: new products start with quantity 0; initial stock is added via an IN transaction.
- Implement inventory changes in one PostgreSQL transaction with row locking (`SELECT ... FOR UPDATE`) or safe conditional updates, and insert a matching history row before commit. Roll back on failure.
- For product deletion, set `is_active=false` to preserve history; exclude inactive products from normal search/list. Decide and document whether stock movement on inactive products is prohibited (recommended).
- Add indexes for category/product lookups and transaction history; include `database/schema.sql` and `database/seed.sql` with realistic demo data.
- `users` is **not** necessary for MVP; add only if authentication is later approved.

## 6. REST API contract

All routes are prefixed `/api`. Use consistent JSON responses and correct HTTP status codes. Suggested endpoints:

| Method | Path | Purpose |
|---|---|---|
| GET | `/api/health` | Service/database health check (no secrets) |
| GET | `/api/categories` | List categories |
| POST | `/api/categories` | Create category (optional P1) |
| GET | `/api/products?q=&categoryId=&page=&limit=` | List, search, filter, paginate active products |
| GET | `/api/products/:id` | Product details |
| POST | `/api/products` | Create product, initial stock 0 |
| PUT | `/api/products/:id` | Update product metadata, NOT quantity |
| DELETE | `/api/products/:id` | Soft delete product |
| POST | `/api/inventory/transactions` | Stock in/out: `{productId, type, quantity, note}` |
| GET | `/api/inventory/transactions?productId=&page=&limit=` | Transaction history |
| GET | `/api/dashboard/summary` | P1 dashboard statistics |

- Validate numeric IDs, price, quantity, SKU, required strings, pagination limits and category existence.
- Use parameterized SQL; never concatenate user input into SQL.
- Suggested response format: success `{ "data": ... }`; failure `{ "error": { "code": "...", "message": "..." } }`.
- Handle duplicate SKU (409), invalid input (400), missing product (404), insufficient stock (409), unexpected server errors (500).
- Never expose raw database errors, passwords, or stack traces in production HTTP responses.
- Provide `docs/API.md` with request/response examples.

## 7. Flutter Web UX requirements

- Material 3, clean professional inventory dashboard; Vietnamese UI text preferred.
- Responsive: desktop sidebar/navigation rail; smaller widths use drawer or compact navigation.
- Screens:
  1. Dashboard (P1).
  2. Products: searchable/filterable table or cards, product detail, add/edit forms, delete confirmation.
  3. Inventory: select product, stock IN/OUT form, transaction history.
  4. Categories: list/selector (category management optional).
- Reusable API service layer; typed Dart models; use `http` or `dio` consistently.
- Clearly show loading, success, empty, and error states; disable submit during requests.
- Forms validate inputs client-side, while server validation remains authoritative.
- Refresh data after mutations; no fake static product data in deployed screens.
- Currency/number formatting consistent; show stock and low-stock alerts.
- Do not store any DB connection secrets in Flutter.

## 8. Repository layout

```text
inventory-management/
├── frontend/                  # Flutter Web project
│   ├── lib/
│   │   ├── main.dart
│   │   ├── models/
│   │   ├── services/
│   │   ├── screens/
│   │   └── widgets/
│   └── pubspec.yaml
├── backend/
│   ├── src/
│   │   ├── app.js
│   │   ├── server.js
│   │   ├── db/
│   │   ├── routes/
│   │   ├── controllers/
│   │   └── middleware/
│   ├── package.json
│   └── .env.example
├── database/
│   ├── schema.sql
│   └── seed.sql
├── docs/
│   ├── API.md
│   ├── DEPLOY_RENDER.md
│   └── TEST_PLAN.md
├── .gitignore
└── README.md
```

Structure can be adjusted for maintainability, but keep Flutter and Node.js projects separate and documentation complete.

## 9. Render deployment guide — mandatory deliverable

Create `docs/DEPLOY_RENDER.md` with **reproducible step-by-step instructions**, including:

1. Prerequisites: Flutter SDK, Node.js LTS, GitHub repository, Render account, local PostgreSQL (or cloud dev DB).
2. Local setup: clone, install packages, create backend `.env` from `.env.example`, run schema/seed, run API, run Flutter Web, test basic workflow.
3. Push project to GitHub (never commit `.env`).
4. Create Render PostgreSQL database (choose supported plan/region, note that availability, free-tier limits, and pricing may change; check Render's current dashboard/docs).
5. Obtain and set the backend's `DATABASE_URL` securely; explain internal DB URL for services in the same Render region/network, and when external URL is used.
6. Apply SQL schema and optional seed to the hosted database safely; show actual command examples using `psql` or an approved migration command, without printing secrets.
7. Create Render Node.js Web Service from repository, set **Root Directory** to `backend`, install/build/start commands appropriate to package scripts, set `DATABASE_URL`, `NODE_ENV=production`, `FRONTEND_ORIGIN`, and optional SSL settings per current provider guidance.
8. Verify `https://<backend-host>/api/health` and test product CRUD/search/stock transactions via HTTPS.
9. Build Flutter Web with the real API URL (`flutter build web --release --dart-define=API_BASE_URL=https://<backend-host>`). Deploy compiled `build/web` as a Render Static Site using a documented reproducible build workflow (e.g., GitHub Actions to build and publish assets, or an appropriately configured Render build environment with Flutter SDK). **Do not assume Render's native Node build environment includes Flutter SDK.** Document the exact supported approach chosen.
10. Configure SPA fallback/rewrite to `index.html` if client-side routing requires it; configure CORS for final frontend origin.
11. Test from a different device/browser; refresh page; verify data persists in PostgreSQL after backend redeploy.
12. Include troubleshooting: CORS, incorrect API URL, Render port binding, missing env vars, DB TLS/connection errors, static asset paths, free-instance cold starts, database expiration/plan limits.
13. Add screenshot placeholders/checklist: PostgreSQL creation, Web Service settings, environment variables (redact values), successful API, Flutter public site, database rows, live CRUD and stock history.

Alternative allowed: build Flutter Web externally and serve `build/web` from Express, deploying a single Render Web Service. If selected, document the reproducible build/artifact flow and routing, and still ensure Node.js + PostgreSQL + Render are demonstrably used.

## 10. Security, quality and tests

- No secrets committed or embedded in frontend; `.env.example` contains placeholder values only.
- Use `helmet`, CORS allowlist, parameterized queries, centralized error handler, and request validation.
- Database connection pooling and graceful startup/shutdown.
- Add SQL constraints for nonnegative stock and prices.
- Minimum API test cases:
  - Create valid product; reject duplicate SKU.
  - Search by partial name and exact/partial SKU; filter category.
  - Edit product metadata; reject negative price.
  - Stock-in increases quantity and creates transaction.
  - Stock-out decreases quantity and creates transaction.
  - Stock-out larger than available stock fails with no stock/history change.
  - Invalid transaction quantity fails.
  - Soft-deleted product is hidden and cannot receive stock changes.
  - Two concurrent stock-out requests cannot oversell.
  - Database-backed data survives API restart/redeploy.
- Include manual UI test checklist and instructions to run automated backend tests if implemented.

## 11. Team division (4 members)

1. **Member A — Flutter UI:** navigation, responsive layout, dashboard, common components.
2. **Member B — Flutter business flows:** products forms/list/search, inventory forms/history, API integration.
3. **Member C — Backend & PostgreSQL:** schema, migrations/seed, REST API, validation, atomic inventory transactions.
4. **Member D — Cloud & QA:** Render setup, environment variables, end-to-end testing, screenshots, deployment guide, presentation materials.

Everyone participates in integration and demo rehearsal; assign actual names later.

## 12. Acceptance criteria / definition of done

- [ ] Public Flutter Web URL loads over HTTPS.
- [ ] Node.js/Express API deployed to Render and reachable over HTTPS.
- [ ] PostgreSQL stores actual records; no mock persistence in production.
- [ ] Product create/list/edit/delete (soft delete) works from the browser.
- [ ] Product search and category filter work with PostgreSQL queries.
- [ ] Stock IN/OUT updates quantity and history atomically; insufficient stock is rejected.
- [ ] Responsive UI and clear error/empty/loading states.
- [ ] No secrets in Git; environment variables configured securely.
- [ ] `README.md` provides local run instructions.
- [ ] `docs/API.md`, `docs/TEST_PLAN.md`, and `docs/DEPLOY_RENDER.md` are complete.
- [ ] Step-by-step Render tutorial includes database connection, build/deploy, troubleshooting, and screenshot checklist.
- [ ] End-to-end demo verified against public deployed environment.

## 13. Instructions for OpenCode (AI coding agent)

You are implementing the above course project. Work in stages and produce runnable, maintainable code rather than just pseudocode.

**Execution sequence:**
1. Inspect current repository and installed tools. Report assumptions, missing dependencies and proposed architecture. Do not overwrite existing files without checking.
2. Scaffold backend and PostgreSQL schema/seed; implement validation, API endpoints, transaction safety and tests.
3. Scaffold Flutter Web with models, API client, responsive screens and all P0 flows.
4. Integrate frontend with backend and test against a real PostgreSQL instance; fix failures.
5. Write deployment guide, API docs, test plan, `.env.example`, and README.
6. Prepare Render deployment configuration/scripts; deploy only when credentials/account access are available and the user approves actions involving external accounts/costs.
7. Summarize created files, commands to run, test results, unresolved issues, and next steps.

**Important constraints:**
- Preserve Flutter Web + Node.js/Express + PostgreSQL + Render; do not silently switch technologies.
- Implement the three core functions completely before P1 extras.
- Do not invent a successful deployment, screenshots, URLs, or test results. Mark steps requiring human Render/GitHub access as manual.
- Prefer simple, well-documented dependencies and clear code.
- Ask a question only if a blocking ambiguity exists; otherwise use the defaults in this spec and document assumptions.
- Do not introduce authentication, payments, or unrelated features without approval.

## 14. Suggested first prompt to OpenCode

```text
Read PROJECT_REQUIREMENTS.md completely and treat it as the project specification.
First inspect the repository and create a concise implementation plan. Then implement Phase 1: PostgreSQL schema/seed and Node.js + Express REST API for product management, search, and atomic inventory IN/OUT. Include .env.example, local setup instructions, and API tests. Do not use mock persistence. After Phase 1, summarize what works and the commands to test it; wait for my approval before implementing the Flutter Web frontend.
```
