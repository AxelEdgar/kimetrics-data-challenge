-- business_cases.sql
-- Business Query Examples for Retail Analytics
-- Data Engineer II Challenge

SET search_path TO retail, public;

-- =====================================================
-- BUSINESS CASE 1: Daily Sales by Chain and Store
-- =====================================================

-- Q1.1: Daily sales summary by chain
-- Use case: Executive dashboard showing daily performance across chains
SELECT 
    c.fecha,
    t.cadena,
    COUNT(DISTINCT v.ticket_id) as num_transacciones,
    SUM(v.cantidad) as unidades_vendidas,
    SUM(v.cantidad * v.precio_unitario * (1 - v.descuento_pct/100)) as ventas_netas,
    AVG(v.cantidad * v.precio_unitario * (1 - v.descuento_pct/100)) as ticket_promedio
FROM retail.fact_ventas v
JOIN retail.dim_tienda t ON v.id_tienda = t.id_tienda
JOIN retail.dim_calendario c ON v.fecha = c.fecha
WHERE v.fecha BETWEEN '2024-01-01' AND '2024-12-31'
GROUP BY c.fecha, t.cadena
ORDER BY c.fecha DESC, ventas_netas DESC;

-- Q1.2: Weekly sales trend by chain (last 12 weeks)
-- Use case: Identify weekly performance trends and seasonality
SELECT 
    c.anno,
    c.semana_anno,
    t.cadena,
    SUM(v.cantidad * v.precio_unitario * (1 - v.descuento_pct/100)) as ventas_netas,
    COUNT(DISTINCT v.id_tienda) as tiendas_activas,
    COUNT(DISTINCT v.ticket_id) as transacciones
FROM retail.fact_ventas v
JOIN retail.dim_tienda t ON v.id_tienda = t.id_tienda
JOIN retail.dim_calendario c ON v.fecha = c.fecha
WHERE v.fecha >= CURRENT_DATE - INTERVAL '12 weeks'
GROUP BY c.anno, c.semana_anno, t.cadena
ORDER BY c.anno DESC, c.semana_anno DESC, ventas_netas DESC;

-- Q1.3: Store performance ranking within chain
-- Use case: Identify top and bottom performing stores for operational focus
WITH store_performance AS (
    SELECT 
        t.cadena,
        t.id_tienda,
        t.nombre_tienda,
        t.formato,
        t.region,
        SUM(v.cantidad * v.precio_unitario * (1 - v.descuento_pct/100)) as ventas_netas,
        COUNT(DISTINCT v.fecha) as dias_activos,
        SUM(v.cantidad * v.precio_unitario * (1 - v.descuento_pct/100)) / COUNT(DISTINCT v.fecha) as venta_promedio_diaria
    FROM retail.fact_ventas v
    JOIN retail.dim_tienda t ON v.id_tienda = t.id_tienda
    WHERE v.fecha BETWEEN '2024-10-01' AND '2024-12-31'
    GROUP BY t.cadena, t.id_tienda, t.nombre_tienda, t.formato, t.region
)
SELECT 
    cadena,
    nombre_tienda,
    formato,
    region,
    ventas_netas,
    venta_promedio_diaria,
    RANK() OVER (PARTITION BY cadena ORDER BY venta_promedio_diaria DESC) as ranking_cadena,
    PERCENT_RANK() OVER (PARTITION BY cadena ORDER BY venta_promedio_diaria) as percentil_performance
FROM store_performance
ORDER BY cadena, ranking_cadena;

-- =====================================================
-- BUSINESS CASE 2: Top Products Analysis
-- =====================================================

-- Q2.1: Top 20 products by revenue (last quarter)
-- Use case: Identify best-selling products for inventory planning
SELECT 
    p.categoria,
    p.marca,
    p.nombre_producto,
    SUM(v.cantidad) as unidades_vendidas,
    SUM(v.cantidad * v.precio_unitario * (1 - v.descuento_pct/100)) as ventas_netas,
    AVG(v.precio_unitario) as precio_promedio,
    COUNT(DISTINCT v.id_tienda) as tiendas_vendedoras,
    COUNT(DISTINCT v.fecha) as dias_con_ventas
FROM retail.fact_ventas v
JOIN retail.dim_producto p ON v.id_producto = p.id_producto
JOIN retail.dim_calendario c ON v.fecha = c.fecha
WHERE c.trimestre = 4 AND c.anno = 2024
GROUP BY p.categoria, p.marca, p.nombre_producto, p.id_producto
ORDER BY ventas_netas DESC
LIMIT 20;

