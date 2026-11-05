# Inventory Management REST API

Phase 3 backend contract for the Flutter Web client and integration tests.

## 1. Base URL and conventions

| Environment | Base URL |
|---|---|
| Local | `http://localhost:3000` |
| Render | `https://<service-name>.onrender.com` |

- API prefix: `/api`
- Request/response content type: `application/json; charset=utf-8`
- Success envelope: `{ "data": ... }`, optionally with `{ "meta": ... }`
- Error envelope:

```json
{
  "error": {
    "code": "VALIDATION_ERROR",
    "message": "Request validation failed",
    "details": [
      {
        "field": "unitPrice",
        "message": "unitPrice must be greater than or equal to 0"
      }
    ]
  }
}
```

- Dates are ISO-8601 UTC strings, for example `2026-11-03T08:15:30.000Z`.
- IDs are JSON numbers in this demo. The database uses `BIGINT`; values above
  `Number.MAX_SAFE_INTEGER` are rejected by validation.
- Money is returned as a JSON number rounded to two decimals. The database column is
  `NUMERIC(12,2)`.
- All SQL uses parameter placeholders. Dynamic sort columns are selected from a fixed
  allowlist.

## 2. Status and error codes

| HTTP | Code | Meaning |
|---|---|---|
| 200 | — | Successful read, update, or soft delete |
| 201 | — | Product, category, or transaction created |
| 400 | `VALIDATION_ERROR` | Invalid body, query, or path parameter |
| 400 | `CATEGORY_NOT_FOUND` | Referenced category does not exist |
| 400 | `FIELD_NOT_EDITABLE` | `quantity` or `isActive` sent to product create/update |
| 403 | `CORS_ORIGIN_DENIED` | Browser origin is not allowed |
| 404 | `PRODUCT_NOT_FOUND` | Product is missing or inactive |
| 404 | `ROUTE_NOT_FOUND` | Unknown API route |
| 409 | `DUPLICATE_SKU` | SKU already exists (case-insensitive) |
| 409 | `CATEGORY_EXISTS` | Category name already exists (case-insensitive) |
| 409 | `INSUFFICIENT_STOCK` | Stock-out exceeds available quantity |
| 409 | `PRODUCT_INACTIVE` | Stock movement attempted on a soft-deleted product |
| 413 | `PAYLOAD_TOO_LARGE` | JSON body exceeds the configured limit |
| 500 | `INTERNAL_ERROR` | Unexpected server error; stack traces are not exposed |
| 503 | `DB_UNAVAILABLE` | Database connection or query unavailable |

Validation errors include a `details` array. Unknown fields are rejected by the strict
schemas.

## 3. Health

### GET `/api/health`

Runs a lightweight `SELECT 1` against PostgreSQL with a short timeout.

```bash
curl -s http://localhost:3000/api/health
```

```json
{
  "data": {
    "status": "ok",
    "database": "up",
    "uptimeSeconds": 123,
    "timestamp": "2026-11-03T08:15:30.000Z"
  }
}
```

When the database is unavailable:

```json
{
  "error": {
    "code": "DB_UNAVAILABLE",
    "message": "Database is unavailable"
  }
}
```

HTTP status is `503`. Connection strings and credentials are never returned.

## 4. Categories

### GET `/api/categories`

Returns all categories with the count of **active** products.

```bash
curl -s http://localhost:3000/api/categories
```

```json
{
  "data": [
    {
      "id": 1,
      "name": "Thiết bị điện tử",
      "productCount": 5,
      "createdAt": "2026-11-03T08:00:00.000Z"
    }
  ]
}
```

### POST `/api/categories`

Request:

```json
{
  "name": "Thiết bị điện tử"
}
```

```bash
curl -s -X POST http://localhost:3000/api/categories \
  -H 'Content-Type: application/json' \
  -d '{"name":"Thiết bị điện tử"}'
```

Success: `201 Created`, `Location: /api/categories/:id`.

```json
{
  "data": {
    "id": 6,
    "name": "Thiết bị điện tử",
    "productCount": 0,
    "createdAt": "2026-11-03T08:15:30.000Z"
  }
}
```

- Blank or longer than 100 characters: `400 VALIDATION_ERROR`.
- Duplicate name in any letter case: `409 CATEGORY_EXISTS`.

## 5. Products

### Product object

