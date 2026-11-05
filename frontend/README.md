# Flutter Web Frontend — Inventory Management System

Frontend của dự án **Hệ thống quản lý kho hàng** (Cloud Computing). Ứng dụng Flutter Web
giao tiếp với API Node.js/Express đã có sẵn trong `../backend` và cơ sở dữ liệu
PostgreSQL thật (Render), **không** chứa dữ liệu mock và không có kết nối trực tiếp
đến CSDL.

## 1. Công nghệ

| Thành phần | Giá trị |
|---|---|
| Flutter | 3.47.2 stable (Dart 3.13.2) |
| State management | `provider` 6.x + `ChangeNotifier` |
| Navigation | `go_router` 18.x (path URL strategy) |
| HTTP | `http` 1.x, timeout 15 s, thể hiện `{ data }` / `{ error }` envelope |
| Định dạng | `intl` với dữ liệu locale `vi_VN` (tiền tệ VND, ngày, số) |
| UI | Material 3, giao diện sáng, chủ đạo xanh indigo, nội dung tiếng Việt |

## 2. Cài đặt

Yêu cầu: Flutter SDK 3.47+ (web enabled), Node.js 20+ để chạy backend.

```bash
cd frontend
flutter pub get
```

## 3. Cấu hình API 

Địa chỉ API được đọc từ `--dart-define` với biến **`API_BASE_URL`**
(mặc định khi thiếu: `http://localhost:3000` khi debug, hoặc origin hiện tại khi
release — để hỗ trợ triển khai một-origin trên Render):

```bash
# Local development (khuyến nghị)
flutter run -d web-server \
  --web-port 8080 --web-hostname 0.0.0.0 \
  --dart-define=API_BASE_URL=http://localhost:3000

# Build release trỏ tới Render (cấu trúc tên miền thay đổi sau Phase 6)
flutter build web --release --dart-define=API_BASE_URL=https://<your-service>.onrender.com
```

Không đặt `DATABASE_URL` hay thông tin CSDL bất kỳ đâu trong frontend — API client chỉ
nhận base URL của REST API, không có thông tin xác thực.

CORS backend đã cho phép mọi origin `http://localhost:*` / `http://127.0.0.1:*` khi
`NODE_ENV=development`.

## 4. Chạy backend

```bash
cd ../backend
npm install
npm start   # API tại http://localhost:3000 (biến PORT mặc định 3000)
```

## 5. Chạy frontend

```bash
cd frontend
flutter run -d web-server \
  --web-port 8080 --web-hostname 0.0.0.0 \
  --dart-define=API_BASE_URL=http://localhost:3000
```

Mở `http://localhost:8080` (deep link như `/products/3`, `/inventory` hỗ trợ URL path).

## 6. Kiểm thử

```bash
# Analyze + unit/test UI
flutter analyze
flutter test

# Kiểm hành API thật (backend phải đang chạy)
flutter test tool/api_smoke_test.dart       # chỉ đọc, không thay đổi dữ liệu
flutter test tool/crud_smoke_test.dart      # CRUD + tồn kho, dữ liệu test có xoá mềm

# Build để sản xuất
flutter build web --release
# Kết quả: build/web
```

Các test dưới `test/` chỉ dùng dữ liệu giả lập qua `MockClient`, không cần mạng.
Hai test trong `tool/` là "smoke test tích hợp" bắt buộc backend đang chạy.

## 7. Cấu trúc thư mục

```
lib/
  app.dart, main.dart                  # MaterialApp.router, locale vi_VN
  core/
    config/app_config.dart             # đọc API_BASE_URL, quyết định origin
    network/api_client.dart + api_exception.dart  # envelope, timeout, lỗi->tiếng Việt
    router/app_router.dart             # go_router, deep-link /products/:id
    theme/                             # AppTheme (Material 3), AppColors
    utils/                             # AppFormatters, AppValidators
  models/                              # Product, Category, InventoryTransaction...
  services/                            # REST calls cho từng domain
  providers/                           # state ChangeNotifier + global refresh
  screens/                             # shell, dashboard, products, inventory, categories
  widgets/                             # card, bảng, badge, trang phân trang, dialog...
test/                                  # unit + widget tests (không cần mạng)
tool/                                  # smoke test tích hợp cần backend thật
```

## 8. Hạn chế đã ghi nhận

- Kiểm thử bằng trình duyệt thực (uỷ quyền tới từng màn hình, mọi luồng CRUD qua UI)
  cần hội ngữ trình duyệt; được lên lịch cho Phase 5 (integration).
- Danh sách sản phẩm trong dropdown "Chọn sản phẩm"/"Lọc tồn kho" chỉ tải tối đa 100
  mục đang hoạt động (giới hạn hợp lý của demo; API cho phép tới 100).
- Auth, phân quyền, rate limiting không nằm trong phạm vi dự án.
- Sản phẩm bị soft-delete vẫn giữ lại trong lịch sử giao dịch (theo thiết kế).

Hạn chế chung của toàn dự án xem `../PROJECT_REQUIREMENTS.md`, chi tiết phần việc
chưa kiểm minh xem `../PHASE4_HANDOVER.md`.
