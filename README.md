# Inventory Management System (Hệ thống quản lý kho hàng)

> Đồ án môn **Cloud Computing** — Flutter Web + Node.js/Express + PostgreSQL, triển khai trên Render.
>
> 🌐 **Ứng dụng đang chạy:** <https://inventory-management-cloud.onrender.com>
> 📚 **Hướng dẫn triển khai Render:** [`docs/DEPLOY_RENDER.md`](docs/DEPLOY_RENDER.md)
> 🔌 **Tài liệu REST API:** [`docs/API.md`](docs/API.md)
> 🧪 **Kế hoạch & kết quả kiểm thử:** [`docs/TEST_PLAN.md`](docs/TEST_PLAN.md)

## 1. Chức năng

**Ba chức năng chính của đề bài:**

1. **Thêm sản phẩm** — tạo sản phẩm mới (SKU duy nhất, giá VND, danh mục, mức tồn tối thiểu), tồn kho khởi đầu bằng 0.
2. **Tìm kiếm sản phẩm** — tìm theo tên hoặc SKU, lọc theo danh mục, sắp xếp, phân trang.
3. **Cập nhật sản phẩm** — sửa toàn bộ thông tin sản phẩm (không cho sửa trực tiếp số lượng tồn).

**Tính năng mở rộng (vượt yêu cầu đề bài):** dashboard tổng quan, nhập/xuất kho atomic có khoá dòng (chặn bán quá tồn, cả khi request đồng thời), lịch sử giao dịch có lọc/phân trang, danh mục, xoá mềm sản phẩm (giữ lịch sử), giao diện responsive tiếng Việt (sidebar / rail / drawer), định dạng tiền tệ `1.290.000 ₫`.

## 2. Công nghệ

| Thành phần | Công nghệ |
|---|---|
| Frontend | Flutter Web (Material 3), `provider` + `ChangeNotifier`, `go_router`, `http`, `intl` (locale `vi_VN`) |
| Backend | Node.js 20+, Express 5, Zod validation, kiến trúc route → controller → service → repository |
| Database | PostgreSQL (Render), migration + seed SQL |
| Triển khai | 1 Docker Web Service trên Render (Express phục vụ cả API và Flutter Web prebuilt) |

## 3. Cấu trúc thư mục

```
inventory-management-cloud/
├── backend/            # API Express (src/), kiểm thử (tests/), script DB (scripts/)
├── database/           # schema.sql, migrations/, seed.sql
├── frontend/           # Ứng dụng Flutter Web (lib/), test/, tool/ (smoke test)
├── docs/               # API.md, DEPLOY_RENDER.md, TEST_PLAN.md
└── Dockerfile          # Image production (node:20-alpine + build/web)
```

> 📌 **Về thư mục làm việc:** tất cả lệnh bên dưới đều viết rõ bạn đang đứng ở đâu.
> Cách đơn giản nhất: mở **hai cửa sổ terminal riêng** từ thư mục **chứa thư mục repo vừa clone**
> (ví dụ `~/Documents`) — một terminal cho backend, một cho frontend.

## 4. Yêu cầu môi trường

| Công cụ | Phiên bản | Kiểm tra |
|---|---|---|
| Node.js | **20+** (bắt buộc) | `node --version` |
| Flutter SDK | **3.47+** (Dart SDK `^3.13.2`), đã bật web | `flutter --version`, `flutter devices` |
| PostgreSQL | 14+ (chạy local) | `psql --version` |
| Git | bất kỳ | `git --version` |

## 5. Cài đặt và chạy trên máy cá nhân

### Bước 0 — Clone dự án (từ thư mục cha, ví dụ `~/Documents`)

```bash
git clone https://github.com/Truong-Cong-Tien-Dat/inventory-management-cloud.git
# kết quả: ~/Documents/inventory-management-cloud/
```

### Bước 1 — Tạo database phát triển riêng `inventory_demo`

> ⚠️ **Bước này bắt buộc.** Database không tự tạo — bạn phải tạo trước khi chạy migration.

**Linux (terminal psql):**
```bash
sudo -u postgres psql
```
```sql
CREATE DATABASE inventory_demo;
CREATE USER inventory_app WITH PASSWORD 'matkhau_local_cua_ban';
GRANT ALL PRIVILEGES ON DATABASE inventory_demo TO inventory_app;
\q
```
(Hoặc nhanh hơn: `createdb inventory_demo` nếu user postgres hiện tại có quyền tạo database.)

