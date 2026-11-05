# HƯỚNG DẪN TRIỂN KHAI LÊN RENDER — Inventory Management System

> Tài liệu này là sản phẩm của yêu cầu đề bài gốc: *"Write a step-by-step guide on
> deploying the website to Render and connecting it to PostgreSQL."*
>
> Kiến trúc đã duyệt: **1 Render Web Service (Docker)** chạy Express API + Flutter Web
> prebuilt (Phương án A — build web trên máy local, commit `frontend/build/web/`),
> kết nối **PostgreSQL Render có sẵn**. Một URL duy nhất, same-origin, không cần CORS
> production.

---

## 1. Điều kiện cần (Prerequisites)

| Yêu cầu | Kiểm tra |
|---|---|
| Tài khoản GitHub | có quyền tạo repository mới |
| Tài khoản Render (free) | dashboard.render.com |
| Flutter SDK 3.47+ (đã build web ở Phase 4/5) | `flutter --version` |
| Node.js 20+ | `node --version` |
| Repo chứa code đã hoàn thành Phase 1–5 | xem `PHASE5_HANDOVER.md` |

## 2. Build Flutter Web trên máy local

```bash
cd frontend
flutter pub get
flutter build web --release --no-wasm-dry-run
```

- Kết quả nằm ở `frontend/build/web/` (~40 MB).
- **Không truyền** `--dart-define=API_BASE_URL` khi build cho Render: bản release
  không định nghĩa này sẽ tự dùng **origin hiện tại** (same-origin) — đã kiểm chứng
  bundle không chứa chuỗi `localhost:3000` (`grep -c "localhost:3000" build/web/main.dart.js` → 0).
- `frontend/build/web/` được **commit lên git** (loại trừ các output build khác) vì
  Docker image sẽ copy trực tiếp thư mục này.

## 3. Chuẩn bị repository GitHub

1. Kiểm tra `.gitignore` đã loại trừ: `backend/.env`, mọi `*.env*`, `node_modules/`
   (trừ ngoại lệ `backend/.env.example` chỉ chứa placeholder).
2. Commit toàn bộ dự án (xem mục 10 để xem lệnh kiểm tra trước commit).
3. Tạo repository **private** trên GitHub, rồi:

```bash
git remote add origin git@github.com:<tài khoản>/<repo>.git
git push -u origin main        # KHÔNG dùng --force
```

📸 **[S1]** Ảnh chụp trang GitHub repo hiển thị cấu trúc thư mục
(backend/, frontend/, database/, docs/, Dockerfile).

## 4. Kết nối PostgreSQL trên Render

Dùng lại **instance PostgreSQL đã tạo từ Phase 2** (không tạo mới, không reset):

| Mục đích | URL dùng | Vì sao |
|---|---|---|
| Web Service (cùng region Oregon) | **Internal Database URL** | Kết nối nội mạng Render, nhanh và riêng tư |
| Chạy migration/seed từ máy local | **External Database URL** | Chỉ cần khi thao tác từ ngoài |

- Lấy URL: Render Dashboard → **Databases** → chọn instance → **Connections** →
  *Internal Database URL* / *External Database URL*.
- ⚠️ URL chứa mật khẩu — **không** đưa vào code, log hay ảnh chụp báo cáo.

> Database hiện có sẵn schema (4 bảng) và seed data. **Không chạy lại migration/seed**
> trừ khi tạo database mới. Chỉ chạy `npm run db:verify` để xác nhận.

📸 **[S2]** Trang PostgreSQL trên Render: region (Oregon), trạng thái Available,
mục Connections (che mật khẩu).

## 5. Tạo Web Service trên Render

1. Render Dashboard → **New +** → **Web Service**.
2. Kết nối repository GitHub vừa tạo (uỷ quyền GitHub nếu lần đầu).
3. Cấu hình:

| Thiết lập | Giá trị |
|---|---|
| Runtime | **Docker** (Render tự nhận `Dockerfile` ở root) |
| Region | **Oregon** (cùng region với PostgreSQL) |
| Instance type | **Free** |
| Health Check Path | `/api/health` |

4. **Environment variables** (Environment tab):

| Biến | Giá trị | Ghi chú |
|---|---|---|
| `DATABASE_URL` | Internal Database URL của bước 4 | Render ẩn giá trị sau khi lưu |
| `DATABASE_SSL` | `disable` | URL nội mạng Render không dùng TLS; dùng `require` nếu dùng External URL |
| `NODE_ENV` | `production` | Tắt CORS localhost, bật trust proxy, log chuẩn production |

5. Không cần set `PORT` — Render tự cấp biến `PORT` (mặc định 10000) và backend đã
   đọc `process.env.PORT`. Không cần set `RENDER_EXTERNAL_URL` — Render tự inject và
   code đã thêm nó vào CORS allow-list (giúp same-origin POST/PUT/DELETE có header
   `Origin` được chấp nhận).

📸 **[S3]** Form tạo Web Service (runtime Docker, region, repo).
📸 **[S4]** Trang Environment hiển thị các biến (che `DATABASE_URL`).

## 6. Triển khai (Deploy)

1. Bấm **Create Web Service** (hoặc **Manual Deploy → Deploy latest commit**).
2. Theo dõi log: Render build Docker image (`npm ci --omit=dev`, copy `frontend/build/web`
   vào `/app/public`) rồi khởi động container.
3. Trạng thái chuyển **Live** khi health check `/api/health` trả 200.
4. URL công khai dạng `https://<tên-service>.onrender.com`.

