-- 01_daily_sales_query.sql
-- Performance optimization example: Daily sales by chain
-- Data Engineer II Challenge

SET search_path TO retail, public;

-- =====================================================
-- QUERY 1: Daily Sales by Chain (BEFORE Optimization)
-- =====================================================

-- This query represents a common business requirement:
-- Show daily sales performance by chain for the last quarter

-- BEFORE: Unoptimized query
EXPLAIN (ANALYZE, BUFFERS, VERBOSE)
SELECT 
    v.fecha,
    t.cadena,
    COUNT(DISTINCT v.ticket_id) as num_transacciones,
    SUM(v.cantidad) as unidades_vendidas,
    SUM(v.cantidad * v.precio_unitario * (1 - v.descuento_pct/100)) as ventas_netas,
    AVG(v.cantidad * v.precio_unitario * (1 - v.descuento_pct/100)) as ticket_promedio
FROM retail.fact_ventas v
JOIN retail.dim_tienda t ON v.id_tienda = t.id_tienda
WHERE v.fecha BETWEEN '2024-10-01' AND '2024-12-31'
GROUP BY v.fecha, t.cadena
ORDER BY v.fecha DESC, ventas_netas DESC;

-- Expected issues in BEFORE scenario:
-- 1. Sequential scan on fact_ventas if no date index
-- 2. Hash join might be inefficient without proper indexes
-- 3. Sorting on calculated field without covering index

-- =====================================================
-- OPTIMIZATION STEPS
-- =====================================================

-- Step 1: Create optimized indexes
CREATE INDEX CONCURRENTLY idx_ventas_fecha_optimized 
ON retail.fact_ventas (fecha) 
WHERE fecha >= '2024-01-01';

-- Step 2: Create covering index for this specific query pattern
CREATE INDEX CONCURRENTLY idx_ventas_daily_sales_covering 
ON retail.fact_ventas (fecha, id_tienda) 
INCLUDE (ticket_id, cantidad, precio_unitario, descuento_pct);

-- Step 3: Ensure store dimension has proper index
CREATE INDEX CONCURRENTLY idx_tienda_id_cadena 
ON retail.dim_tienda (id_tienda) 
INCLUDE (cadena);

-- Update statistics
ANALYZE retail.fact_ventas;
ANALYZE retail.dim_tienda;

-- =====================================================
-- QUERY 1: Daily Sales by Chain (AFTER Optimization)
-- =====================================================

-- AFTER: Optimized query with better structure
EXPLAIN (ANALYZE, BUFFERS, VERBOSE)
SELECT 
    v.fecha,
    t.cadena,
    COUNT(DISTINCT v.ticket_id) as num_transacciones,
    SUM(v.cantidad) as unidades_vendidas,
    SUM(v.cantidad * v.precio_unitario * (1 - v.descuento_pct/100)) as ventas_netas,
    AVG(v.cantidad * v.precio_unitario * (1 - v.descuento_pct/100)) as ticket_promedio
FROM retail.fact_ventas v
JOIN retail.dim_tienda t ON v.id_tienda = t.id_tienda
WHERE v.fecha BETWEEN '2024-10-01' AND '2024-12-31'
GROUP BY v.fecha, t.cadena
ORDER BY v.fecha DESC, ventas_netas DESC;

-- Expected improvements in AFTER scenario:
-- 1. Index scan on fecha with partition pruning
-- 2. Efficient nested loop or hash join using covering index
-- 3. Reduced I/O due to INCLUDE columns in index
