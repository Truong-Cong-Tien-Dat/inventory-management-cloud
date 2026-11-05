# PHASE 4 HANDOVER — Flutter Web Frontend

> Cập nhật: 2026-11-04. Người giữ phiên sau có thể tiếp tục từ mục "6. Lệnh tiếp tục".
> Trạng thái Phase 4: **code complete + automated verification passed; browser-side UI
> walkthrough chưa chạy** (không kết nối được trình duyệt desktop trong phiên làm việc).

---

## 1. Tính năng đã hoàn thành

### 1.1 Khung ứng dụng (App shell & navigation)

| Hạng mục | Chi tiết |
|---|---|
| Thiết kế | Material 3, theme sáng, chủ đạo indigo (`AppColors.primary = 0xFF4F46E5`), nền `0xFFF5F7FB` |
| Desktop (≥ 1024 px) | Sidebar 252 px + top bar riêng: brand "Kho Thông Minh" |
| Tablet (600–1023 px) | `NavigationRail` (hiện label) + top bar compact |
| Mobile (< 600 px) | `AppBar` + `Drawer` 286 px, điều hướng đầy đủ |
| Trạng thái hệ thống | Chip "API trực tuyến / Mất kết nối / Đang kiểm tra" ở top bar; bấm để kiểm tra lại |
| Làm mới toàn cục | Nút "Làm mới dữ liệu" trên top bar (`GlobalRefreshController` + `GlobalRefreshMixin`); mỗi screen tự đăng ký listener |
| Deep link | `go_router` + `usePathUrlStrategy()`; `/`, `/products`, `/products/:id`, `/inventory`, `/inventory?productId=N`, `/categories`, kèm màn 404 |
| Ngôn ngữ | `Locale('vi','VN')` + `flutter_localizations` + `initializeDateFormatting('vi_VN')` |
| Tiền tệ / số / ngày | `intl` `vi_VN`: `1.290.000 ₫`, ngày `dd/MM/yyyy HH:mm` |

### 1.2 Dashboard (`/`)

- 5 thẻ `StatCard`: tổng sản phẩm active, tổng tồn kho, giá trị tồn kho (VND),
  sắp hết hàng, hết hàng — responsive 5/3/2/1 cột.
- Banner cảnh báo khi có sản phẩm low-stock / out-of-stock.
- Bảng "Giao dịch gần đây" (bảng trên desktop, card trên mobile) + nút "Xem tất cả".
- Loading, empty, error + retry; refresh thất bại không xóa dữ liệu cũ (hiện banner).

### 1.3 Quản lý sản phẩm (`/products`)

- Tìm theo tên/SKU (debounce 350 ms, nút xoá nhanh).
- Lọc danh mục; sắp xếp `createdAt | name | unitPrice | quantity` + hướng tăng/giảm.
- Phân trang `PaginationBar` (chuyển trang; khi trang rỗng tự lùi trang).
- Bảng 7 cột trên desktop (SKU, tên, danh mục, đơn giá, tồn, trạng thái, thao tác)
  và danh sách `ProductCard` trên mobile.
- Thêm/sửa sản phẩm qua dialog (`ProductFormDialog`):
  - SKU tự uppercase, validation khớp quy tắc trong server;
  - đơn giá (VND, số nguyên), mức tồn tối thiểu, mô tả ≤ 2.000 ký tự, ghi chú ≤ 500;
  - chưa có danh mục → cảnh báo + nút chuyển sang `/categories`;
  - lỗi server: `DUPLICATE_SKU` → lỗi tại ô SKU, `CATEGORY_NOT_FOUND` → lỗi tại
    dropdown, lỗi khác → banner chung.
- Xoá mềm qua hộp xác nhận (`ConfirmDialog`), lịch sử giao dịch được giữ lại theo thiết kế.
- Chỉ báo tồn kho: badge "Còn hàng / Sắp hết / Hết hàng" (`StockBadge`).

### 1.4 Chi tiết sản phẩm (`/products/:id`)

- Thẻ thông tin: SKU, tên, danh mục, đơn giá, mức tồn tối thiểu, ngày tạo.
- Thẻ tồn kho: số lượng lớn + `StockBadge`, thao tác nhanh **Nhập kho / Xuất kho**
  (`StockMovementDialog`: chọn trạng thái IN/OUT, số lượng, ghi chú, validate, lỗi rõ).
- Lịch sử 10 giao dịch gần nhất + nút "Xem tất cả" sang `/inventory?productId=N`.
- Chỉnh sửa sản phẩm ngay tại trang chi tiết; refresh sau khi lưu/giao dịch thành công.