> ⏱️ Free tier tự "ngủ" sau ~15 phút không truy cập; request đầu tiên sau đó mất
> ~30–60 s để tỉnh. **Mở URL trước buổi demo/chấm điểm ít nhất 1 phút.**

📸 **[S5]** Log build/deploy thành công (có dòng `npm ci` và `Deploy live`).
📸 **[S6]** Trang service trạng thái **Live** + URL công khai.

## 7. Kiểm chứng sau triển khai

```bash
# 1. Health check (mở trong trình duyệt cũng được)
curl https://<tên-service>.onrender.com/api/health
# Mong đợi: {"data":{"status":"ok","database":"up",...}}

# 2. SPA deep-link (phải trả HTML 200, không 404)
curl -o /dev/null -w '%{http_code}\n' https://<tên-service>.onrender.com/products/11
curl -o /dev/null -w '%{http_code}\n' https://<tên-service>.onrender.com/inventory
```

📸 **[S7]** Kết quả health check trên URL công khai.

### Kiểm chứng 3 chức năng chính của đề bài

| # | Chức năng | Cách làm | Ảnh chụp |
|---|---|---|---|
| 1 | **Thêm sản phẩm** | Mở `https://…/products` → **Thêm sản phẩm** → SKU `DEMO-001`, tên, danh mục, đơn giá → Lưu → Snack bar + sản phẩm hiện trong bảng (tồn = 0) | 📸 **[S8a]** form điền; **[S8b]** kết quả sau lưu |
| 2 | **Tìm kiếm sản phẩm** | Gõ `DEMO-001` vào ô tìm kiếm → danh sách lọc đúng; thử tìm từ vô nghĩa → trạng thái trống tiếng Việt | 📸 **[S9]** |
| 3 | **Cập nhật sản phẩm** | Nút **Sửa** trên `DEMO-001` → đổi tên/giá → Lưu → bảng cập nhật ngay | 📸 **[S10a]** form sửa; **[S10b]** kết quả |

### Bằng chứng bổ sung (tính năng mở rộng — tuỳ chọn)

- Dashboard tổng quan dữ liệu thật — 📸 **[S11]**
- Nhập/xuất kho + lịch sử giao dịch — 📸 **[S12]**
- Truy cập từ điện thoại (responsive drawer) — 📸 **[S13]**
- Data persists sau khi service restart (Manual Deploy → Deploy latest commit, tải lại
  trang, sản phẩm `DEMO-001` vẫn còn) — 📸 **[S14]**

## 8. Xử lý sự cố (Troubleshooting)

| Triệu chứng | Nguyên nhân | Cách xử lý |
|---|---|---|
| Deploy fail: `STATIC_DIR is configured but /app/public/index.html does not exist` | `frontend/build/web` chưa được commit/push | Chạy lại `flutter build web --release`, commit thư mục, push |
| Deploy fail: `npm ci` lỗi version | `package-lock.json` không khớp `package.json` | Chạy `npm install` local, commit lại lock file |
| Service live nhưng trang trắng / lỗi CSP trên Console | Helmet CSP chặn tài nguyên | Gửi lại ảnh Console; chỉ nên xảy ra nếu build dùng renderer lạ |
| `/api/*` trả 503 `DB_UNAVAILABLE` | Sai `DATABASE_URL`, hoặc dùng External URL nhưng `DATABASE_SSL` sai | Kiểm tra biến môi trường; Internal URL → `DATABASE_SSL=disable`, External → `require` |
| `CORS_ORIGIN_DENIED` khi gọi API từ trình duyệt | Truy cập bằng domain khác `RENDER_EXTERNAL_URL` | Dùng đúng URL `.onrender.com`; hoặc thêm domain vào `FRONTEND_ORIGIN` |
| Request đầu chậm 30–60 giây | Free tier sleep | Mở URL trước để service tỉnh |
| Đổi code không có hiệu lực | Build local chưa chạy lại trước khi push | `flutter build web --release` → commit `frontend/build/web` → push |

## 9. Checklist ảnh chụp cho báo cáo

- [ ] **[S1]** GitHub repo + cấu trúc thư mục
- [ ] **[S2]** PostgreSQL trên Render (che mật khẩu)
- [ ] **[S3]** Form tạo Web Service
- [ ] **[S4]** Environment variables (che `DATABASE_URL`)
- [ ] **[S5]** Log build thành công
- [ ] **[S6]** Service trạng thái Live + URL
- [ ] **[S7]** Health check công khai
- [ ] **[S8a/b]** Thêm sản phẩm (form + kết quả)
- [ ] **[S9]** Tìm kiếm sản phẩm
- [ ] **[S10a/b]** Cập nhật sản phẩm (form + kết quả)
- [ ] **[S11]** Dashboard (mở rộng)
- [ ] **[S12]** Nhập/xuất kho (mở rộng)
- [ ] **[S13]** Mobile responsive
- [ ] **[S14]** Dữ liệu còn sau restart

## 10. Phụ lục — kiểm tra an toàn trước khi push

```bash
# Không được có file .env thật nào trong danh sách sẽ commit
git add -A --dry-run | grep -iE "\.env$" || echo "OK: no .env staged"

# Không được có chuỗi kết nối thật trong các file sẽ commit
git ls-files --others --exclude-standard | xargs grep -l "postgresql://[^U]" 2>/dev/null \
  | grep -v database.js || echo "OK: no connection strings"

# Dockerfile và bundle build/web phải có mặt
git add -A --dry-run | grep -c "frontend/build/web"
```