```json
{
  "id": 3,
  "sku": "ELEC-003",
  "name": "Bàn phím cơ",
  "categoryId": 1,
  "categoryName": "Thiết bị điện tử",
  "description": "Bàn phím cơ 87 phím",
  "unitPrice": 1290000,
  "quantity": 24,
  "reorderLevel": 5,
  "stockStatus": "IN_STOCK",
  "isActive": true,
  "createdAt": "2026-11-03T08:00:00.000Z",
  "updatedAt": "2026-11-03T08:00:00.000Z"
}
```

`stockStatus` is computed by the API:

- `OUT_OF_STOCK`: `quantity === 0`
- `LOW_STOCK`: `quantity > 0 && quantity <= reorderLevel`
- `IN_STOCK`: otherwise

### GET `/api/products`

Query parameters:

| Parameter | Rules |
|---|---|
| `q` | Optional, trimmed, max 100 characters; partial case-insensitive match on name or SKU |
| `categoryId` | Optional positive integer |
| `page` | Integer >= 1, default `1` |
| `limit` | Integer 1–100, default `20` |
| `sort` | `createdAt`, `updatedAt`, `name`, `sku`, `unitPrice`, or `quantity`; default `createdAt` |
| `order` | `asc` or `desc`; default `desc` |

Inactive products are excluded by default. `meta` echoes the applied `sort` and `order`.

```bash
curl -s 'http://localhost:3000/api/products?q=ban&categoryId=1&page=1&limit=20&sort=name&order=asc'
```

```json
{
  "data": [
    {
      "id": 3,
      "sku": "ELEC-003",
      "name": "Bàn phím cơ",
      "categoryId": 1,
      "categoryName": "Thiết bị điện tử",
      "description": "Bàn phím cơ 87 phím",
      "unitPrice": 1290000,
      "quantity": 24,
      "reorderLevel": 5,
      "stockStatus": "IN_STOCK",
      "isActive": true,
      "createdAt": "2026-11-03T08:00:00.000Z",
      "updatedAt": "2026-11-03T08:00:00.000Z"
    }
  ],
  "meta": {
    "page": 1,
    "limit": 20,
    "total": 1,
    "totalPages": 1,
    "hasNext": false,
    "hasPrev": false,
    "sort": "name",
    "order": "asc"
  }
}
```

Invalid query parameters return `400 VALIDATION_ERROR`. Unknown query parameters are rejected.

### GET `/api/products/:id`

```bash
curl -s http://localhost:3000/api/products/3
```

- `200` with `{ "data": { ...product } }`.
- `404 PRODUCT_NOT_FOUND` if missing or inactive.
- `400 VALIDATION_ERROR` if the ID is not a positive integer.

### POST `/api/products`

New products always start with `quantity = 0`.

```json
{
  "sku": "ELEC-010",
  "name": "Màn hình 27 inch",
  "categoryId": 1,
  "description": "Màn hình IPS 2K",
  "unitPrice": 4500000,
  "reorderLevel": 3
}
```

```bash
curl -s -X POST http://localhost:3000/api/products \
  -H 'Content-Type: application/json' \
  -d '{
    "sku": "ELEC-010",
    "name": "Màn hình 27 inch",
    "categoryId": 1,
    "description": "Màn hình IPS 2K",
    "unitPrice": 4500000,
    "reorderLevel": 3
  }'
```

- SKU is trimmed and normalized to uppercase.
- `quantity` and `isActive` are rejected with `400 FIELD_NOT_EDITABLE`; stock changes
  must use the inventory endpoints.
- Success: `201 Created` and `Location: /api/products/:id`.
- Invalid fields: `400 VALIDATION_ERROR`.
- Missing category: `400 CATEGORY_NOT_FOUND`.
- Case-insensitive SKU conflict: `409 DUPLICATE_SKU`.

Validation highlights:

- `sku`: 1–50 characters, `^[A-Z0-9][A-Z0-9._-]*$` after trimming/uppercasing.
- `name`: 1–200 characters after trimming.
- `description`: optional, max 2000 characters; blank string becomes `null`.
- `unitPrice`: 0 to 9,999,999,999.99, at most two decimal places.
- `reorderLevel`: integer 0–1,000,000; default `5` on create.

### PUT `/api/products/:id`

This is a full metadata update. Send all metadata fields. Stock quantity and active state
cannot be changed here.

