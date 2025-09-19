-- 02_top_products_query.sql
-- Performance optimization example: Top products by region
-- Data Engineer II Challenge

SET search_path TO retail, public;

-- =====================================================
-- QUERY 2: Top Products by Region (BEFORE Optimization)
-- =====================================================

-- Business requirement: Find top 10 products by revenue in each region
-- for the current month to support regional merchandising decisions

-- BEFORE: Unoptimized query
EXPLAIN (ANALYZE, BUFFERS, VERBOSE)
SELECT 
    t.region,
    p.categoria,
    p.marca,
    p.nombre_producto,
    SUM(v.cantidad * v.precio_unitario * (1 - v.descuento_pct/100)) as ventas_netas,
    SUM(v.cantidad) as unidades_vendidas,
    COUNT(DISTINCT v.id_tienda) as tiendas_vendedoras,
    ROW_NUMBER() OVER (PARTITION BY t.region ORDER BY SUM(v.cantidad * v.precio_unitario * (1 - v.descuento_pct/100)) DESC) as ranking_regional
FROM retail.fact_ventas v
JOIN retail.dim_producto p ON v.id_producto = p.id_producto
JOIN retail.dim_tienda t ON v.id_tienda = t.id_tienda
WHERE v.fecha >= DATE_TRUNC('month', CURRENT_DATE)
GROUP BY t.region, p.categoria, p.marca, p.nombre_producto, p.id_producto
HAVING SUM(v.cantidad * v.precio_unitario * (1 - v.descuento_pct/100)) > 1000
ORDER BY t.region, ranking_regional;

-- Expected issues in BEFORE scenario:
-- 1. Multiple table joins without optimized join paths
-- 2. Complex aggregation without supporting indexes
-- 3. Window function over large result set
-- 4. HAVING clause applied after expensive aggregation

-- =====================================================
-- OPTIMIZATION STEPS
-- =====================================================

-- Step 1: Create composite index for date-based filtering
CREATE INDEX CONCURRENTLY idx_ventas_current_month 
ON retail.fact_ventas (fecha, id_producto, id_tienda) 
WHERE fecha >= DATE_TRUNC('month', CURRENT_DATE - INTERVAL '3 months');

-- Step 2: Create materialized view for regional product performance
CREATE MATERIALIZED VIEW retail.mv_regional_product_performance AS
SELECT 
    t.region,
    p.id_producto,
    p.categoria,
    p.marca,
    p.nombre_producto,
    DATE_TRUNC('month', v.fecha) as mes,
    SUM(v.cantidad * v.precio_unitario * (1 - v.descuento_pct/100)) as ventas_netas,
    SUM(v.cantidad) as unidades_vendidas,
    COUNT(DISTINCT v.id_tienda) as tiendas_vendedoras,
    COUNT(DISTINCT v.ticket_id) as transacciones
FROM retail.fact_ventas v
JOIN retail.dim_producto p ON v.id_producto = p.id_producto
JOIN retail.dim_tienda t ON v.id_tienda = t.id_tienda
WHERE v.fecha >= DATE_TRUNC('month', CURRENT_DATE - INTERVAL '6 months')
GROUP BY t.region, p.id_producto, p.categoria, p.marca, p.nombre_producto, DATE_TRUNC('month', v.fecha);

-- Step 3: Create index on materialized view
CREATE INDEX idx_mv_regional_performance_month_region 
ON retail.mv_regional_product_performance (mes, region, ventas_netas DESC);

-- Step 4: Create refresh function for the materialized view
CREATE OR REPLACE FUNCTION refresh_regional_performance()
RETURNS void AS $$
BEGIN
    REFRESH MATERIALIZED VIEW CONCURRENTLY retail.mv_regional_product_performance;
END;
$$ LANGUAGE plpgsql;

-- Update statistics
ANALYZE retail.mv_regional_product_performance;

-- =====================================================
-- QUERY 2: Top Products by Region (AFTER Optimization)
-- =====================================================

-- AFTER: Optimized query using materialized view
EXPLAIN (ANALYZE, BUFFERS, VERBOSE)
WITH ranked_products AS (
    SELECT 
        region,
        categoria,
        marca,
        nombre_producto,
        ventas_netas,
        unidades_vendidas,
        tiendas_vendedoras,
        ROW_NUMBER() OVER (PARTITION BY region ORDER BY ventas_netas DESC) as ranking_regional
    FROM retail.mv_regional_product_performance
    WHERE mes = DATE_TRUNC('month', CURRENT_DATE)
      AND ventas_netas > 1000
)
SELECT 
    region,
    categoria,
    marca,
    nombre_producto,
    ventas_netas,
    unidades_vendidas,
    tiendas_vendedoras,
    ranking_regional
FROM ranked_products
WHERE ranking_regional <= 10
ORDER BY region, ranking_regional;

-- Expected improvements in AFTER scenario:
-- 1. Pre-aggregated data eliminates expensive joins
-- 2. Index scan on materialized view instead of full table scans
-- 3. Reduced data volume for window function processing
-- 4. Much faster execution due to pre-computed aggregations