### 1.5 Quản lý kho (`/inventory`)

- Form tạo giao dịch: chọn sản phẩm bằng `ProductPickerField` (dialog/bottom-sheet
  có ô tìm theo tên/SKU, badge tồn kho), chọn loại IN/OUT, số lượng, ghi chú.
- Chặn tủ client: xuất vượt tồn → báo lỗi trước khi gọi API.
- Lỗi server đã map tiếng Việt: `INSUFFICIENT_STOCK`, `PRODUCT_INACTIVE`
  (tự reload danh sách sản phẩm + lịch sử), lỗi form hiển thị banner đỏ.
- Sau thành công: clear form, Snackbar "Đã nhập/xuất N sản phẩm...", refresh
  inventory provider + dashboard provider.
- Lịch sử giao dịch: lọc theo sản phẩm + loại, nút xoá bộ lọc, bảng/card,
  phân trang, loading/empty/error + retry.

### 1.6 Danh mục (`/categories`)

- Card danh mục: icon, tên, số sản phẩm active, ngày tạo; click chuyển tới
  `/products?categoryId=N` (product list nhận query param và lọc sẵn).
- Thêm danh mục qua dialog, validation 1–100 ký tự, `CATEGORY_EXISTS`
  hiển thị ngay trên ô tên.
- Không triển khai sửa/xoá danh mục vì backend chưa có endpoint (đúng hợp đồng API).

### 1.7 API client & models

- `ApiClient`: `get/post/put/delete`, timeout 15 s, giải mã UTF-8, đọc envelope
  `{ data, meta }` và `{ error: { code, message, details } }`.
- `ApiException`: mã lỗi → tiếng Việt (DUPLICATE_SKU, CATEGORY_EXISTS,
  INSUFFICIENT_STOCK, PRODUCT_NOT_FOUND, PRODUCT_INACTIVE, FIELD_NOT_EDITABLE,
  VALIDATION_ERROR, DB_UNAVAILABLE, CORS_ORIGIN_DENIED, NETWORK_ERROR, TIMEOUT…),
  `fieldError(field)` giúp UI gán lỗi về đúng từng ô.
- Models (12): `Product`, `ProductInput`, `Category`, `InventoryTransaction`,
  `DashboardSummary`, `PaginationMeta`, `PaginatedResult<T>`, `StockProductSummary`,
  `StockMovementResult`, `StockStatus`, `TransactionType`, `json_utils`.
- AppConfig: `API_BASE_URL` qua `--dart-define`; mặc định dev là
  `http://localhost:3000`, mặc định release là origin hiện tại (hỗ trợ Render single-origin).

## 2. Danh sách file đã tạo / sửa

### Tạo mới

```
frontend/lib/app.dart, frontend/lib/main.dart
frontend/lib/core/config/app_config.dart
frontend/lib/core/network/api_client.dart, api_exception.dart
frontend/lib/core/router/app_router.dart
frontend/lib/core/theme/app_colors.dart, app_theme.dart
frontend/lib/core/utils/formatters.dart, json_utils.dart, validators.dart
frontend/lib/models/*.dart (12 files)
frontend/lib/services/*.dart (5 files)
frontend/lib/providers/*.dart (8 files)
frontend/lib/screens/shell/app_shell.dart, not_found_screen.dart
frontend/lib/screens/dashboard/dashboard_screen.dart
frontend/lib/screens/products/product_list_screen.dart, product_detail_screen.dart, product_form_dialog.dart
frontend/lib/screens/inventory/inventory_screen.dart
frontend/lib/screens/categories/categories_screen.dart
frontend/lib/widgets/*.dart (16 files)
frontend/test/*.dart (5 files)
frontend/tool/api_smoke_test.dart, crud_smoke_test.dart
frontend/README.md (nội dung mới)
PHASE4_HANDOVER.md (tài liệu này)
```

### Sửa

```
frontend/pubspec.yaml, frontend/pubspec.lock   # thêm provider/go_router/http/intl/…
IMPLEMENTATION_PLAN.md                         # header + phần Phase 4 + trạng thái cuối
```

### Không động vào

`backend/**`, `database/**`, `docs/API.md`, `backend/.env`, schema PostgreSQL,
seed data, hợp đồng API.

## 3. Kết quả kiểm thử (2026-11-04)

