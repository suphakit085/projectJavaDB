-- USERS & ROLES
CREATE TABLE users (
  id BIGSERIAL PRIMARY KEY,                   -- รหัสผู้ใช้ (Primary key, auto increment)
  email CITEXT UNIQUE NOT NULL,               -- อีเมล (แบบไม่ case-sensitive) ต้องไม่ซ้ำ
  password_hash TEXT NOT NULL,                -- รหัสผ่านที่ถูก hash แล้ว
  phone TEXT,                                 -- เบอร์โทรศัพท์ผู้ใช้
  full_name TEXT,                             -- ชื่อ-นามสกุลเต็มของผู้ใช้
  is_active BOOLEAN DEFAULT TRUE,             -- สถานะบัญชีใช้งานได้/ถูกระงับ
  created_at TIMESTAMPTZ DEFAULT now()        -- วันที่สร้างบัญชี
);

CREATE TABLE roles (
  id SMALLSERIAL PRIMARY KEY,                 -- รหัส role เช่น buyer/seller/admin
  name TEXT UNIQUE NOT NULL                   -- ชื่อ role (buyer, seller, admin)
);

CREATE TABLE user_roles (
  user_id BIGINT REFERENCES users(id) ON DELETE CASCADE, -- ผู้ใช้ (FK)
  role_id SMALLINT REFERENCES roles(id) ON DELETE CASCADE, -- role (FK)
  PRIMARY KEY (user_id, role_id)             -- 1 user อาจมีหลาย role
);

CREATE TABLE addresses (
  id BIGSERIAL PRIMARY KEY,                   -- รหัสที่อยู่
  user_id BIGINT REFERENCES users(id) ON DELETE CASCADE, -- ผู้ใช้ที่เป็นเจ้าของที่อยู่
  label TEXT,                                 -- ป้ายชื่อ เช่น "บ้าน", "ที่ทำงาน"
  full_name TEXT,                             -- ชื่อผู้รับ
  phone TEXT,                                 -- เบอร์โทรผู้รับ
  line1 TEXT NOT NULL,                        -- ที่อยู่บรรทัดหลัก
  line2 TEXT,                                 -- ที่อยู่บรรทัดเสริม
  district TEXT,                              -- อำเภอ/เขต
  province TEXT,                              -- จังหวัด
  postal_code TEXT,                           -- รหัสไปรษณีย์
  country TEXT DEFAULT 'TH',                  -- ประเทศ (ค่าเริ่มต้นไทย)
  is_default_shipping BOOLEAN DEFAULT FALSE,  -- เป็นที่อยู่จัดส่งหลักไหม
  is_default_billing  BOOLEAN DEFAULT FALSE   -- เป็นที่อยู่ออกใบเสร็จหลักไหม
);

-- SELLER & SHOP
CREATE TABLE sellers (
  user_id BIGINT PRIMARY KEY REFERENCES users(id) ON DELETE CASCADE, -- ผู้ใช้ที่เป็น seller
  national_id TEXT,                           -- เลขบัตรประชาชน/ภาษี
  bank_account TEXT,                          -- เลขบัญชีธนาคาร
  status TEXT DEFAULT 'pending',              -- สถานะการยืนยัน (pending/verified/rejected)
  verified_at TIMESTAMPTZ                     -- วันที่ยืนยันตัวตน
);

CREATE TABLE shops (
  id BIGSERIAL PRIMARY KEY,                   -- รหัสร้านค้า
  seller_user_id BIGINT REFERENCES users(id) ON DELETE CASCADE, -- ผู้ใช้เจ้าของร้าน
  name TEXT NOT NULL,                         -- ชื่อร้าน
  slug TEXT UNIQUE NOT NULL,                  -- URL slug ของร้าน (ใช้ในลิงก์)
  logo_url TEXT,                              -- URL โลโก้ร้าน
  description TEXT,                           -- รายละเอียดร้าน
  status TEXT DEFAULT 'active',               -- สถานะร้าน (active/suspended)
  created_at TIMESTAMPTZ DEFAULT now()        -- วันที่เปิดร้าน
);

-- CATALOG
CREATE TABLE categories (
  id BIGSERIAL PRIMARY KEY,                   -- รหัสหมวดสินค้า
  parent_id BIGINT REFERENCES categories(id), -- หมวดพ่อ (ทำ tree)
  name TEXT NOT NULL,                         -- ชื่อหมวด
  slug TEXT UNIQUE NOT NULL,                  -- URL slug ของหมวด
  path TEXT,                                  -- path hierarchy เช่น /electronics/phones
  is_active BOOLEAN DEFAULT TRUE              -- เปิดใช้งานหมวดนี้หรือไม่
);

