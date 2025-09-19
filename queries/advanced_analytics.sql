-- advanced_analytics.sql
-- Advanced Analytics Queries for Business Intelligence
-- Data Engineer II Challenge

SET search_path TO retail, public;

-- =====================================================
-- ADVANCED ANALYTICS QUERIES
-- =====================================================

-- A1: Customer Basket Analysis (Market Basket Analysis)
-- Use case: Product placement and cross-selling opportunities
WITH ticket_products AS (
    SELECT 
        v.ticket_id,
        p.categoria,
        p.nombre_producto,
        SUM(v.cantidad * v.precio_unitario * (1 - v.descuento_pct/100)) as valor_producto
    FROM retail.fact_ventas v
    JOIN retail.dim_producto p ON v.id_producto = p.id_producto
    WHERE v.fecha BETWEEN '2024-10-01' AND '2024-12-31'
      AND v.ticket_id IS NOT NULL
    GROUP BY v.ticket_id, p.categoria, p.nombre_producto
),
category_pairs AS (
    SELECT 
        tp1.categoria as categoria_a,
        tp2.categoria as categoria_b,
        COUNT(*) as co_occurrences,
        AVG(tp1.valor_producto + tp2.valor_producto) as valor_promedio_conjunto
    FROM ticket_products tp1
    JOIN ticket_products tp2 ON tp1.ticket_id = tp2.ticket_id
    WHERE tp1.categoria < tp2.categoria  -- Avoid duplicates and self-pairs
    GROUP BY tp1.categoria, tp2.categoria
    HAVING COUNT(*) >= 100  -- Minimum statistical significance
)
SELECT 
    categoria_a,
    categoria_b,
    co_occurrences,
    valor_promedio_conjunto,
    RANK() OVER (ORDER BY co_occurrences DESC) as ranking_afinidad
FROM category_pairs
ORDER BY co_occurrences DESC
LIMIT 20;

-- A2: Sales Forecasting Base Data (Trend Analysis)
-- Use case: Demand planning and inventory forecasting
WITH weekly_sales AS (
    SELECT 
        c.anno,
        c.semana_anno,
        p.categoria,
        t.region,
        SUM(v.cantidad * v.precio_unitario * (1 - v.descuento_pct/100)) as ventas_semanales,
        SUM(v.cantidad) as unidades_semanales
    FROM retail.fact_ventas v
    JOIN retail.dim_producto p ON v.id_producto = p.id_producto
    JOIN retail.dim_tienda t ON v.id_tienda = t.id_tienda
    JOIN retail.dim_calendario c ON v.fecha = c.fecha
    WHERE c.anno BETWEEN 2022 AND 2024
    GROUP BY c.anno, c.semana_anno, p.categoria, t.region
),
trend_analysis AS (
    SELECT 
        categoria,
        region,
        anno,
        semana_anno,
        ventas_semanales,
        LAG(ventas_semanales, 1) OVER (PARTITION BY categoria, region ORDER BY anno, semana_anno) as ventas_semana_anterior,
        LAG(ventas_semanales, 52) OVER (PARTITION BY categoria, region ORDER BY anno, semana_anno) as ventas_mismo_periodo_ano_anterior,
        AVG(ventas_semanales) OVER (
            PARTITION BY categoria, region 
            ORDER BY anno, semana_anno 
            ROWS BETWEEN 11 PRECEDING AND CURRENT ROW
        ) as promedio_movil_12_semanas
    FROM weekly_sales
)
SELECT 
    categoria,
    region,
    anno,
    semana_anno,
    ventas_semanales,
    promedio_movil_12_semanas,
    CASE 
        WHEN ventas_semana_anterior IS NOT NULL THEN 
            ROUND(((ventas_semanales - ventas_semana_anterior) / ventas_semana_anterior) * 100, 2)
        ELSE NULL
    END as crecimiento_semanal_pct,
    CASE 
        WHEN ventas_mismo_periodo_ano_anterior IS NOT NULL THEN 
            ROUND(((ventas_semanales - ventas_mismo_periodo_ano_anterior) / ventas_mismo_periodo_ano_anterior) * 100, 2)
        ELSE NULL
    END as crecimiento_anual_pct
FROM trend_analysis
WHERE anno = 2024
ORDER BY categoria, region, semana_anno DESC;

-- A3: Price Elasticity Analysis
-- Use case: Pricing strategy optimization
WITH price_volume_analysis AS (
    SELECT 
        p.categoria,
        p.marca,
        p.nombre_producto,
        DATE_TRUNC('month', v.fecha) as mes,
        AVG(v.precio_unitario) as precio_promedio,
        SUM(v.cantidad) as volumen_vendido,
        COUNT(DISTINCT v.id_tienda) as tiendas_vendedoras
    FROM retail.fact_ventas v
    JOIN retail.dim_producto p ON v.id_producto = p.id_producto
    WHERE v.fecha BETWEEN '2024-01-01' AND '2024-12-31'
    GROUP BY p.categoria, p.marca, p.nombre_producto, p.id_producto, DATE_TRUNC('month', v.fecha)
    HAVING COUNT(DISTINCT v.id_tienda) >= 5  -- Sold in at least 5 stores
),
price_elasticity AS (
    SELECT 
        categoria,
        marca,
        nombre_producto,
        mes,
        precio_promedio,
        volumen_vendido,
        LAG(precio_promedio) OVER (PARTITION BY categoria, marca, nombre_producto ORDER BY mes) as precio_anterior,
        LAG(volumen_vendido) OVER (PARTITION BY categoria, marca, nombre_producto ORDER BY mes) as volumen_anterior
    FROM price_volume_analysis
)
SELECT 
    categoria,
    marca,
    nombre_producto,
    mes,
    precio_promedio,
    volumen_vendido,
    CASE 
        WHEN precio_anterior IS NOT NULL AND precio_anterior != precio_promedio AND volumen_anterior IS NOT NULL THEN
            ROUND(
                ((volumen_vendido - volumen_anterior) / volumen_anterior::numeric) / 
                ((precio_promedio - precio_anterior) / precio_anterior::numeric), 
                2
            )
        ELSE NULL
    END as elasticidad_precio
