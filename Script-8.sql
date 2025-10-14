------------------------------------------------------------
-- 1) Ürün Aktif mi?
-- Amaç: Verilen ürünün satışta (discontinued=false) olup olmadığını döndürür.
-- Kullanılan tablo: products
-- Parametre: p_product_id INT
-- Dönüş: BOOLEAN (ürün yoksa NULL)
-- LANGUAGE sql: çünkü yalnızca SELECT sorgusu içeriyor, kontrol yapısı yok.
------------------------------------------------------------
CREATE OR REPLACE FUNCTION nw_is_product_active(p_product_id INT)
RETURNS BOOLEAN
LANGUAGE sql
AS $$
    SELECT discontinued = false
    FROM products
    WHERE productid = p_product_id;
$$;

-- Testler:
-- SELECT nw_is_product_active(1);  -- Ürün aktifse TRUE, değilse FALSE
-- SELECT nw_is_product_active(9999); -- Olmayan ürün -> NULL


------------------------------------------------------------
-- 2) Tedarikçi Ürün Sayısı
-- Amaç: Bir tedarikçinin kaç ürünü olduğunu döndürür.
-- Kullanılan tablo: products
-- Parametre: p_supplier_id INT
-- Dönüş: INT (tedarikçi yoksa 0)
-- LANGUAGE sql: tek sorgu, toplama işlemi.
------------------------------------------------------------
CREATE OR REPLACE FUNCTION nw_supplier_product_count(p_supplier_id INT)
RETURNS INT
LANGUAGE sql
AS $$
    SELECT COUNT(*) 
    FROM products
    WHERE supplierid = p_supplier_id;
$$;

-- Testler:
-- SELECT nw_supplier_product_count(1); -- Gerçek tedarikçi -> >0 değer
-- SELECT nw_supplier_product_count(9999); -- Yoksa 0


------------------------------------------------------------
-- 3) Müşterinin Yıllık Sipariş Adedi
-- Amaç: Müşterinin belirtilen yıldaki sipariş sayısı.
-- Kullanılan tablo: orders
-- Parametre: p_customer_id TEXT, p_year INT
-- Dönüş: INT
-- LANGUAGE sql: basit toplama.
------------------------------------------------------------
CREATE OR REPLACE FUNCTION nw_customer_order_count(p_customer_id TEXT, p_year INT)
RETURNS INT
LANGUAGE sql
AS $$
    SELECT COUNT(*) 
    FROM orders
    WHERE customerid = p_customer_id
      AND DATE_PART('year', orderdate) = p_year;
$$;

-- Testler:
-- SELECT nw_customer_order_count('ALFKI', 1997); -- ≥1 sipariş beklenir
-- SELECT nw_customer_order_count('AAAAA', 1997); -- 0


------------------------------------------------------------
-- 4) Müşterinin Son Sipariş Tarihi
-- Amaç: Belirtilen müşterinin en son sipariş tarihini döndürür.
-- Kullanılan tablo: orders
-- Dönüş: DATE (sipariş yoksa NULL)
-- LANGUAGE sql: tek sorgu, MAX fonksiyonu.
------------------------------------------------------------
CREATE OR REPLACE FUNCTION nw_customer_last_order_date(p_customer_id TEXT)
RETURNS DATE
LANGUAGE sql
AS $$
    SELECT MAX(orderdate)
    FROM orders
    WHERE customerid = p_customer_id;
$$;

-- Testler:
-- SELECT nw_customer_last_order_date('ALFKI'); -- Son sipariş tarihi
-- SELECT nw_customer_last_order_date('ZZZZZ'); -- NULL


------------------------------------------------------------
-- 5) Tek Siparişin Brüt Değeri
-- Amaç: Bir siparişin toplam tutarı (indirimli).
-- Kullanılan tablo: order_details
-- Dönüş: NUMERIC(12,2)
-- LANGUAGE sql: toplama işlemi, CASE ile NULL yönetimi.
------------------------------------------------------------
CREATE OR REPLACE FUNCTION nw_order_gross_value(p_order_id INT)
RETURNS NUMERIC(12,2)
LANGUAGE sql
AS $$
    SELECT COALESCE(SUM(unitprice * quantity * (1 - discount)), 0.00)
    FROM order_details
    WHERE orderid = p_order_id;
$$;

-- Testler:
-- SELECT nw_order_gross_value(10248); -- 440.00 civarı
-- SELECT nw_order_gross_value(99999); -- 0.00


------------------------------------------------------------
-- 6) Ürünün Tarih Aralığı Geliri
-- Amaç: Ürünün belirli tarih aralığında toplam gelirini verir.
-- Kullanılan tablolar: order_details, orders
-- LANGUAGE sql: JOIN + SUM işlemi
------------------------------------------------------------
CREATE OR REPLACE FUNCTION nw_product_revenue(
    p_product_id INT,
    p_start DATE DEFAULT '1900-01-01',
    p_end DATE DEFAULT '9999-12-31'
)
RETURNS NUMERIC(12,2)
LANGUAGE sql
AS $$
    SELECT COALESCE(SUM(od.unitprice * od.quantity * (1 - od.discount)), 0.00)
    FROM order_details od
    JOIN orders o ON o.orderid = od.orderid
    WHERE od.productid = p_product_id
      AND o.orderdate BETWEEN p_start AND p_end;
$$;

-- Testler:
-- SELECT nw_product_revenue(1, '1996-01-01', '1997-12-31'); -- belirli gelir
-- SELECT nw_product_revenue(9999); -- 0.00


------------------------------------------------------------
-- 7) Reorder Önerisi
-- Amaç: Ürün için sipariş önerisi: stok+onorder < reorderlevel ise fark kadar.
-- Kullanılan tablo: products
-- LANGUAGE sql: CASE ile kontrol.
------------------------------------------------------------
CREATE OR REPLACE FUNCTION nw_reorder_suggestion(p_product_id INT)
RETURNS INT
LANGUAGE sql
AS $$
    SELECT 
        CASE 
            WHEN (unitsinstock + COALESCE(unitsonorder,0)) < reorderlevel
            THEN reorderlevel - (unitsinstock + COALESCE(unitsonorder,0))
            ELSE 0
        END
    FROM products
    WHERE productid = p_product_id;
$$;

-- Testler:
-- SELECT nw_reorder_suggestion(1); -- 0 veya pozitif değer
-- SELECT nw_reorder_suggestion(9999); -- NULL