-- Q2.2: Top products by region (current month)
-- Use case: Regional merchandising and local preferences analysis
WITH regional_products AS (
    SELECT 
        t.region,
        p.categoria,
        p.nombre_producto,
        SUM(v.cantidad * v.precio_unitario * (1 - v.descuento_pct/100)) as ventas_netas,
        SUM(v.cantidad) as unidades_vendidas,
        ROW_NUMBER() OVER (PARTITION BY t.region ORDER BY SUM(v.cantidad * v.precio_unitario * (1 - v.descuento_pct/100)) DESC) as ranking_regional
    FROM retail.fact_ventas v
    JOIN retail.dim_producto p ON v.id_producto = p.id_producto
    JOIN retail.dim_tienda t ON v.id_tienda = t.id_tienda
    WHERE v.fecha >= DATE_TRUNC('month', CURRENT_DATE)
    GROUP BY t.region, p.categoria, p.nombre_producto
)
SELECT 
    region,
    categoria,
    nombre_producto,
    ventas_netas,
    unidades_vendidas,
    ranking_regional
FROM regional_products
WHERE ranking_regional <= 10
ORDER BY region, ranking_regional;

-- Q2.3: Product performance by channel
-- Use case: Understand which products perform better online vs in-store
SELECT 
    p.categoria,
    p.subcategoria,
    v.canal,
    COUNT(DISTINCT p.id_producto) as productos_vendidos,
    SUM(v.cantidad) as unidades_vendidas,
    SUM(v.cantidad * v.precio_unitario * (1 - v.descuento_pct/100)) as ventas_netas,
    AVG(v.cantidad * v.precio_unitario * (1 - v.descuento_pct/100)) as ticket_promedio
FROM retail.fact_ventas v
JOIN retail.dim_producto p ON v.id_producto = p.id_producto
WHERE v.fecha BETWEEN '2024-01-01' AND '2024-12-31'
GROUP BY p.categoria, p.subcategoria, v.canal
ORDER BY p.categoria, ventas_netas DESC;

-- =====================================================
-- BUSINESS CASE 3: Average Ticket Analysis
-- =====================================================

-- Q3.1: Weekly average ticket by store format
-- Use case: Understand customer behavior patterns by store type
SELECT 
    c.anno,
    c.semana_anno,
    t.formato,
    COUNT(DISTINCT v.ticket_id) as num_tickets,
    SUM(v.cantidad * v.precio_unitario * (1 - v.descuento_pct/100)) as ventas_totales,
    SUM(v.cantidad * v.precio_unitario * (1 - v.descuento_pct/100)) / COUNT(DISTINCT v.ticket_id) as ticket_promedio,
    AVG(items_per_ticket.items) as items_promedio_por_ticket
FROM retail.fact_ventas v
JOIN retail.dim_tienda t ON v.id_tienda = t.id_tienda
JOIN retail.dim_calendario c ON v.fecha = c.fecha
JOIN (
    SELECT ticket_id, COUNT(*) as items
    FROM retail.fact_ventas
    WHERE ticket_id IS NOT NULL
    GROUP BY ticket_id
) items_per_ticket ON v.ticket_id = items_per_ticket.ticket_id
WHERE v.fecha BETWEEN '2024-01-01' AND '2024-12-31'
  AND v.ticket_id IS NOT NULL
GROUP BY c.anno, c.semana_anno, t.formato
ORDER BY c.anno DESC, c.semana_anno DESC, ticket_promedio DESC;

-- Q3.2: Monthly ticket analysis by region
-- Use case: Regional pricing and promotion strategy
SELECT 
    c.anno,
    c.mes,
    c.nombre_mes,
    t.region,
    COUNT(DISTINCT v.ticket_id) as num_tickets,
    SUM(v.cantidad * v.precio_unitario * (1 - v.descuento_pct/100)) as ventas_netas,
    SUM(v.cantidad * v.precio_unitario * (1 - v.descuento_pct/100)) / COUNT(DISTINCT v.ticket_id) as ticket_promedio,
    PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY ticket_values.ticket_value) as ticket_mediano
FROM retail.fact_ventas v
JOIN retail.dim_tienda t ON v.id_tienda = t.id_tienda
JOIN retail.dim_calendario c ON v.fecha = c.fecha
JOIN (
    SELECT 
        ticket_id, 
        SUM(cantidad * precio_unitario * (1 - descuento_pct/100)) as ticket_value
    FROM retail.fact_ventas
    WHERE ticket_id IS NOT NULL
    GROUP BY ticket_id
) ticket_values ON v.ticket_id = ticket_values.ticket_id
WHERE v.fecha BETWEEN '2024-01-01' AND '2024-12-31'
  AND v.ticket_id IS NOT NULL
