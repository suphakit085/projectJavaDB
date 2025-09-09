-- USERS & ROLES
CREATE TABLE users (
  id BIGSERIAL PRIMARY KEY,                   -- รหัสผู้ใช้ (primary key, auto increment)
  email CITEXT UNIQUE NOT NULL,               -- อีเมล (ไม่ซ้ำ, ไม่ case-sensitive)
  password_hash TEXT NOT NULL,                -- รหัสผ่านที่ถูกเข้ารหัส (hash)
  full_name TEXT,                             -- ชื่อ-นามสกุลเต็มของผู้ใช้
  is_active BOOLEAN DEFAULT TRUE,             -- สถานะการใช้งาน (true=ใช้งาน, false=ระงับ)
  created_at TIMESTAMPTZ DEFAULT now()        -- วันที่สร้างบัญชี
);

CREATE TABLE roles (
  id SMALLSERIAL PRIMARY KEY,                 -- รหัส role (primary key)
  name TEXT UNIQUE NOT NULL                   -- ชื่อ role เช่น buyer, seller, admin
);

CREATE TABLE user_roles (
  user_id BIGINT REFERENCES users(id) ON DELETE CASCADE,  -- ผู้ใช้ (foreign key)
  role_id SMALLINT REFERENCES roles(id) ON DELETE CASCADE, -- บทบาท (foreign key)
  PRIMARY KEY (user_id, role_id)             -- กำหนด primary key รวม (1 user มีหลาย role ได้)
);

-- ADDRESSES
CREATE TABLE addresses (
  id BIGSERIAL PRIMARY KEY,                   -- รหัสที่อยู่
  user_id BIGINT REFERENCES users(id) ON DELETE CASCADE, -- ผู้ใช้ที่เป็นเจ้าของที่อยู่
  label TEXT,                                 -- ชื่อเรียกที่อยู่ เช่น "บ้าน" หรือ "ที่ทำงาน"
  full_name TEXT,                             -- ชื่อผู้รับ
  phone TEXT,                                 -- เบอร์โทรผู้รับ
  line1 TEXT NOT NULL,                        -- ที่อยู่บรรทัดหลัก
  line2 TEXT,                                 -- ที่อยู่บรรทัดเสริม
  district TEXT,                              -- อำเภอ/เขต
  province TEXT,                              -- จังหวัด
  postal_code TEXT,                           -- รหัสไปรษณีย์
  country TEXT DEFAULT 'TH',                  -- ประเทศ (ค่า default=ไทย)
  is_default_shipping BOOLEAN DEFAULT FALSE,  -- ใช้เป็นที่อยู่จัดส่งหลักหรือไม่
  is_default_billing BOOLEAN DEFAULT FALSE    -- ใช้เป็นที่อยู่ออกบิลหลักหรือไม่
);

-- SELLER / SHOP
CREATE TABLE sellers (
  user_id BIGINT PRIMARY KEY REFERENCES users(id) ON DELETE CASCADE, -- ผู้ใช้ที่สมัครเป็นผู้ขาย
  status TEXT DEFAULT 'pending'               -- สถานะผู้ขาย (pending/approved/rejected)
);

CREATE TABLE shops (
  id BIGSERIAL PRIMARY KEY,                   -- รหัสร้านค้า
  seller_user_id BIGINT REFERENCES users(id) ON DELETE CASCADE, -- ผู้ใช้เจ้าของร้าน
  name TEXT NOT NULL,                         -- ชื่อร้านค้า
  slug TEXT UNIQUE NOT NULL,                  -- URL slug ของร้าน (ใช้ทำลิงก์ เช่น /shop/slug)
  status TEXT DEFAULT 'active',               -- สถานะร้าน (active/suspended)
  created_at TIMESTAMPTZ DEFAULT now()        -- วันที่เปิดร้าน
);

-- CATALOG
CREATE TABLE categories (
  id BIGSERIAL PRIMARY KEY,                   -- รหัสหมวดสินค้า
  name TEXT NOT NULL,                         -- ชื่อหมวดสินค้า
  slug TEXT UNIQUE NOT NULL,                  -- slug สำหรับ URL
  is_active BOOLEAN DEFAULT TRUE              -- ใช้งานหมวดนี้อยู่หรือไม่
);

CREATE TABLE products (
  id BIGSERIAL PRIMARY KEY,                   -- รหัสสินค้า
  shop_id BIGINT REFERENCES shops(id) ON DELETE CASCADE, -- ร้านที่ขายสินค้า
  category_id BIGINT REFERENCES categories(id), -- หมวดที่สินค้าอยู่
  title TEXT NOT NULL,                        -- ชื่อสินค้า
  slug TEXT UNIQUE NOT NULL,                  -- URL slug ของสินค้า
  status TEXT DEFAULT 'active',               -- สถานะสินค้า (active/draft/hidden)
  created_at TIMESTAMPTZ DEFAULT now()        -- วันที่สร้างสินค้า
);

CREATE TABLE product_variants (
  id BIGSERIAL PRIMARY KEY,                   -- รหัสตัวเลือกสินค้า (variant)
  product_id BIGINT REFERENCES products(id) ON DELETE CASCADE, -- สินค้าที่เป็นเจ้าของ
  sku TEXT UNIQUE NOT NULL,                   -- SKU (Stock Keeping Unit) ไม่ซ้ำ
  price NUMERIC(12,2) NOT NULL                -- ราคาขายของ variant
);

