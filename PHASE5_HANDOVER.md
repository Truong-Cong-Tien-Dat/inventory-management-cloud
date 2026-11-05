# PHASE 5 HANDOVER — Integration & End-to-End Testing

> Cập nhật: 2026-11-05. Phase 5 hoàn tất ở mức **mọi kiểm thử tự động có thể thực hiện
> trong môi trường này đều pass**; phần duyệt UI bằng trình duyệt thật được liệt kê
> minh bạch thành checklist manual (mục 5) — **không tuyên bố pass** những gì chưa chạy.
> Trạng thái: **chờ phê duyệt để bắt đầu Phase 6 (Render deployment).**

---

## 1. Môi trường kiểm thử đã dựng

| Thành phần | Cách chạy | Kết quả |
|---|---|---|
| Backend Express | `cd backend && npm start` (port 3000, `development`) | Chạy ổn định, log request đầy đủ |
| PostgreSQL Render | Chỉ truy cập qua backend (External Database URL, SSL require) | `database: up` |
| Flutter Web | `flutter run -d web-server --web-port 8080 --web-hostname 0.0.0.0 --dart-define=API_BASE_URL=http://localhost:3000` | Serve HTTP 200 tại `/` |

Backend và frontend đã chạy **đồng thời** và giao tiếp qua REST API thật; frontend
không chứa dữ liệu mock, không kết nối trực tiếp CSDL.

## 2. Kiểm thử đã thực hiện và kết quả

### 2.1 Tự động — tất cả PASS

| # | Bộ kiểm thử | Lệnh | Kết quả |
|---|---|---|---|
| 1 | Backend unit/integration (vitest) | `npm test` | **32/32 pass** (bao gồm `concurrency.test.js` — chặn oversell dưới request đồng thời) |
| 2 | Structural DB check | `npm run db:verify` | **15/15 pass** |
| 3 | Backend end-to-end smoke (dữ liệu tách biệt, tự dọn) | `API_BASE_URL=http://localhost:3000 npm run smoke` | **10/10 pass**, "isolated smoke-test records removed" |
| 4 | Static analysis Flutter | `flutter analyze` | **0 issue** |
| 5 | Flutter unit + widget tests | `flutter test` | **27/27 pass** (24 cũ + 3 test responsive mới) |
| 6 | Release build | `flutter build web --release` | **thành công** (~115 s) |
| 7 | API contract smoke (frontend services ↔ backend thật, chỉ đọc) | `flutter test tool/api_smoke_test.dart` | **7/7 pass** |
| 8 | CRUD + tồn kho dữ liệu thật qua service layer của UI (tự soft-delete dọn dẹp) | `flutter test tool/crud_smoke_test.dart` | **2/2 pass** |

Nội dung kiểm tra của mục 8 (đúng các luồng UI sẽ gọi): tạo sản phẩm (quantity=0) →
sửa metadata → nhập kho +10 → xuất kho −3 → xuất vượt tồn bị chặn
(`INSUFFICIENT_STOCK`, quantity không đổi) → sửa trực tiếp `quantity` bị chặn
(`FIELD_NOT_EDITABLE`) → xoá mềm → chi tiết trả 404 → search active list không còn thấy.

### 2.2 Tích hợp ở mức HTTP (không cần trình duyệt)

| Kiểm tra | Cách làm | Kết quả |
|---|---|---|
| CORS preflight | `OPTIONS /api/products` với `Origin: http://localhost:8080` | **204** + `Access-Control-Allow-Origin: http://localhost:8080`, methods GET/POST/PUT/DELETE/OPTIONS |
| CORS GET thật | `GET /api/health` với `Origin: http://localhost:8080` | Header `Access-Control-Allow-Origin` trả về đúng origin |
| Origin không cho phép | `GET /api/health` với `Origin: http://evil.example.com` | **403 Forbidden**, không trả header allow — đúng thiết kế |
| Deep-link SPA fallback (dev server) | `curl /products/3`, `/inventory`, `/categories` trên port 8080 | **HTTP 200** cho mọi route (dev server trả `index.html`, go_router takeover bằng URL path) |
| Health endpoint | `curl /api/health` | 200 `{"database":"up"}` |

