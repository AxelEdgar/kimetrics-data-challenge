-- 03_inventory_analysis_query.sql
-- Performance optimization example: Inventory analysis with stock alerts
-- Data Engineer II Challenge

SET search_path TO retail, public;

-- =====================================================
-- QUERY 3: Inventory Analysis with Stock Alerts (BEFORE Optimization)
-- =====================================================

-- Business requirement: Identify products with low stock or stockout conditions
-- across all stores, including days of supply calculation

-- BEFORE: Unoptimized query with complex subqueries
EXPLAIN (ANALYZE, BUFFERS, VERBOSE)
SELECT 
    p.categoria,
    p.marca,
    p.nombre_producto,
    t.cadena,
    t.nombre_tienda,
    t.region,
    i.stock_final,
    COALESCE(recent_sales.avg_daily_sales, 0) as avg_daily_sales,
    CASE 
        WHEN COALESCE(recent_sales.avg_daily_sales, 0) > 0 
        THEN i.stock_final / recent_sales.avg_daily_sales
        ELSE NULL
    END as dias_de_inventario,
    CASE 
        WHEN i.stock_final = 0 THEN 'SIN_STOCK'
        WHEN i.stock_final / COALESCE(recent_sales.avg_daily_sales, 1) < 7 THEN 'STOCK_BAJO'
        WHEN i.stock_final / COALESCE(recent_sales.avg_daily_sales, 1) > 60 THEN 'SOBRESTOCK'
        ELSE 'NORMAL'
    END as alerta_inventario,
    i.fecha as fecha_inventario
FROM retail.fact_inventario i
JOIN retail.dim_producto p ON i.id_producto = p.id_producto
JOIN retail.dim_tienda t ON i.id_tienda = t.id_tienda
LEFT JOIN (
    SELECT 
        id_producto,
        id_tienda,
        AVG(cantidad) as avg_daily_sales
    FROM retail.fact_ventas
    WHERE fecha >= CURRENT_DATE - INTERVAL '30 days'
    GROUP BY id_producto, id_tienda
    HAVING COUNT(DISTINCT fecha) >= 5
) recent_sales ON i.id_producto = recent_sales.id_producto 
                 AND i.id_tienda = recent_sales.id_tienda
WHERE i.fecha = (
    SELECT MAX(fecha) 
    FROM retail.fact_inventario i2 
    WHERE i2.id_producto = i.id_producto 
      AND i2.id_tienda = i.id_tienda
)
ORDER BY 
    CASE 
        WHEN i.stock_final = 0 THEN 1
        WHEN i.stock_final / COALESCE(recent_sales.avg_daily_sales, 1) < 7 THEN 2
        ELSE 3
    END,
    p.categoria, t.cadena;

-- Expected issues in BEFORE scenario:
-- 1. Correlated subquery for latest inventory date (very expensive)
-- 2. Complex LEFT JOIN with aggregated subquery
-- 3. Multiple CASE statements with repeated calculations
-- 4. No indexes optimized for this query pattern

-- =====================================================
-- OPTIMIZATION STEPS
-- =====================================================

-- Step 1: Create optimized indexes for inventory queries
CREATE INDEX CONCURRENTLY idx_inventario_producto_tienda_fecha 
ON retail.fact_inventario (id_producto, id_tienda, fecha DESC);

CREATE INDEX CONCURRENTLY idx_inventario_fecha_stock 
ON retail.fact_inventario (fecha DESC, stock_final) 
WHERE fecha >= CURRENT_DATE - INTERVAL '30 days';

-- Step 2: Create materialized view for latest inventory positions
CREATE MATERIALIZED VIEW retail.mv_latest_inventory AS
WITH latest_inventory_dates AS (
    SELECT 
        id_producto,
        id_tienda,
        MAX(fecha) as latest_fecha
    FROM retail.fact_inventario
    WHERE fecha >= CURRENT_DATE - INTERVAL '30 days'
    GROUP BY id_producto, id_tienda
)
SELECT 
    i.id_producto,
    i.id_tienda,
    i.fecha,
    i.stock_final,
    i.costo_unitario,
    i.valor_inventario
FROM retail.fact_inventario i
JOIN latest_inventory_dates lid ON i.id_producto = lid.id_producto 
                                 AND i.id_tienda = lid.id_tienda 
                                 AND i.fecha = lid.latest_fecha;

-- Step 3: Create materialized view for recent sales averages
CREATE MATERIALIZED VIEW retail.mv_recent_sales_avg AS
SELECT 
    id_producto,
    id_tienda,
    AVG(cantidad) as avg_daily_sales,
    COUNT(DISTINCT fecha) as sales_days,
    SUM(cantidad) as total_quantity,
    MAX(fecha) as last_sale_date