```json
{
  "sku": "ELEC-010",
  "name": "Màn hình 27 inch 2K",
  "categoryId": 1,
  "description": "Màn hình IPS 2K, 100Hz",
  "unitPrice": 4690000,
  "reorderLevel": 4
}
```

```bash
curl -s -X PUT http://localhost:3000/api/products/10 \
  -H 'Content-Type: application/json' \
  -d '{
    "sku": "ELEC-010",
    "name": "Màn hình 27 inch 2K",
    "categoryId": 1,
    "description": "Màn hình IPS 2K, 100Hz",
    "unitPrice": 4690000,
    "reorderLevel": 4
  }'
```

- `200` with the updated product.
- `404 PRODUCT_NOT_FOUND` if missing or inactive.
- `409 DUPLICATE_SKU` if the SKU belongs to another product.
- `400 FIELD_NOT_EDITABLE` when `quantity`, `isActive`, or `is_active` is present.
- `400 CATEGORY_NOT_FOUND` when `categoryId` does not exist.

### DELETE `/api/products/:id`

Soft delete only. Transaction history is preserved.

```bash
curl -s -X DELETE http://localhost:3000/api/products/3
```

```json
{
  "data": {
    "id": 3,
    "sku": "ELEC-003",
    "isActive": false
  }
}
```

- `200` on success.
- `404 PRODUCT_NOT_FOUND` if missing or already inactive.
- Soft-deleted products disappear from list/detail endpoints.
- Stock movements on inactive products return `409 PRODUCT_INACTIVE`.
- History remains queryable through the inventory endpoint.

## 6. Inventory transactions

### POST `/api/inventory/transactions`

Performs an atomic stock movement. The service locks the product row with
`SELECT ... FOR UPDATE`, validates the resulting quantity, updates the product, and inserts
the history row in one PostgreSQL transaction.

```json
{
  "productId": 3,
  "type": "OUT",
  "quantity": 5,
  "note": "Xuất bán đơn #1002"
}
```

```bash
curl -s -X POST http://localhost:3000/api/inventory/transactions \
  -H 'Content-Type: application/json' \
  -d '{
    "productId": 3,
    "type": "OUT",
    "quantity": 5,
    "note": "Xuất bán đơn #1002"
  }'
```

Success: `201 Created`.

```json
{
  "data": {
    "transaction": {
      "id": 42,
      "productId": 3,
      "productSku": "ELEC-003",
      "productName": "Bàn phím cơ",
      "type": "OUT",
      "quantity": 5,
      "note": "Xuất bán đơn #1002",
      "createdAt": "2026-11-03T08:20:00.000Z"
    },
    "product": {
      "id": 3,
      "sku": "ELEC-003",
      "quantity": 19,
      "stockStatus": "IN_STOCK",
      "updatedAt": "2026-11-03T08:20:00.000Z"
    }
  }
}
```

Rules:

- `type`: `IN` or `OUT`.
- `quantity`: integer 1–1,000,000.
- `note`: optional, max 500 characters; blank string becomes `null`.
- `IN` increases stock; `OUT` decreases stock.
- `OUT` greater than available stock returns `409 INSUFFICIENT_STOCK` and changes no rows.
- Missing product returns `404 PRODUCT_NOT_FOUND`.
- Inactive product returns `409 PRODUCT_INACTIVE`.
- Concurrent `OUT` requests cannot oversell; the second request waits for the row lock and
  then fails with `INSUFFICIENT_STOCK` if stock is insufficient.
- The stock update and history insert commit or roll back together.

### GET `/api/inventory/transactions`

Query parameters:

| Parameter | Rules |
|---|---|
| `productId` | Optional positive integer |
| `type` | Optional `IN` or `OUT` |
| `from` | Optional ISO date/time, inclusive lower bound |
| `to` | Optional ISO date/time, inclusive upper bound |
| `page` | Integer >= 1, default `1` |
| `limit` | Integer 1–100, default `20` |

```bash
curl -s 'http://localhost:3000/api/inventory/transactions?productId=3&type=OUT&page=1&limit=20'
```

```json
{
  "data": [
    {
      "id": 42,
      "productId": 3,
      "productSku": "ELEC-003",
      "productName": "Bàn phím cơ",
      "type": "OUT",
      "quantity": 5,
      "note": "Xuất bán đơn #1002",
      "createdAt": "2026-11-03T08:20:00.000Z"
    }
  ],
  "meta": {
    "page": 1,
    "limit": 20,
    "total": 1,
    "totalPages": 1,
    "hasNext": false,
    "hasPrev": false
  }
}
```

