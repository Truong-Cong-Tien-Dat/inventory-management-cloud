-- Inventory Management System — development/demo seed data.
-- Idempotent: if products already exist, no product data is inserted again.
-- Quantities are internally consistent: quantity = SUM(IN) - SUM(OUT).
-- This file is intended for development/demo databases only.

BEGIN;

INSERT INTO categories (name) VALUES
  ('Thiết bị điện tử'),
  ('Văn phòng phẩm'),
  ('Nội thất'),
  ('Phụ kiện'),
  ('Lưu trữ')
ON CONFLICT DO NOTHING;

CREATE TEMP TABLE seed_products (
  sku             VARCHAR(50) PRIMARY KEY,
  name            VARCHAR(200) NOT NULL,
  category_name   VARCHAR(100) NOT NULL,
  description     TEXT,
  unit_price      NUMERIC(12,2) NOT NULL,
  reorder_level   INTEGER NOT NULL,
  initial_in      INTEGER NOT NULL,
  out_qty         INTEGER NOT NULL,
  in_days_ago     INTEGER NOT NULL,
  out_days_ago    INTEGER NOT NULL
) ON COMMIT DROP;

INSERT INTO seed_products (
  sku, name, category_name, description, unit_price,
  reorder_level, initial_in, out_qty, in_days_ago, out_days_ago
) VALUES
  ('ELEC-001', 'Bàn phím cơ Keychron K2', 'Thiết bị điện tử',
   'Bàn phím cơ không dây, layout 75%, switch Brown.', 1890000, 5, 40, 12, 45, 6),
  ('ELEC-002', 'Chuột không dây Logitech M331', 'Thiết bị điện tử',
   'Chuột silent không dây, kết nối USB receiver.', 590000, 8, 30, 27, 40, 3),
  ('ELEC-003', 'Màn hình Dell 24 inch', 'Thiết bị điện tử',
   'Màn hình IPS Full HD 24 inch, cổng HDMI và DisplayPort.', 3290000, 4, 25, 25, 38, 4),
  ('ELEC-004', 'Tai nghe Bluetooth Sony WH-CH520', 'Thiết bị điện tử',
   'Tai nghe on-ear Bluetooth, thời lượng pin 50 giờ.', 1250000, 6, 18, 14, 35, 2),
  ('OFF-001', 'Giấy A4 Double A 70gsm', 'Văn phòng phẩm',
   'Giấy in A4 định lượng 70gsm, 500 tờ/ream.', 85000, 20, 120, 55, 30, 1),
  ('OFF-002', 'Bút bi Thiên Long TL-027', 'Văn phòng phẩm',
   'Bút bi mực xanh, đầu bi 0.7mm.', 6500, 50, 300, 120, 30, 1),
  ('FURN-001', 'Ghế văn phòng lưới', 'Nội thất',
   'Ghế xoay lưới, tựa đầu, tay vịn điều chỉnh.', 2450000, 3, 15, 4, 28, 7),
  ('FURN-002', 'Bàn làm việc 1m4', 'Nội thất',
   'Bàn làm việc gỗ công nghiệp, kích thước 140x60cm.', 3150000, 3, 10, 8, 28, 5),
  ('ACC-001', 'Balo laptop 15.6 inch', 'Phụ kiện',
   'Balo chống sốc, ngăn laptop 15.6 inch, cổng USB.', 890000, 5, 50, 22, 25, 8),
  ('ACC-002', 'Đế tản nhiệt laptop', 'Phụ kiện',
   'Đế tản nhiệt 5 quạt, đèn LED, điều chỉnh độ cao.', 450000, 6, 20, 15, 25, 6),
  ('STOR-001', 'Kệ sắt 5 tầng', 'Lưu trữ',
   'Kệ sắt để kho, 5 tầng, tải trọng 80kg/tầng.', 1750000, 4, 25, 7, 22, 9),
  ('STOR-002', 'Hộp tài liệu A4', 'Lưu trữ',
   'Hộp nhựa đựng tài liệu A4, có nắp đậy.', 120000, 10, 80, 30, 20, 10);

DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM products) THEN
    INSERT INTO products (
      sku, name, category_id, description, unit_price,
      quantity, reorder_level, created_at, updated_at
    )
    SELECT
      s.sku,
      s.name,
      c.id,
      s.description,
      s.unit_price,
      0,
      s.reorder_level,
      NOW() - make_interval(days => s.in_days_ago + 1),
      NOW() - make_interval(days => s.in_days_ago + 1)
    FROM seed_products s
    JOIN categories c ON c.name = s.category_name
    ON CONFLICT (sku) DO NOTHING;

    INSERT INTO inventory_transactions (product_id, type, quantity, note, created_at)
    SELECT
      p.id,
      'IN',
      s.initial_in,
      'Nhập hàng đợt đầu',
      NOW() - make_interval(days => s.in_days_ago)
    FROM seed_products s
    JOIN products p ON p.sku = s.sku;

    INSERT INTO inventory_transactions (product_id, type, quantity, note, created_at)
    SELECT
      p.id,
      'OUT',
      s.out_qty,
      'Xuất bán đơn demo',
      NOW() - make_interval(days => s.out_days_ago)
    FROM seed_products s
    JOIN products p ON p.sku = s.sku
    WHERE s.out_qty > 0;

    UPDATE products p
    SET quantity = s.initial_in - s.out_qty
    FROM seed_products s
    WHERE p.sku = s.sku;
  END IF;
END $$;

COMMIT;