FROM price_elasticity
WHERE precio_anterior IS NOT NULL
  AND ABS(precio_promedio - precio_anterior) > 0.5  -- Significant price change
ORDER BY categoria, marca, mes DESC;

-- A4: Store Clustering Analysis
-- Use case: Store segmentation for targeted strategies
WITH store_metrics AS (
    SELECT 
        t.id_tienda,
        t.cadena,
        t.formato,
        t.region,
        t.superficie_m2,
        SUM(v.cantidad * v.precio_unitario * (1 - v.descuento_pct/100)) as ventas_anuales,
        COUNT(DISTINCT v.fecha) as dias_activos,
        COUNT(DISTINCT v.ticket_id) as total_transacciones,
        AVG(v.cantidad * v.precio_unitario * (1 - v.descuento_pct/100)) as ticket_promedio,
        COUNT(DISTINCT v.id_producto) as variedad_productos,
        SUM(v.cantidad * v.precio_unitario * (1 - v.descuento_pct/100)) / t.superficie_m2 as ventas_por_m2
    FROM retail.fact_ventas v
    JOIN retail.dim_tienda t ON v.id_tienda = t.id_tienda
    WHERE v.fecha BETWEEN '2024-01-01' AND '2024-12-31'
      AND v.ticket_id IS NOT NULL
    GROUP BY t.id_tienda, t.cadena, t.formato, t.region, t.superficie_m2
    HAVING COUNT(DISTINCT v.fecha) >= 300  -- Active most of the year
),
store_percentiles AS (
    SELECT 
        *,
        NTILE(4) OVER (ORDER BY ventas_anuales) as cuartil_ventas,
        NTILE(4) OVER (ORDER BY ticket_promedio) as cuartil_ticket,
        NTILE(4) OVER (ORDER BY ventas_por_m2) as cuartil_productividad
    FROM store_metrics
)
SELECT 
    cadena,
    formato,
    region,
    COUNT(*) as num_tiendas,
    AVG(ventas_anuales) as ventas_promedio,
    AVG(ticket_promedio) as ticket_promedio_grupo,
    AVG(ventas_por_m2) as productividad_promedio,
    CASE 
        WHEN cuartil_ventas = 4 AND cuartil_ticket = 4 THEN 'PREMIUM'
        WHEN cuartil_ventas = 4 AND cuartil_productividad = 4 THEN 'HIGH_PERFORMANCE'
        WHEN cuartil_ventas >= 3 THEN 'STRONG'
        WHEN cuartil_ventas = 2 THEN 'AVERAGE'
        ELSE 'UNDERPERFORMING'
    END as segmento_tienda
FROM store_percentiles
GROUP BY cadena, formato, region, cuartil_ventas, cuartil_ticket, cuartil_productividad
ORDER BY ventas_promedio DESC;

-- A5: Cohort Analysis (Customer Retention Simulation)
-- Use case: Customer lifecycle analysis (simulated with store loyalty)
WITH monthly_store_activity AS (
    SELECT 
        t.id_tienda,
        t.cadena,
        DATE_TRUNC('month', v.fecha) as mes,
        SUM(v.cantidad * v.precio_unitario * (1 - v.descuento_pct/100)) as ventas_mes,
        COUNT(DISTINCT v.ticket_id) as transacciones_mes
    FROM retail.fact_ventas v
    JOIN retail.dim_tienda t ON v.id_tienda = t.id_tienda
    WHERE v.fecha BETWEEN '2024-01-01' AND '2024-12-31'
      AND v.ticket_id IS NOT NULL
    GROUP BY t.id_tienda, t.cadena, DATE_TRUNC('month', v.fecha)
),
store_cohorts AS (
    SELECT 
        cadena,
        mes,
        COUNT(DISTINCT id_tienda) as tiendas_activas,
        AVG(ventas_mes) as venta_promedio_por_tienda,
        SUM(transacciones_mes) as total_transacciones
    FROM monthly_store_activity
    GROUP BY cadena, mes
)
SELECT 
    cadena,
    mes,
    tiendas_activas,
    venta_promedio_por_tienda,
    total_transacciones,
    LAG(tiendas_activas, 1) OVER (PARTITION BY cadena ORDER BY mes) as tiendas_mes_anterior,
    CASE 
        WHEN LAG(tiendas_activas, 1) OVER (PARTITION BY cadena ORDER BY mes) IS NOT NULL THEN
            ROUND((tiendas_activas::numeric / LAG(tiendas_activas, 1) OVER (PARTITION BY cadena ORDER BY mes)) * 100, 2)
        ELSE NULL
    END as retencion_tiendas_pct
FROM store_cohorts
ORDER BY cadena, mes;