CREATE TABLE products (
  id BIGSERIAL PRIMARY KEY,                   -- รหัสสินค้า
  shop_id BIGINT REFERENCES shops(id) ON DELETE CASCADE, -- ร้านที่ขาย
  category_id BIGINT REFERENCES categories(id), -- หมวดสินค้า
  title TEXT NOT NULL,                        -- ชื่อสินค้า
  slug TEXT UNIQUE NOT NULL,                  -- URL slug ของสินค้า
  description TEXT,                           -- รายละเอียดสินค้า
  brand TEXT,                                 -- ยี่ห้อ
  status TEXT DEFAULT 'active',               -- สถานะสินค้า (active/draft/deleted)
  rating_avg NUMERIC(3,2) DEFAULT 0,          -- คะแนนรีวิวเฉลี่ย
  rating_count INTEGER DEFAULT 0,             -- จำนวนรีวิว
  created_at TIMESTAMPTZ DEFAULT now()        -- วันที่สร้าง
);

CREATE TABLE product_variants (
  id BIGSERIAL PRIMARY KEY,                   -- รหัส variant
  product_id BIGINT REFERENCES products(id) ON DELETE CASCADE, -- สินค้าหลัก
  sku TEXT UNIQUE NOT NULL,                   -- SKU ไม่ซ้ำ
  option_json JSONB,                          -- ข้อมูลตัวเลือก เช่น {"color":"Black","size":"M"}
  price NUMERIC(12,2) NOT NULL,               -- ราคาขาย
  compare_at_price NUMERIC(12,2),             -- ราคาก่อนลด (ถ้ามี)
  weight_gram INTEGER,                        -- น้ำหนัก
  barcode TEXT                                -- บาร์โค้ด (EAN/UPC)
);

CREATE TABLE product_images (
  id BIGSERIAL PRIMARY KEY,                   -- รหัสรูป
  product_id BIGINT REFERENCES products(id) ON DELETE CASCADE, -- สินค้าที่เกี่ยวข้อง
  url TEXT NOT NULL,                          -- URL รูป
  sort_order INTEGER DEFAULT 0,               -- ลำดับการแสดง
  alt_text TEXT                               -- คำอธิบายรูป (alt)
);

CREATE TABLE inventories (
  id BIGSERIAL PRIMARY KEY,                   -- รหัส inventory
  variant_id BIGINT UNIQUE REFERENCES product_variants(id) ON DELETE CASCADE, -- variant ที่ track stock
  quantity_on_hand INTEGER NOT NULL DEFAULT 0, -- จำนวนคงเหลือจริง
  quantity_reserved INTEGER NOT NULL DEFAULT 0, -- จำนวนที่ถูกจอง
  low_stock_threshold INTEGER DEFAULT 0       -- จำนวนต่ำสุดที่ถือว่า stock ต่ำ
);

-- CART
CREATE TABLE carts (
  id BIGSERIAL PRIMARY KEY,                   -- รหัสตะกร้า
  user_id BIGINT UNIQUE REFERENCES users(id) ON DELETE CASCADE, -- เจ้าของตะกร้า (1 คน 1 ตะกร้า)
  created_at TIMESTAMPTZ DEFAULT now(),       -- วันที่สร้าง
  updated_at TIMESTAMPTZ DEFAULT now()        -- วันที่แก้ไขล่าสุด
);

CREATE TABLE cart_items (
  id BIGSERIAL PRIMARY KEY,                   -- รหัส item ในตะกร้า
  cart_id BIGINT REFERENCES carts(id) ON DELETE CASCADE, -- ตะกร้า
  variant_id BIGINT REFERENCES product_variants(id), -- variant ที่ใส่ในตะกร้า
  quantity INTEGER NOT NULL CHECK (quantity > 0), -- จำนวน
  price_snapshot NUMERIC(12,2) NOT NULL       -- ราคาตอนใส่ลงตะกร้า
);

