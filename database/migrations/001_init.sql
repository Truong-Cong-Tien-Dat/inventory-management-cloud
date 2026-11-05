-- Inventory Management System — initial schema.
-- PostgreSQL 16+ (verified against PostgreSQL 18 on Render).
-- Applying this file twice is safe: objects are created only when missing.

BEGIN;

CREATE EXTENSION IF NOT EXISTS pg_trgm;

CREATE TABLE IF NOT EXISTS categories (
  id          BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  name        VARCHAR(100) NOT NULL,
  created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  CONSTRAINT categories_name_unique UNIQUE (name),
  CONSTRAINT categories_name_not_blank CHECK (btrim(name) <> '')
);

CREATE TABLE IF NOT EXISTS products (
  id             BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  sku            VARCHAR(50) NOT NULL,
  name           VARCHAR(200) NOT NULL,
  category_id    BIGINT NOT NULL,
  description    TEXT NULL,
  unit_price     NUMERIC(12,2) NOT NULL,
  quantity       INTEGER NOT NULL DEFAULT 0,
  reorder_level  INTEGER NOT NULL DEFAULT 5,
  is_active      BOOLEAN NOT NULL DEFAULT TRUE,
  created_at     TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at     TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  CONSTRAINT products_sku_unique UNIQUE (sku),
  CONSTRAINT products_category_fk FOREIGN KEY (category_id)
    REFERENCES categories(id) ON DELETE RESTRICT,
  CONSTRAINT products_unit_price_nonnegative CHECK (unit_price >= 0),
  CONSTRAINT products_quantity_nonnegative CHECK (quantity >= 0),
  CONSTRAINT products_reorder_level_nonnegative CHECK (reorder_level >= 0),
  CONSTRAINT products_sku_not_blank CHECK (btrim(sku) <> ''),
  CONSTRAINT products_name_not_blank CHECK (btrim(name) <> '')
);

CREATE TABLE IF NOT EXISTS inventory_transactions (
  id          BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  product_id  BIGINT NOT NULL,
  type        VARCHAR(10) NOT NULL,
  quantity    INTEGER NOT NULL,
  note        TEXT NULL,
  created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  CONSTRAINT inventory_product_fk FOREIGN KEY (product_id)
    REFERENCES products(id) ON DELETE RESTRICT,
  CONSTRAINT inventory_type_valid CHECK (type IN ('IN', 'OUT')),
  CONSTRAINT inventory_quantity_positive CHECK (quantity > 0)
);

-- Case-insensitive SKU uniqueness in addition to the column constraint.
CREATE UNIQUE INDEX IF NOT EXISTS products_sku_upper_unique
  ON products (UPPER(sku));

-- Category names are unique regardless of letter case.
CREATE UNIQUE INDEX IF NOT EXISTS categories_name_lower_unique
  ON categories (LOWER(name));

-- Product list/search/filter indexes.
CREATE INDEX IF NOT EXISTS products_category_idx
  ON products (category_id);
CREATE INDEX IF NOT EXISTS products_active_created_idx
  ON products (is_active, created_at DESC, id DESC);
CREATE INDEX IF NOT EXISTS products_name_trgm_idx
  ON products USING GIN (name gin_trgm_ops);
CREATE INDEX IF NOT EXISTS products_sku_trgm_idx
  ON products USING GIN (sku gin_trgm_ops);

-- Transaction history indexes.
CREATE INDEX IF NOT EXISTS transactions_product_created_idx
  ON inventory_transactions (product_id, created_at DESC, id DESC);
CREATE INDEX IF NOT EXISTS transactions_created_idx
  ON inventory_transactions (created_at DESC, id DESC);
CREATE INDEX IF NOT EXISTS transactions_type_idx
  ON inventory_transactions (type);

-- Maintain products.updated_at on every update. clock_timestamp() is used
-- instead of NOW() so an update in the same transaction as an insert still
-- gets a later timestamp.
CREATE OR REPLACE FUNCTION set_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = clock_timestamp();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS products_set_updated_at ON products;
CREATE TRIGGER products_set_updated_at
  BEFORE UPDATE ON products
  FOR EACH ROW
  EXECUTE FUNCTION set_updated_at();

COMMENT ON TABLE categories IS 'Product categories.';
COMMENT ON TABLE products IS 'Products; inventory history is preserved on soft delete.';
COMMENT ON COLUMN products.is_active IS 'FALSE means soft-deleted; hidden from normal queries.';
COMMENT ON TABLE inventory_transactions IS 'Append-only stock-in/stock-out history.';

COMMIT;
