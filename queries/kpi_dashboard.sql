-- kpi_dashboard.sql
-- Key Performance Indicators for Executive Dashboard
-- Data Engineer II Challenge

SET search_path TO retail, public;

-- =====================================================
-- EXECUTIVE KPI DASHBOARD QUERIES
-- =====================================================

-- KPI 1: Sales Performance Summary (Current vs Previous Period)
WITH current_period AS (
    SELECT 
        SUM(v.cantidad * v.precio_unitario * (1 - v.descuento_pct/100)) as ventas_actuales,
        COUNT(DISTINCT v.ticket_id) as transacciones_actuales,
        COUNT(DISTINCT v.id_tienda) as tiendas_activas,
        AVG(v.cantidad * v.precio_unitario * (1 - v.descuento_pct/100)) as ticket_promedio_actual
    FROM retail.fact_ventas v
    WHERE v.fecha BETWEEN CURRENT_DATE - INTERVAL '30 days' AND CURRENT_DATE
),
previous_period AS (
    SELECT 
        SUM(v.cantidad * v.precio_unitario * (1 - v.descuento_pct/100)) as ventas_anteriores,
        COUNT(DISTINCT v.ticket_id) as transacciones_anteriores,
        AVG(v.cantidad * v.precio_unitario * (1 - v.descuento_pct/100)) as ticket_promedio_anterior
    FROM retail.fact_ventas v
    WHERE v.fecha BETWEEN CURRENT_DATE - INTERVAL '60 days' AND CURRENT_DATE - INTERVAL '30 days'
)
SELECT 
    'Ventas Netas' as kpi,
    cp.ventas_actuales as valor_actual,
    pp.ventas_anteriores as valor_anterior,
    ROUND(((cp.ventas_actuales - pp.ventas_anteriores) / pp.ventas_anteriores) * 100, 2) as cambio_porcentual
FROM current_period cp, previous_period pp
UNION ALL
SELECT 
    'Transacciones' as kpi,
    cp.transacciones_actuales as valor_actual,
    pp.transacciones_anteriores as valor_anterior,
    ROUND(((cp.transacciones_actuales - pp.transacciones_anteriores) / pp.transacciones_anteriores::numeric) * 100, 2) as cambio_porcentual
FROM current_period cp, previous_period pp
UNION ALL
SELECT 
    'Ticket Promedio' as kpi,
    cp.ticket_promedio_actual as valor_actual,
    pp.ticket_promedio_anterior as valor_anterior,
    ROUND(((cp.ticket_promedio_actual - pp.ticket_promedio_anterior) / pp.ticket_promedio_anterior) * 100, 2) as cambio_porcentual
FROM current_period cp, previous_period pp;

-- KPI 2: Top 5 and Bottom 5 Performing Stores (Last 30 days)
WITH store_performance AS (
    SELECT 
        t.cadena,
        t.nombre_tienda,
        t.formato,
        t.region,
        SUM(v.cantidad * v.precio_unitario * (1 - v.descuento_pct/100)) as ventas_netas,
        COUNT(DISTINCT v.fecha) as dias_activos,
        SUM(v.cantidad * v.precio_unitario * (1 - v.descuento_pct/100)) / COUNT(DISTINCT v.fecha) as venta_diaria_promedio
    FROM retail.fact_ventas v
    JOIN retail.dim_tienda t ON v.id_tienda = t.id_tienda
    WHERE v.fecha BETWEEN CURRENT_DATE - INTERVAL '30 days' AND CURRENT_DATE
    GROUP BY t.cadena, t.nombre_tienda, t.formato, t.region, t.id_tienda
    HAVING COUNT(DISTINCT v.fecha) >= 20  -- At least 20 days of activity
),
ranked_stores AS (
    SELECT 
        *,
        ROW_NUMBER() OVER (ORDER BY venta_diaria_promedio DESC) as rank_top,
        ROW_NUMBER() OVER (ORDER BY venta_diaria_promedio ASC) as rank_bottom
    FROM store_performance
)
SELECT 'TOP_5' as categoria, cadena, nombre_tienda, formato, region, ventas_netas, venta_diaria_promedio
FROM ranked_stores WHERE rank_top <= 5
UNION ALL
SELECT 'BOTTOM_5' as categoria, cadena, nombre_tienda, formato, region, ventas_netas, venta_diaria_promedio
FROM ranked_stores WHERE rank_bottom <= 5
ORDER BY categoria DESC, venta_diaria_promedio DESC;

-- KPI 3: Category Performance Matrix
SELECT 
    p.categoria,
    COUNT(DISTINCT p.id_producto) as productos_activos,
    SUM(v.cantidad) as unidades_vendidas,
    SUM(v.cantidad * v.precio_unitario * (1 - v.descuento_pct/100)) as ventas_netas,
    AVG(v.precio_unitario) as precio_promedio,
    SUM(v.cantidad * v.precio_unitario * (1 - v.descuento_pct/100)) / SUM(SUM(v.cantidad * v.precio_unitario * (1 - v.descuento_pct/100))) OVER () * 100 as participacion_ventas_pct
FROM retail.fact_ventas v
JOIN retail.dim_producto p ON v.id_producto = p.id_producto
WHERE v.fecha BETWEEN CURRENT_DATE - INTERVAL '90 days' AND CURRENT_DATE
GROUP BY p.categoria
ORDER BY ventas_netas DESC;

-- KPI 4: Channel Performance
SELECT 
    v.canal,
    COUNT(DISTINCT v.ticket_id) as transacciones,
    SUM(v.cantidad) as unidades_vendidas,
    SUM(v.cantidad * v.precio_unitario * (1 - v.descuento_pct/100)) as ventas_netas,
    AVG(v.cantidad * v.precio_unitario * (1 - v.descuento_pct/100)) as ticket_promedio,
    SUM(v.cantidad * v.precio_unitario * (1 - v.descuento_pct/100)) / SUM(SUM(v.cantidad * v.precio_unitario * (1 - v.descuento_pct/100))) OVER () * 100 as participacion_pct
FROM retail.fact_ventas v
WHERE v.fecha BETWEEN CURRENT_DATE - INTERVAL '30 days' AND CURRENT_DATE
  AND v.ticket_id IS NOT NULL
GROUP BY v.canal
ORDER BY ventas_netas DESC;

-- KPI 5: Inventory Health Summary
WITH inventory_health AS (
    SELECT 
        p.categoria,
        COUNT(*) as total_sku_tienda,
        COUNT(*) FILTER (WHERE i.stock_final = 0) as stockouts,
        COUNT(*) FILTER (WHERE i.stock_final < 10) as low_stock,
        AVG(i.stock_final * i.costo_unitario) as valor_inventario_promedio
    FROM retail.fact_inventario i
    JOIN retail.dim_producto p ON i.id_producto = p.id_producto
    WHERE i.fecha >= CURRENT_DATE - INTERVAL '7 days'
    GROUP BY p.categoria
)
SELECT 
    categoria,
    total_sku_tienda,
    stockouts,
    low_stock,
    ROUND((stockouts::numeric / total_sku_tienda) * 100, 2) as stockout_rate_pct,
    ROUND((low_stock::numeric / total_sku_tienda) * 100, 2) as low_stock_rate_pct,
    valor_inventario_promedio
FROM inventory_health
ORDER BY stockout_rate_pct DESC;