GROUP BY c.anno, c.mes, c.nombre_mes, t.region
ORDER BY c.anno DESC, c.mes DESC, ticket_promedio DESC;

-- Q3.3: Hourly ticket patterns
-- Use case: Staff scheduling and operational optimization
SELECT 
    EXTRACT(HOUR FROM v.hora::time) as hora,
    t.formato,
    COUNT(DISTINCT v.ticket_id) as num_tickets,
    SUM(v.cantidad * v.precio_unitario * (1 - v.descuento_pct/100)) as ventas_netas,
    SUM(v.cantidad * v.precio_unitario * (1 - v.descuento_pct/100)) / COUNT(DISTINCT v.ticket_id) as ticket_promedio
FROM retail.fact_ventas v
JOIN retail.dim_tienda t ON v.id_tienda = t.id_tienda
WHERE v.fecha BETWEEN '2024-11-01' AND '2024-11-30'
  AND v.hora IS NOT NULL
  AND v.ticket_id IS NOT NULL
GROUP BY EXTRACT(HOUR FROM v.hora::time), t.formato
ORDER BY hora, formato;

-- =====================================================
-- BUSINESS CASE 4: Inventory Analysis and Stock Alerts
-- =====================================================

-- Q4.1: Current stock levels with days of supply
-- Use case: Inventory replenishment planning
WITH recent_sales AS (
    SELECT 
        id_producto,
        id_tienda,
        AVG(cantidad) as avg_daily_sales
    FROM retail.fact_ventas
    WHERE fecha >= CURRENT_DATE - INTERVAL '30 days'
    GROUP BY id_producto, id_tienda
    HAVING COUNT(*) >= 5  -- At least 5 days of sales data
),
latest_inventory AS (
    SELECT DISTINCT
        id_producto,
        id_tienda,
        FIRST_VALUE(stock_final) OVER (
            PARTITION BY id_producto, id_tienda 
            ORDER BY fecha DESC
        ) as stock_actual,
        FIRST_VALUE(fecha) OVER (
            PARTITION BY id_producto, id_tienda 
            ORDER BY fecha DESC
        ) as fecha_ultimo_inventario
    FROM retail.fact_inventario
)
SELECT 
    p.categoria,
    p.marca,
    p.nombre_producto,
    t.cadena,
    t.nombre_tienda,
    li.stock_actual,
    rs.avg_daily_sales,
    CASE 
        WHEN rs.avg_daily_sales > 0 THEN li.stock_actual / rs.avg_daily_sales
        ELSE NULL
    END as dias_de_inventario,
    li.fecha_ultimo_inventario,
    CASE 
        WHEN li.stock_actual = 0 THEN 'SIN_STOCK'
        WHEN li.stock_actual / NULLIF(rs.avg_daily_sales, 0) < 7 THEN 'STOCK_BAJO'
        WHEN li.stock_actual / NULLIF(rs.avg_daily_sales, 0) > 60 THEN 'SOBRESTOCK'
        ELSE 'NORMAL'
    END as alerta_inventario
FROM latest_inventory li
JOIN retail.dim_producto p ON li.id_producto = p.id_producto
JOIN retail.dim_tienda t ON li.id_tienda = t.id_tienda
LEFT JOIN recent_sales rs ON li.id_producto = rs.id_producto AND li.id_tienda = rs.id_tienda
WHERE li.fecha_ultimo_inventario >= CURRENT_DATE - INTERVAL '7 days'
ORDER BY 
    CASE 
        WHEN li.stock_actual = 0 THEN 1
        WHEN li.stock_actual / NULLIF(rs.avg_daily_sales, 0) < 7 THEN 2
        WHEN li.stock_actual / NULLIF(rs.avg_daily_sales, 0) > 60 THEN 3
        ELSE 4
    END,
    p.categoria, t.cadena;

-- Q4.2: Inventory turnover by category and store format
-- Use case: Category management and space allocation
WITH inventory_metrics AS (
    SELECT 
        p.categoria,
        t.formato,
        AVG(i.stock_final * i.costo_unitario) as inventario_promedio,
        SUM(v.cantidad * i.costo_unitario) as costo_ventas
    FROM retail.fact_inventario i
    JOIN retail.dim_producto p ON i.id_producto = p.id_producto
    JOIN retail.dim_tienda t ON i.id_tienda = t.id_tienda
    JOIN retail.fact_ventas v ON i.id_producto = v.id_producto 
        AND i.id_tienda = v.id_tienda 
        AND i.fecha = v.fecha
    WHERE i.fecha BETWEEN '2024-01-01' AND '2024-12-31'
    GROUP BY p.categoria, t.formato
)
SELECT 
    categoria,
    formato,
    inventario_promedio,
    costo_ventas,
    CASE 
        WHEN inventario_promedio > 0 THEN costo_ventas / inventario_promedio
        ELSE 0
    END as rotacion_inventario,
    CASE 
        WHEN costo_ventas > 0 THEN (inventario_promedio / costo_ventas) * 365
        ELSE 0
    END as dias_inventario_promedio