> Lưu ý Phase 6: SPA fallback cho deep-link trên **production** sẽ do Express serve
> `build/web` (Docker image) đảm nhiệm — dev server của Flutter chỉ minh chứng routing client-side.

### 2.3 Lỗi đã phát hiện & đã xử lý trong Phase 5

| # | Phát hiện | Mức | Xử lý |
|---|---|---|---|
| 1 | **Sidebar footer overflow 18 px** (RenderFlex overflow khi render `app_shell.dart:437`) — phát hiện bởi widget test responsive mới | Bug UI thật | **Đã sửa**: bọc label "Dữ liệu trực tiếp" trong `Expanded` + `maxLines: 1` + `ellipsis`. Không đổi gì khác |
| 2 | **503 `DB_UNAVAILABLE` ngẫu nhiên** trên `/api/health`: log cho thấy request lỗi mất 5002 ms (timeout truy vấn), sau đó 12/12 lần đo tiếp theo đều 200 | Hạn chế môi trường (latency tới PostgreSQL Render tại Oregon, khu vực xuyên lục địa; response DAO 180 ms – 3,7 s) | Không sửa (ngoài phạm vi — không redesign pool). Backend map đúng 503 + code `DB_UNAVAILABLE`; frontend đã có banner lỗi + retry. Ghi nhận làm hạn chế đã biết |

## 3. Bao phủ viewport & browser

| Kênh | Phương thức | Phạm vi đã xác minh | Còn lại |
|---|---|---|---|
| Widget test Flutter (`test/responsive_shell_test.dart`) | `tester.view` giả lập logical size 1440×900 / 768×900 / 390×844 | Desktop ≥1024 → **sidebar** (brand "Kho Thông Minh", mục "ĐIỀU HƯỚNG", chip "Dữ liệu trực tiếp"); tablet 600–1023 → **NavigationRail**; mobile <600 → **AppBar + Drawer** (mở drawer được, đủ mục điều hướng tiếng Việt) | Là kiểm tra layout ở mức Flutter widget, **không phải ảnh chụp trình duyệt thật** |
| Trình duyệt desktop thật / Chrome headless | **Không khả dụng trong môi trường này**: không có trình duyệt desktop kết nối session và không có binary Chrome/Chromium trên máy (`which google-chrome chromium` rỗng) | — | Toàn bộ checklist mục 5 |

## 4. Đối chiếu 10 yêu cầu xác minh của Phase 5

| # | Yêu cầu | Kết quả | Kênh xác minh |
|---|---|---|---|
| 1 | Dashboard tải dữ liệu PostgreSQL thật | **Pass** (API level) | `tool/api_smoke_test.dart` (dashboard summary counters), backend smoke |
| 2 | Danh sách SP, tìm kiếm, lọc, sắp xếp, phân trang | **Pass** (API level) | Backend smoke (search), vitest products.test.js (filter/sort/pagination), tool smoke |
| 3 | Tạo & sửa sản phẩm | **Pass** (API + service level) | `tool/crud_smoke_test.dart` test 1 |
| 4 | Chi tiết SP & lịch sử giao dịch | **Pass** (API level) | tool smoke (product detail, inventory history), backend smoke |
| 5 | Nhập/xuất kho IN/OUT | **Pass** (API + service level) | `tool/crud_smoke_test.dart`, backend smoke |
| 6 | Chặn xuất vượt tồn kho | **Pass** (cả client guard lẫn server 409) | `tool/crud_smoke_test.dart`, `backend/tests/inventory.test.js`, `concurrency.test.js` |
| 7 | Cấm sửa trực tiếp `quantity` | **Pass** | `tool/crud_smoke_test.dart` test 2 (`FIELD_NOT_EDITABLE`) |
| 8 | Tạo danh mục | **Pass** (API level) | `npm run smoke` (category list/create); UI dialog đã có test widget |
| 9 | Xoá mềm sản phẩm | **Pass** | `tool/crud_smoke_test.dart` + backend smoke (history preserved) |
| 10 | Thông báo lỗi, loading, empty state | **Pass** (widget tests + code review); **chưa xác minh bằng mắt trên trình duyệt** | `flutter test` (24 test gốc) |

## 5. Checklist manual còn lại (cần người + trình duyệt thật)