-- ORDER
CREATE TABLE orders (
  id BIGSERIAL PRIMARY KEY,                   -- รหัสคำสั่งซื้อ
  code TEXT UNIQUE NOT NULL,                  -- เลขที่ออเดอร์
  buyer_user_id BIGINT REFERENCES users(id),  -- ผู้ซื้อ
  status TEXT NOT NULL DEFAULT 'pending',     -- สถานะ order
  subtotal NUMERIC(12,2) NOT NULL DEFAULT 0,  -- ราคารวมสินค้าก่อนส่วนลด
  shipping_fee NUMERIC(12,2) NOT NULL DEFAULT 0, -- ค่าจัดส่ง
  discount_total NUMERIC(12,2) NOT NULL DEFAULT 0, -- ส่วนลดรวม
  tax_total NUMERIC(12,2) NOT NULL DEFAULT 0, -- ภาษี
  platform_fee NUMERIC(12,2) NOT NULL DEFAULT 0, -- ค่าธรรมเนียมแพลตฟอร์ม
  grand_total NUMERIC(12,2) NOT NULL DEFAULT 0, -- ยอดสุทธิ
  currency TEXT NOT NULL DEFAULT 'THB',       -- สกุลเงิน
  shipping_address_snapshot JSONB,            -- snapshot ที่อยู่จัดส่ง
  billing_address_snapshot JSONB,             -- snapshot ที่อยู่ออกใบเสร็จ
  created_at TIMESTAMPTZ DEFAULT now()        -- วันที่สร้าง order
);

CREATE TABLE order_items (
  id BIGSERIAL PRIMARY KEY,                   -- รหัสรายการสินค้าใน order
  order_id BIGINT REFERENCES orders(id) ON DELETE CASCADE, -- ออเดอร์ที่เกี่ยวข้อง
  shop_id BIGINT REFERENCES shops(id),        -- ร้านที่ขาย
  product_id BIGINT REFERENCES products(id),  -- สินค้าหลัก
  variant_id BIGINT REFERENCES product_variants(id), -- variant
  title_snapshot TEXT NOT NULL,               -- ชื่อ snapshot สินค้า
  sku_snapshot TEXT,                          -- SKU snapshot
  unit_price NUMERIC(12,2) NOT NULL,          -- ราคาต่อชิ้น
  quantity INTEGER NOT NULL CHECK (quantity > 0), -- จำนวน
  discount_amount NUMERIC(12,2) NOT NULL DEFAULT 0, -- ส่วนลด
  tax_amount NUMERIC(12,2) NOT NULL DEFAULT 0, -- ภาษี
  total NUMERIC(12,2) NOT NULL,               -- ยอดรวม
  status TEXT DEFAULT 'pending'               -- สถานะ item
);

-- PAYMENTS / SHIPMENTS / REFUNDS
CREATE TABLE payments (
  id BIGSERIAL PRIMARY KEY,                   -- รหัสการชำระเงิน
  order_id BIGINT UNIQUE REFERENCES orders(id) ON DELETE CASCADE, -- ออเดอร์
  provider TEXT,                              -- ผู้ให้บริการ เช่น Stripe/Omise
  method TEXT,                                -- วิธี เช่น credit_card/promptpay
  txn_id TEXT UNIQUE,                         -- หมายเลขอ้างอิงธุรกรรม
  amount NUMERIC(12,2) NOT NULL,              -- จำนวนเงิน
  status TEXT NOT NULL,                       -- สถานะการจ่าย
  paid_at TIMESTAMPTZ,                        -- เวลาที่จ่ายเสร็จ
  raw_payload JSONB                           -- raw data จาก provider
);

CREATE TABLE shipments (
  id BIGSERIAL PRIMARY KEY,                   -- รหัสการจัดส่ง
  order_id BIGINT REFERENCES orders(id) ON DELETE CASCADE, -- ออเดอร์
  shop_id BIGINT REFERENCES shops(id),        -- ร้านที่จัดส่ง
  carrier TEXT,                               -- บริษัทขนส่ง
  tracking_number TEXT,                       -- เลขพัสดุ
  status TEXT DEFAULT 'pending',              -- สถานะการจัดส่ง
  shipped_at TIMESTAMPTZ,                     -- เวลาที่ส่ง
  delivered_at TIMESTAMPTZ,                   -- เวลาที่ถึง
  shipping_label_url TEXT                     -- URL ใบปะหน้าพัสดุ
);

CREATE UNIQUE INDEX uniq_order_shop_shipment ON shipments(order_id, shop_id); -- จำกัด 1 order ต่อร้านมี shipment เดียว

CREATE TABLE refunds (
  id BIGSERIAL PRIMARY KEY,                   -- รหัสการคืนเงิน
  order_id BIGINT REFERENCES orders(id) ON DELETE CASCADE, -- ออเดอร์
  payment_id BIGINT REFERENCES payments(id) ON DELETE SET NULL, -- การจ่ายที่เกี่ยวข้อง
  amount NUMERIC(12,2) NOT NULL,              -- จำนวนเงินคืน
  reason TEXT,                                -- เหตุผลการคืนเงิน
  status TEXT DEFAULT 'pending',              -- สถานะการคืนเงิน
  created_at TIMESTAMPTZ DEFAULT now()        -- วันที่สร้าง
);