-- INVENTORY
CREATE TABLE inventories (
  id BIGSERIAL PRIMARY KEY,                   -- รหัสคลังสินค้า
  variant_id BIGINT UNIQUE REFERENCES product_variants(id) ON DELETE CASCADE, -- variant ที่ track สต็อก
  quantity_on_hand INTEGER NOT NULL DEFAULT 0, -- จำนวนคงเหลือจริง
  quantity_reserved INTEGER NOT NULL DEFAULT 0 -- จำนวนที่ถูกจอง (ยังไม่ส่งออก)
);

-- CART
CREATE TABLE carts (
  id BIGSERIAL PRIMARY KEY,                   -- รหัสตะกร้า
  user_id BIGINT UNIQUE REFERENCES users(id) ON DELETE CASCADE, -- ผู้ใช้ (1 คนมี 1 ตะกร้า)
  created_at TIMESTAMPTZ DEFAULT now(),       -- วันที่สร้างตะกร้า
  updated_at TIMESTAMPTZ DEFAULT now()        -- วันที่แก้ไขล่าสุด
);

CREATE TABLE cart_items (
  id BIGSERIAL PRIMARY KEY,                   -- รหัส item ในตะกร้า
  cart_id BIGINT REFERENCES carts(id) ON DELETE CASCADE, -- ตะกร้าที่ item สังกัด
  variant_id BIGINT REFERENCES product_variants(id), -- variant ที่ใส่ลงตะกร้า
  quantity INTEGER NOT NULL CHECK (quantity > 0), -- จำนวนสินค้าที่ใส่
  price_snapshot NUMERIC(12,2) NOT NULL       -- ราคาของ variant ตอนที่ใส่ลงตะกร้า
);

-- ORDER
CREATE TABLE orders (
  id BIGSERIAL PRIMARY KEY,                   -- รหัสคำสั่งซื้อ
  code TEXT UNIQUE NOT NULL,                  -- เลขออเดอร์ (unique)
  buyer_user_id BIGINT REFERENCES users(id),  -- ผู้ซื้อ
  status TEXT NOT NULL DEFAULT 'pending',     -- สถานะออเดอร์ (pending/paid/shipped)
  subtotal NUMERIC(12,2) NOT NULL DEFAULT 0,  -- ยอดรวมสินค้า (ก่อนค่าจัดส่ง)
  shipping_fee NUMERIC(12,2) NOT NULL DEFAULT 0, -- ค่าจัดส่ง
  grand_total NUMERIC(12,2) NOT NULL DEFAULT 0, -- ยอดสุทธิที่ต้องชำระ
  currency TEXT NOT NULL DEFAULT 'THB',       -- สกุลเงิน
  shipping_address_snapshot JSONB,            -- snapshot ที่อยู่จัดส่ง (ตอนซื้อ)
  created_at TIMESTAMPTZ DEFAULT now()        -- วันที่สร้างออเดอร์
);

CREATE TABLE order_items (
  id BIGSERIAL PRIMARY KEY,                   -- รหัสรายการสินค้าในออเดอร์
  order_id BIGINT REFERENCES orders(id) ON DELETE CASCADE, -- ออเดอร์ที่เป็นเจ้าของ
  shop_id BIGINT REFERENCES shops(id),        -- ร้านค้าที่ขาย
  variant_id BIGINT REFERENCES product_variants(id), -- variant ที่สั่ง
  unit_price NUMERIC(12,2) NOT NULL,          -- ราคาต่อชิ้น
  quantity INTEGER NOT NULL CHECK (quantity > 0), -- จำนวนชิ้น
  total NUMERIC(12,2) NOT NULL                -- ยอดรวม (unit_price * quantity)
);

-- PAYMENT
CREATE TABLE payments (
  id BIGSERIAL PRIMARY KEY,                   -- รหัสการชำระเงิน
  order_id BIGINT UNIQUE REFERENCES orders(id) ON DELETE CASCADE, -- ออเดอร์ที่จ่าย
  amount NUMERIC(12,2) NOT NULL,              -- จำนวนเงินที่จ่าย
  status TEXT NOT NULL,                       -- สถานะการชำระ (pending/paid/failed)
  paid_at TIMESTAMPTZ                         -- วันที่จ่ายสำเร็จ
);

-- SHIPMENT
CREATE TABLE shipments (
  id BIGSERIAL PRIMARY KEY,                   -- รหัสการจัดส่ง
  order_id BIGINT REFERENCES orders(id) ON DELETE CASCADE, -- ออเดอร์
  shop_id BIGINT REFERENCES shops(id),        -- ร้านที่จัดส่ง
  tracking_number TEXT,                       -- เลขติดตามพัสดุ
  status TEXT DEFAULT 'pending',              -- สถานะการส่ง (pending/shipped/delivered)
  shipped_at TIMESTAMPTZ,                     -- วันที่ส่งออก
  delivered_at TIMESTAMPTZ                    -- วันที่จัดส่งสำเร็จ
);