| Kiểm thử | Lệnh | Kết quả |
|---|---|---|
| Phân tích tĩnh | `flutter analyze` | **0 issue** |
| Unit + widget tests | `flutter test` | **24/24 passed** |
| Build release | `flutter build web --release` | **thành công** (~102 s, đã tree-shake icon font) |
| Backend + DB thật | `curl /api/health` | `{"database":"up"}`, HTTP 200 |
| Smoke API chỉ đọc | `flutter test tool/api_smoke_test.dart` | **7/7 passed** (health, categories, products + pagination, product detail, dashboard, inventory, PRODUCT_NOT_FOUND) |
| CRUD + tồn kho dữ liệu thật | `flutter test tool/crud_smoke_test.dart` | **2/2 passed** (create → edit → IN → OUT → quá bán bị chặn → soft delete; FIELD_NOT_EDITABLE bị chặn) |
| Duyệt UI trong trình duyệt | `flutter run` + trình duyệt desktop | **CHƯA XÁC MINH** — không có trình duyệt desktop kết nối trong phiên |

Chi tiết dữ liệu test CRUD thật (an toàn, có kiểm soát):

- Sinh 2 sản phẩm với SKU duy nhất có tiền tố `UIVERIFY-<timestamp>` và
  `UIVERIFYQ-<timestamp>`; sau kiểm xong đều **soft-delete** (lịch sử được giữ lại,
  không còn xuất hiện trên UI) — đúng thiết kế dự án.
- Không sửa/xoá bất kỳ bản ghi seed (12 sản phẩm, 5 danh mục).

## 4. Vấn đề đã biết & hạn chế

| # | Vấn đề | Trạng thái |
|---|---|---|
| 1 | Browser UI walkthrough (mọi luồng điều khiển qua HTML/DOM) chưa chạy | Chuyển sang Phase 5 |
| 2 | `DropdownButtonFormField` dùng `initialValue` (API mới Flutter 3.33+); đã dùng `key` tái tạo widget khi dữ liệu load để tránh assertion | Đã xử lý |
| 3 | Danh sách chọn sản phẩm (picker + lịch sử) tải tối đa 100 item active | Hợp lý cho demo; muốn nhiều hơn cần phân trang bên trong picker |
| 4 | Khi server trả HTTP không JSON, client báo `INVALID_RESPONSE` chung, không hiển thị mã HTTP | Nhỏ, chấp nhận được |
| 5 | Không có auth/rate-limit | Đúng đặc tả (educational prototype) |
| 6 | CORS từ origin `http://localhost:8080` → `:3000` chưa được xác minh trên trình duyệt thật | Cần Phase 5 |
| 7 | Build in một dòng cảnh báo `--wasm-dry-run` (không phải lỗi) | Không ảnh hưởng artifact |

## 5. Việc còn lại thuộc phạm vi Phase 5 (integration)

1. Chạy backend + `flutter run -d web-server` + trình duyệt thật, đi qua từng luồng:
   dashboard load, tìm/lọc/phân trang, thêm/sửa/xoá sản phẩm (dialog), chi tiết sản phẩm,
   nhập/xuất kho, lỗi tồn kho, thêm danh mục, layout mobile/desktop, chữ và tiền tệ
   tiếng Việt hiển thị đúng.
2. Kiểm tra CORS từ `localhost:8080` gọi `:3000` trong Network tab, và deep-link
   refresh (`/products/3`, `/inventory`) không 404.
3. Ghi kết quả vào `docs/TEST_PLAN.md` (deliverable của Phase 5).

## 6. Lệnh tiếp tục nhanh

```bash
# 1. Backend (chạy nền)
cd backend && npm start

# 2. Frontend dev (terminal riêng hoặc nền)
cd frontend
flutter run -d web-server --web-port 8080 --web-hostname 0.0.0.0 \
  --dart-define=API_BASE_URL=http://localhost:3000

# 3. Kiểm thử lại từ đầu
flutter analyze && flutter test
flutter test tool/api_smoke_test.dart          # cần backend
flutter test tool/crud_smoke_test.dart         # cần backend
flutter build web --release
```

## 7. Checklist sẵn sàng cho Phase 5

- [x] Tất cả màn hình Phase 4 đã code, qua phân tích và build release.
- [x] API client/test khớp `docs/API.md` khi đối chiếu thực tế (7/7 + 2/2).
- [x] Không dùng dữ liệu mock thay API thật trong code UI.
- [x] Không thay đổi schema/hợp đồng API/backend.
- [ ] Browser walkthrough từng luồng khi trình duyệt khả dụng.
- [ ] CORS + deep-link refresh + layout responsive trên trình duyệt thật.
- [ ] Ghi kết quả vào `docs/TEST_PLAN.md`.

**Gate: không bắt đầu Phase 5 / triển khai Render cho đến khi người dùng phê duyệt.**