FROM inventory_metrics
ORDER BY rotacion_inventario DESC;

-- Q4.3: Stockout frequency analysis
-- Use case: Service level optimization and supplier performance
WITH stockout_analysis AS (
    SELECT 
        p.categoria,
        p.marca,
        t.region,
        t.formato,
        COUNT(*) as total_snapshots,
        COUNT(*) FILTER (WHERE i.stock_final = 0) as stockouts,
        COUNT(*) FILTER (WHERE i.stock_final < 5) as low_stock_events
    FROM retail.fact_inventario i
    JOIN retail.dim_producto p ON i.id_producto = p.id_producto
    JOIN retail.dim_tienda t ON i.id_tienda = t.id_tienda
    WHERE i.fecha BETWEEN '2024-01-01' AND '2024-12-31'
    GROUP BY p.categoria, p.marca, t.region, t.formato
    HAVING COUNT(*) >= 10  -- Minimum data points
)
SELECT 
    categoria,
    marca,
    region,
    formato,
    total_snapshots,
    stockouts,
    low_stock_events,
    ROUND((stockouts::numeric / total_snapshots) * 100, 2) as stockout_rate_pct,
    ROUND((low_stock_events::numeric / total_snapshots) * 100, 2) as low_stock_rate_pct
FROM stockout_analysis
ORDER BY stockout_rate_pct DESC, categoria, marca;

-- =====================================================
-- BUSINESS CASE 5: Seasonal Analysis
-- =====================================================

-- Q5.1: Monthly seasonality patterns by category
-- Use case: Demand forecasting and promotional planning
SELECT 
    p.categoria,
    c.mes,
    c.nombre_mes,
    SUM(v.cantidad * v.precio_unitario * (1 - v.descuento_pct/100)) as ventas_netas,
    AVG(SUM(v.cantidad * v.precio_unitario * (1 - v.descuento_pct/100))) OVER (
        PARTITION BY p.categoria
    ) as promedio_anual_categoria,
    (SUM(v.cantidad * v.precio_unitario * (1 - v.descuento_pct/100)) / 
     AVG(SUM(v.cantidad * v.precio_unitario * (1 - v.descuento_pct/100))) OVER (
        PARTITION BY p.categoria
     )) as indice_estacionalidad
FROM retail.fact_ventas v
JOIN retail.dim_producto p ON v.id_producto = p.id_producto
JOIN retail.dim_calendario c ON v.fecha = c.fecha
WHERE c.anno BETWEEN 2022 AND 2024  -- 3 years for stable patterns
GROUP BY p.categoria, c.mes, c.nombre_mes
ORDER BY p.categoria, c.mes;

-- Q5.2: Holiday impact analysis
-- Use case: Holiday promotion effectiveness
SELECT 
    c.nombre_festivo,
    c.fecha,
    c.nombre_dia,
    SUM(v.cantidad * v.precio_unitario * (1 - v.descuento_pct/100)) as ventas_festivo,
    AVG(regular_sales.ventas_regulares) as promedio_dias_regulares,
    (SUM(v.cantidad * v.precio_unitario * (1 - v.descuento_pct/100)) / 
     AVG(regular_sales.ventas_regulares)) as factor_incremento
FROM retail.fact_ventas v
JOIN retail.dim_calendario c ON v.fecha = c.fecha
JOIN (
    SELECT 
        c2.fecha,
        SUM(cantidad * precio_unitario * (1 - descuento_pct/100)) as ventas_regulares
    FROM retail.fact_ventas v2
    JOIN retail.dim_calendario c2 ON v2.fecha = c2.fecha
    WHERE c2.es_festivo = false 
      AND c2.es_fin_de_semana = false
      AND c2.anno BETWEEN 2022 AND 2024
    GROUP BY c2.fecha
) regular_sales ON true
WHERE c.es_festivo = true
  AND c.anno BETWEEN 2022 AND 2024
GROUP BY c.nombre_festivo, c.fecha, c.nombre_dia
ORDER BY factor_incremento DESC;