Không có browser automation khả dụng, các mục dưới đây **chưa được xác minh** và
cần kiểm nhanh bằng tay sau khi chạy 2 lệnh ở mục 6:

1. Mở `http://localhost:8080` — Dashboard hiển thị số liệu thật, bảng giao dịch gần đây.
2. `/products`: gõ ô tìm kiếm (debounce), đổi bộ lọc danh mục, đổi sort, chuyển trang.
3. Dialog thêm/sửa sản phẩm: validation đỏ tại ô, lưu thành công có Snack bar.
4. Trang chi tiết sản phẩm: nút Nhập/Xuất kho mở dialog, lưu xong số tồn cập nhật.
5. Quản lý kho: picker tìm sản phẩm, IN/OUT thành công có Snack bar, thử xuất quá tồn → lỗi.
6. `/categories`: tạo danh mục mới, trùng tên hiện lỗi tại ô.
7. Xoá mềm sản phẩm: hộp xác nhận → sản phẩm biến mất khỏi danh sách.
8. Co giãn cửa sổ qua 1440/768/390 → sidebar ↔ rail ↔ drawer chuyển đúng.
9. Refresh (F5) tại `/products`, `/inventory` — không 404, đúng màn hình sau reload.
10. Dán trực tiếp URL `/products/<id>` — mở đúng chi tiết sản phẩm.
11. Tab Network: request từ `localhost:8080` sang `:3000` không bị CORS error.
12. Tiếng Việt không lỗi font; tiền tệ dạng `1.290.000 ₫`; ngày `dd/MM/yyyy`.

> Ghi chú trung thực: các mục 9–11 ở mức HTTP đã được xác minh bằng curl (mục 2.2);
> việc còn lại là quan sát hành vi trong trình duyệt thật.

## 6. Lệnh tái lập kiểm thử

```bash
# Terminal 1 — backend
cd backend && npm start                      # API :3000

# Terminal 2 — frontend dev
cd frontend
flutter run -d web-server --web-port 8080 --web-hostname 0.0.0.0 \
  --dart-define=API_BASE_URL=http://localhost:3000

# Kiểm thử tự động (không cần frontend)
cd backend
npm test                                     # 32/32
npm run db:verify                            # 15/15
API_BASE_URL=http://localhost:3000 npm run smoke

cd ../frontend
flutter analyze                              # 0 issue
flutter test                                 # 27/27
flutter test tool/api_smoke_test.dart        # 7/7 (cần backend)
flutter test tool/crud_smoke_test.dart       # 2/2 (cần backend)
flutter build web --release                  # build/web
```

Kiểm tra CORS/deep-link bằng curl: xem lại các lệnh trong `PHASE5_HANDOVER.md` mục 2.2
(`curl -X OPTIONS ... -H 'Origin: http://localhost:8080'`, `curl http://localhost:8080/products/3`).

## 7. Checklist sẵn sàng Phase 6 — Render deployment

- [x] Backend 32/32, DB structural 15/15, backend smoke 10/10 — đều pass trên DB Render thật.
- [x] Flutter analyze 0 issue; 27/27 unit/widget/API-client tests; release build thành công.
- [x] `API_BASE_URL` đã hỗ trợ origin tương đối khi release (single-origin Render sẵn sàng).
- [x] CORS backend cho phép localhost dev; Phase 6 cần bổ sung origin Render production.
- [x] Soft-delete, atomic IN/OUT, chống oversell (kể cả concurrent) đã được kiểm chứng.
- [x] Không có mock data trong runtime; mọi dữ liệu qua REST API ↔ PostgreSQL thật.
- [ ] Tạo `Dockerfile` multi-stage (node build + nginx/serve Flutter build/web) + `.dockerignore` + `render.yaml`.
- [ ] SPA fallback trong Express cho deep-link production (dev server đã minh chứng routing OK).
- [ ] Kiểm Docker build local (máy hiện không có Docker — sẽ ghi nhận hướng dẫn xác minh tay).
- [ ] Bổ sung origin Render (ví dụ `https://<service>.onrender.com`) vào allow-list CORS.
- [ ] Viết `docs/DEPLOY_RENDER.md`.

**Gate: không bắt đầu Phase 6 cho đến khi người dùng phê duyệt.**