History is ordered by `created_at DESC, id DESC`. The product join includes inactive
products so history remains readable after a soft delete. `from` must be less than or equal
to `to`.

## 7. Dashboard

### GET `/api/dashboard/summary`

```bash
curl -s http://localhost:3000/api/dashboard/summary
```

```json
{
  "data": {
    "totalActiveProducts": 12,
    "totalUnitsInStock": 420,
    "lowStockProducts": 3,
    "outOfStockProducts": 1,
    "inventoryValue": 123456789,
    "recentTransactions": [
      {
        "id": 42,
        "productId": 3,
        "productSku": "ELEC-003",
        "productName": "Bàn phím cơ",
        "type": "OUT",
        "quantity": 5,
        "note": "Xuất bán đơn #1002",
        "createdAt": "2026-11-03T08:20:00.000Z"
      }
    ]
  }
}
```

Definitions:

- `totalActiveProducts`: count of `is_active = TRUE`.
- `totalUnitsInStock`: sum of `quantity` for active products.
- `lowStockProducts`: active products with `quantity > 0` and
  `quantity <= reorder_level`.
- `outOfStockProducts`: active products with `quantity = 0`.
- `inventoryValue`: sum of `quantity * unit_price` for active products, rounded to two
  decimals.
- `recentTransactions`: latest 10 transactions, newest first.

## 8. Security behavior

- Helmet sets security headers, including a CSP compatible with Flutter Web's generated
  bootstrap script and CanvasKit. `'unsafe-inline'` is limited to script/style directives
  required by Flutter's generated `index.html`; it can be tightened for API-only use.
- CORS allowlist:
  - Comma-separated `FRONTEND_ORIGIN`.
  - `RENDER_EXTERNAL_URL` when running on Render.
  - Any `http://localhost:*` or `http://127.0.0.1:*` origin when `NODE_ENV !== "production"`.
  - Requests without an `Origin` header (curl, same-origin) are allowed.
- JSON bodies are limited to 100 KiB by default (`JSON_BODY_LIMIT` can override it).
- Unknown routes return a JSON `404 ROUTE_NOT_FOUND`.
- Internal database errors, stack traces, connection strings, and credentials are never
  returned to clients.
- Database credentials live only in `backend/.env` locally or Render environment variables
  in deployment; they are not committed.

## 9. Local commands

### Prerequisites

- Node.js 20 or newer.
- `backend/.env` created from `backend/.env.example` with a valid `DATABASE_URL`.
- The Render PostgreSQL database from Phase 2 must be reachable.

### Install, verify, test, and start

```bash
cd backend
npm install
npm run db:verify
npm test
npm start
```

The API listens on `PORT` (default `3000`). Startup verifies the database connection with
retries before accepting traffic.

Development mode with Node's watcher:

```bash
npm run dev
```

### Smoke test against a running API

```bash
# Terminal 1
cd backend
npm start

# Terminal 2
cd backend
API_BASE_URL=http://localhost:3000 npm run smoke
```

The smoke script creates isolated records, exercises health, category/product creation,
stock IN/OUT, search, insufficient-stock rejection, dashboard, and soft delete, then removes
its records from the database. It never truncates seed data.

### Automated test suite

```bash
cd backend
npm test
```

The Vitest + Supertest suite uses the real PostgreSQL database configured in
`backend/.env`. It runs files sequentially, uses unique test categories/SKUs, and cleans up
its own transactions, products, and categories. It does not delete or truncate seed data.

Current Phase 3 result:

- 6 test files, 32 tests passed.
- Database verification: 15/15 checks passed.
- Smoke test: passed.
- `npm audit --omit=dev`: 0 vulnerabilities.

### Database commands retained from Phase 2

```bash
npm run db:migrate
npm run db:seed
npm run db:verify
npm run db:test-ops
```

## 10. Known limitations

- No authentication or authorization; this is a demo-scope internal API.
- No rate limiting yet; it is an optional P1 item.
- `PUT /api/products/:id` requires the full metadata payload.
- Product deletion is soft delete; inactive rows remain in the database.
- IDs are returned as JSON numbers for demo simplicity.
- The test suite requires network access to the Render PostgreSQL instance and is slower
  than a local database would be.
- Phase 3 does not include Flutter Web or Render Web Service deployment; those are later
  phases.