**Windows (PowerShell, `psql` đã có trong PATH sau khi cài PostgreSQL):**
```powershell
psql -U postgres -c "CREATE DATABASE inventory_demo;"
psql -U postgres -c "CREATE USER inventory_app WITH PASSWORD 'matkhau_local_cua_ban';"
psql -U postgres -c "GRANT ALL PRIVILEGES ON DATABASE inventory_demo TO inventory_app;"
```
(Có thể dùng pgAdmin thay thế nếu quen giao diện đồ hoạ.)

### Bước 2 — Cài backend và cấu hình `.env` (terminal 1)

```bash
# Từ thư mục cha (ví dụ ~/Documents):
cd inventory-management-cloud/backend
npm install
cp .env.example .env        # Windows PowerShell: Copy-Item .env.example .env
```

Mở `backend/.env` (file này **không** có sẵn sau khi clone vì chứa thông tin nhạy cảm — bạn tự tạo từ `.env.example`). Điền các biến:

| Biến | Giá trị khi chạy local | Giải thích |
|---|---|---|
| `DATABASE_URL` | `postgresql://inventory_app:matkhau_local_cua_ban@localhost:5432/inventory_demo` | Khớp đúng user/password/database bạn tạo ở Bước 1 |
| `DATABASE_SSL` | `disable` | PostgreSQL local không cần TLS. Chỉ dùng `require` khi trỏ tới Render bằng External URL; giá trị hợp lệ: `disable`, `require`, `no-verify` |
| `NODE_ENV` | `development` | Cho phép CORS từ mọi `localhost:*` |
| `PORT` | `3000` | Cổng API |

> 🔐 File `.env` đã nằm trong `.gitignore` — không bao giờ commit hay chia sẻ nội dung thật.

### Bước 3 — Chạy migration + seed (vẫn ở terminal 1, thư mục `backend`)

```bash
npm run db:migrate    # tạo 4 bảng: categories, products, inventory_transactions, schema_migrations
npm run db:seed       # chèn dữ liệu mẫu (an toàn: ON CONFLICT DO NOTHING, không xoá dữ liệu cũ)
npm run db:verify     # kiểm tra 15/15 cấu trúc database
```

- Các script đọc `DATABASE_URL` từ `backend/.env`, chạy được từ thư mục `backend/` (hoặc gốc repo).
- Chạy migrate + seed một lượt: `npm run db:setup`.
- Script seed **từ chối chạy** nếu `NODE_ENV=production` (trừ khi set `ALLOW_PROD_SEED=true`) — lớp bảo vệ database thật.

> 🛑 **CẢNH BÁO QUAN TRỌNG — đừng trỏ vào database production:**
> `DATABASE_URL` trong `backend/.env` dùng để chạy local **phải** trỏ tới database dev riêng
> (`inventory_demo`) — **tuyệt đối không** điền URL PostgreSQL Render của bản production.
> Các lệnh sau **chỉ được chạy khi `DATABASE_URL` trỏ tới database dev/test riêng**:
> `db:migrate`, `db:seed`, `db:setup`, `npm test`, `npm run smoke`,
> `flutter test tool/api_smoke_test.dart`, `flutter test tool/crud_smoke_test.dart`.
> Chúng tạo/sửa/xoá dữ liệu test. Bản production trên Render đã có schema + seed sẵn,
> và không cần (không được) seed lại. Muốn kiểm tra database production, chỉ dùng lệnh
> chỉ-đọc như mở URL `/api/health` hoặc giao diện web.

### Bước 4 — Chạy backend (terminal 1)

```bash
# Vẫn đang ở: inventory-management-cloud/backend
npm start             # API tại http://localhost:3000
```

Kiểm tra: mở `http://localhost:3000/api/health` → `{"data":{"status":"ok","database":"up",...}}`

### Bước 5 — Chạy Flutter Web (terminal 2, mở từ thư mục cha)

```bash
# Từ thư mục cha (ví dụ ~/Documents):
cd inventory-management-cloud/frontend
flutter pub get
flutter run -d web-server --web-port 8080 --web-hostname 0.0.0.0 --dart-define=API_BASE_URL=http://localhost:3000
```

Mở **http://localhost:8080** — ứng dụng gọi API qua `--dart-define` phía trên (khi build release mà **không** truyền biến này, frontend tự dùng same-origin — đúng cấu hình Render).

## 6. Kiểm thử