FROM retail.fact_ventas
WHERE fecha >= CURRENT_DATE - INTERVAL '30 days'
GROUP BY id_producto, id_tienda
HAVING COUNT(DISTINCT fecha) >= 3;  -- At least 3 days of sales

-- Step 4: Create indexes on materialized views
CREATE INDEX idx_mv_latest_inventory_producto_tienda 
ON retail.mv_latest_inventory (id_producto, id_tienda);

CREATE INDEX idx_mv_recent_sales_producto_tienda 
ON retail.mv_recent_sales_avg (id_producto, id_tienda);

-- Step 5: Create composite materialized view for inventory alerts
CREATE MATERIALIZED VIEW retail.mv_inventory_alerts AS
SELECT 
    p.categoria,
    p.marca,
    p.nombre_producto,
    t.cadena,
    t.nombre_tienda,
    t.region,
    li.stock_final,
    COALESCE(rsa.avg_daily_sales, 0) as avg_daily_sales,
    CASE 
        WHEN COALESCE(rsa.avg_daily_sales, 0) > 0 
        THEN li.stock_final / rsa.avg_daily_sales
        ELSE NULL
    END as dias_de_inventario,
    CASE 
        WHEN li.stock_final = 0 THEN 'SIN_STOCK'
        WHEN li.stock_final / COALESCE(rsa.avg_daily_sales, 1) < 7 THEN 'STOCK_BAJO'
        WHEN li.stock_final / COALESCE(rsa.avg_daily_sales, 1) > 60 THEN 'SOBRESTOCK'
        ELSE 'NORMAL'
    END as alerta_inventario,
    li.fecha as fecha_inventario,
    rsa.last_sale_date,
    CASE 
        WHEN li.stock_final = 0 THEN 1
        WHEN li.stock_final / COALESCE(rsa.avg_daily_sales, 1) < 7 THEN 2
        WHEN li.stock_final / COALESCE(rsa.avg_daily_sales, 1) > 60 THEN 3
        ELSE 4
    END as prioridad_alerta
FROM retail.mv_latest_inventory li
JOIN retail.dim_producto p ON li.id_producto = p.id_producto
JOIN retail.dim_tienda t ON li.id_tienda = t.id_tienda
LEFT JOIN retail.mv_recent_sales_avg rsa ON li.id_producto = rsa.id_producto 
                                          AND li.id_tienda = rsa.id_tienda;

-- Step 6: Create index on alerts materialized view
CREATE INDEX idx_mv_inventory_alerts_priority 
ON retail.mv_inventory_alerts (prioridad_alerta, categoria, cadena);

-- Update statistics
ANALYZE retail.mv_latest_inventory;
ANALYZE retail.mv_recent_sales_avg;
ANALYZE retail.mv_inventory_alerts;

-- =====================================================
-- QUERY 3: Inventory Analysis with Stock Alerts (AFTER Optimization)
-- =====================================================

-- AFTER: Optimized query using pre-computed materialized views
EXPLAIN (ANALYZE, BUFFERS, VERBOSE)
SELECT 
    categoria,
    marca,
    nombre_producto,
    cadena,
    nombre_tienda,
    region,
    stock_final,
    avg_daily_sales,
    dias_de_inventario,
    alerta_inventario,
    fecha_inventario,
    last_sale_date
FROM retail.mv_inventory_alerts
WHERE alerta_inventario IN ('SIN_STOCK', 'STOCK_BAJO')
ORDER BY prioridad_alerta, categoria, cadena;

-- Expected improvements in AFTER scenario:
-- 1. Eliminates expensive correlated subqueries
-- 2. Pre-computed aggregations and calculations
-- 3. Simple index scan instead of complex joins
-- 4. Dramatic reduction in execution time and resource usage

-- =====================================================
-- MAINTENANCE PROCEDURES
-- =====================================================

-- Create function to refresh all inventory-related materialized views
CREATE OR REPLACE FUNCTION refresh_inventory_views()
RETURNS void AS $$
BEGIN
    REFRESH MATERIALIZED VIEW CONCURRENTLY retail.mv_latest_inventory;
    REFRESH MATERIALIZED VIEW CONCURRENTLY retail.mv_recent_sales_avg;
    REFRESH MATERIALIZED VIEW CONCURRENTLY retail.mv_inventory_alerts;
    
    -- Update statistics
    ANALYZE retail.mv_latest_inventory;
    ANALYZE retail.mv_recent_sales_avg;
    ANALYZE retail.mv_inventory_alerts;
END;
$$ LANGUAGE plpgsql;

-- Schedule this function to run daily via cron or pg_cron
-- SELECT cron.schedule('refresh-inventory-views', '0 6 * * *', 'SELECT refresh_inventory_views();');