-- COUPONS / DISCOUNTS
CREATE TABLE coupons (
  id BIGSERIAL PRIMARY KEY,                   -- รหัสคูปอง
  code TEXT UNIQUE NOT NULL,                  -- รหัสคูปอง
  type TEXT NOT NULL,                         -- ประเภท (percent/fixed)
  value NUMERIC(12,2) NOT NULL,               -- มูลค่า
  starts_at TIMESTAMPTZ,                      -- วันเริ่มใช้
  ends_at TIMESTAMPTZ,                        -- วันหมดอายุ
  usage_limit INTEGER,                        -- จำนวนครั้งใช้สูงสุด
  usage_count INTEGER DEFAULT 0,              -- จำนวนครั้งที่ถูกใช้ไป
  min_order_amount NUMERIC(12,2) DEFAULT 0,   -- ยอดขั้นต่ำ
  applicable_shop_id BIGINT REFERENCES shops(id) -- ใช้กับร้านเฉพาะ (nullable)
);

CREATE TABLE order_discounts (
  id BIGSERIAL PRIMARY KEY,                   -- รหัสส่วนลดใน order
  order_id BIGINT REFERENCES orders(id) ON DELETE CASCADE, -- ออเดอร์
  coupon_id BIGINT REFERENCES coupons(id),    -- คูปอง
  amount_applied NUMERIC(12,2) NOT NULL,      -- มูลค่าที่ใช้จริง
  description TEXT                            -- คำอธิบายส่วนลด
);

-- REVIEWS
CREATE TABLE reviews (
  id BIGSERIAL PRIMARY KEY,                   -- รหัสรีวิว
  order_item_id BIGINT UNIQUE REFERENCES order_items(id) ON DELETE SET NULL, -- อ้างกับสินค้าในออเดอร์
  product_id BIGINT REFERENCES products(id),  -- สินค้าที่รีวิว
  user_id BIGINT REFERENCES users(id),        -- ผู้รีวิว
  rating INTEGER CHECK (rating BETWEEN 1 AND 5), -- คะแนน
  title TEXT,                                 -- หัวข้อ
  body TEXT,                                  -- เนื้อหา
  images JSONB,                               -- รูปรีวิว
  is_approved BOOLEAN DEFAULT FALSE,          -- แอดมินอนุมัติไหม
  created_at TIMESTAMPTZ DEFAULT now()        -- วันที่รีวิว
);

-- COMMISSION & PAYOUT
CREATE TABLE commission_rules (
  id BIGSERIAL PRIMARY KEY,                   -- รหัสกติกาคอมมิชชัน
  shop_id BIGINT REFERENCES shops(id),        -- ร้านที่ใช้กติกานี้
  rate_percent NUMERIC(5,2) DEFAULT 5.00,     -- เปอร์เซ็นต์ค่าคอม
  fixed_fee NUMERIC(12,2) DEFAULT 0,          -- ค่าธรรมเนียมคงที่
  effective_from DATE,                        -- เริ่มมีผล
  effective_to DATE                           -- หมดอายุ
);

CREATE TABLE payouts (
  id BIGSERIAL PRIMARY KEY,                   -- รหัสการจ่ายเงินให้ร้าน
  shop_id BIGINT REFERENCES shops(id),        -- ร้าน
  period_start DATE,                          -- รอบจ่ายเริ่ม
  period_end DATE,                            -- รอบจ่ายสิ้นสุด
  sales_amount NUMERIC(12,2) NOT NULL DEFAULT 0, -- ยอดขาย
  commission_amount NUMERIC(12,2) NOT NULL DEFAULT 0, -- ค่าคอม
  refund_amount NUMERIC(12,2) NOT NULL DEFAULT 0, -- ยอดคืนเงิน
  payout_amount NUMERIC(12,2) NOT NULL DEFAULT 0, -- ยอดที่โอนจริง
  status TEXT DEFAULT 'pending',              -- สถานะการจ่าย
  paid_at TIMESTAMPTZ,                        -- เวลาที่จ่ายแล้ว
  slip_url TEXT                               -- URL สลิปโอน
);

-- AUDIT
CREATE TABLE audit_logs (
  id BIGSERIAL PRIMARY KEY,                   -- รหัส log
  actor_user_id BIGINT REFERENCES users(id),  -- ผู้กระทำ
  action TEXT NOT NULL,                       -- การกระทำ เช่น update_product
  entity_type TEXT,                           -- ประเภท entity เช่น "product"
  entity_id BIGINT,                           -- id ของ entity
  diff JSONB,                                 -- ข้อมูลก่อน/หลังการแก้ไข
  ip INET,                                    -- IP address
  created_at TIMESTAMPTZ DEFAULT now()        -- วันที่บันทึก
);