```bash
# --- Backend (terminal 1, đang ở inventory-management-cloud/backend) ---
npm test                 # 37 test unit/integration (vitest) — tự tạo & dọn dữ liệu test
npm run smoke            # 10 bước e2e: thêm/tìm/nhập/xuất kho/xoá mềm — tự tạo & tự dọn record
npm run db:verify        # 15/15 cấu trúc database

# --- Frontend (terminal 2, đang ở inventory-management-cloud/frontend) ---
flutter analyze          # phân tích tĩnh (0 issue)
flutter test             # 27 test unit/widget (dùng MockClient, không cần mạng, không cần backend)
flutter test tool/api_smoke_test.dart     # 7 test API thật — CẦN backend đang chạy ở :3000
flutter test tool/crud_smoke_test.dart    # 2 test CRUD + tồn kho dữ liệu thật — CẦN backend, tự dọn
```

> 🛑 Nhắc lại cảnh báo ở Bước 3: các bộ test tích hợp (`npm test`, `npm run smoke`,
> `tool/*.dart`) thao tác dữ liệu thật qua `DATABASE_URL` — chỉ chạy trỏ tới database
> dev/test riêng, **không chạy trỏ tới database Render production**.
> `flutter analyze` và `flutter test` (không có đối số `tool/`) không cần backend, không đụng dữ liệu.

> ✅ Cả hai bộ smoke (`npm run smoke` và `tool/*.dart`) chỉ tạo record với tiền tố duy nhất và xoá mềm/xoá chúng khi kết thúc — không làm bẩn dữ liệu mẫu.

## 7. Build bản production

```bash
# Terminal 2, đang ở inventory-management-cloud/frontend
flutter build web --release --no-wasm-dry-run
# Kết quả: frontend/build/web — bundle không chứa localhost (same-origin)
```

Để chạy "như production" trên máy: Express có thể phục vụ chính bundle này:

```bash
# Đang ở inventory-management-cloud/backend
NODE_ENV=production PORT=3101 STATIC_DIR=../frontend/build/web node src/server.js
# Mở http://localhost:3101
# Windows PowerShell: $env:NODE_ENV="production"; $env:PORT="3101"; $env:STATIC_DIR="..\frontend\build\web"; node src/server.js
```

Triển khai Render đầy đủ (Docker, biến môi trường, kiểm chứng): xem [`docs/DEPLOY_RENDER.md`](docs/DEPLOY_RENDER.md).

## 8. Xử lý sự cố thường gặp

| Hiện tượng | Nguyên nhân & cách xử lý |
|---|---|
| `DATABASE_URL is not configured` | Chưa tạo `backend/.env` (Bước 2) hoặc chưa điền `DATABASE_URL` |
| Backend báo `ECONNREFUSED 127.0.0.1:5432` | PostgreSQL local chưa chạy, sai port/tên database |
| Lỗi `database "inventory_demo" does not exist` | Chưa chạy Bước 1 — tạo database trước khi migrate |
| `permission denied for database` | Chưa `GRANT ALL PRIVILEGES` cho user ở Bước 1, hoặc sai user trong `DATABASE_URL` |
| Frontend hiện "Mất kết nối" | Backend chưa chạy ở `:3000`, hoặc quên `--dart-define=API_BASE_URL` khi `flutter run` |
| Lỗi CORS trên Console khi dev | Đảm bảo `NODE_ENV=development` trong `.env` (cho phép mọi `localhost:*`) |
| `flutter: command not found` / phiên bản cũ | Cài Flutter SDK 3.47+ theo flutter.dev; chạy `flutter doctor` |
| Port 3000/8080 bị chiếm | Đổi port: `PORT=3001 npm start` và `--web-port 8081` (nhớ đổi cả `API_BASE_URL`) |
| `git clone` xong thiếu `frontend/build/web` | Thư mục này đã được commit; nếu thiếu, chạy lại `flutter build web --release` |

## 9. Ghi chú

- **Bảo mật:** không có xác thực/phân quyền (ngoài phạm vi đồ án); không commit secrets; frontend không bao giờ kết nối thẳng PostgreSQL — mọi dữ liệu đi qua REST API.
- **Dữ liệu mẫu:** seed gồm 5 danh mục và 12 sản phẩm (có sẵn sản phẩm sắp hết/hết hàng để demo cảnh báo).
- Toàn bộ lịch sử phát triển theo phase nằm ở `PHASE4_HANDOVER.md`, `PHASE5_HANDOVER.md`, `IMPLEMENTATION_PLAN.md`.
