# TEST PLAN & RESULTS — Inventory Management System

> Cập nhật: 2026-11-05 (Phase 5). Chi tiết đầy đủ: `../PHASE5_HANDOVER.md`.

## 1. Ma trận kiểm thử đã thực hiện

| Lớp | Bộ kiểm thử | Lệnh | Kết quả lần chạy 2026-11-05 |
|---|---|---|---|
| Database structural | Verify schema + seed | `cd backend && npm run db:verify` | 15/15 pass |
| Backend unit/integration | vitest (products, categories, inventory, dashboard, health, concurrency) | `cd backend && npm test` | 32/32 pass |
| Backend e2e smoke | Tác lập record tách biệt, tự dọn | `API_BASE_URL=http://localhost:3000 npm run smoke` | 10/10 pass |
| Frontend static | `flutter analyze` | `cd frontend && flutter analyze` | 0 issue |
| Frontend unit/widget/API-client | MockClient, không cần mạng | `cd frontend && flutter test` | 27/27 pass |
| Frontend responsive shell | Widget test 1440/768/390 px | nằm trong `flutter test` (`test/responsive_shell_test.dart`) | 3/3 pass |
| Frontend ↔ API contract (read-only) | Services của UI gọi backend thật | `flutter test tool/api_smoke_test.dart` | 7/7 pass |
| Frontend CRUD + inventory (reversible) | Tạo/sửa/IN/OUT/chặn quá bán/xoá mềm, tự dọn | `flutter test tool/crud_smoke_test.dart` | 2/2 pass |
| Release build | `flutter build web --release` | | Thành công (~115 s) |
| CORS server-side | curl preflight + GET với `Origin: http://localhost:8080` | xem `PHASE5_HANDOVER.md` §2.2 | Pass (204/echo origin; origin lạ 403) |
| SPA deep-link (dev) | `curl /products/3`, `/inventory`, `/categories` | | HTTP 200 toàn bộ |

## 2. Phạm vi chưa xác minh bằng trình duyệt

Môi trường không có trình duyệt automation (không desktop browser, không Chrome binary).
Các luồng UI cần quan sát bằng mắt được liệt kê trong `../PHASE5_HANDOVER.md` §5
(checklist 12 mục) và **không được tuyên bố là đã pass**.

## 3. Kịch bản P0 bắt buộc (đối chiếu PROJECT_REQUIREMENTS §1.1)

1. Quản lý sản phẩm (list/create/view/edit/soft-delete) — pass ở mức API + service.
2. Tìm kiếm theo tên/SKU, lọc danh mục, phân trang — pass ở mức API + backend tests.
3. Nhập/xuất kho atomic, lịch sử, chặn xuất khi không đủ tồn (kể cả concurrent) — pass.

## 4. Quy tắc dữ liệu kiểm thử

- Chỉ tạo record với tiền tố duy nhất (`UIVERIFY-*`, smoke test tự sinh).
- Sản phẩm test kết thúc bằng soft-delete; lịch sử giữ lại theo thiết kế.
- Không sửa/xoá seed data (12 sản phẩm, 5 danh mục); không truy cập CSDL trực tiếp
  từ frontend; mọi thao tác dữ liệu qua REST API của backend.
