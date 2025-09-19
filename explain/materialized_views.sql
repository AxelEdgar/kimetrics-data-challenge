-- explain/materialized_views.sql
-- Creación de Vistas Materializadas para optimizar consultas de BI y dashboards
-- Data Engineer II Challenge

SET search_path TO retail, public;

-- ====================================================================
-- VISTA 1: Resumen de Ventas Diarias (mv_daily_sales_summary)
-- Objetivo: Acelerar el KPI principal del dashboard ejecutivo.
-- ====================================================================

-- Elimina la vista si ya existe para permitir la re-ejecución del script
DROP MATERIALIZED VIEW IF EXISTS retail.mv_daily_sales_summary;

CREATE MATERIALIZED VIEW retail.mv_daily_sales_summary AS
SELECT 
    c.fecha,
    c.anno,
    c.mes,
    c.nombre_mes,
    c.nombre_dia, -- CORREGIDO
    t.cadena,
    t.formato,
    t.region,
    COUNT(DISTINCT v.ticket_id) as total_transacciones,
    SUM(v.cantidad) as total_unidades_vendidas,
    SUM(v.cantidad * v.precio_unitario * (1 - v.descuento_pct/100)) as ventas_netas
FROM retail.fact_ventas v
JOIN retail.dim_tienda t ON v.id_tienda = t.id_tienda
JOIN retail.dim_calendario c ON v.fecha = c.fecha
GROUP BY 
    c.fecha, c.anno, c.mes, c.nombre_mes, c.nombre_dia, -- CORREGIDO
    t.cadena, t.formato, t.region;

-- Crea índices sobre la vista materializada para hacerla aún más rápida
CREATE INDEX idx_mv_daily_sales_fecha ON retail.mv_daily_sales_summary(fecha);
CREATE INDEX idx_mv_daily_sales_cadena ON retail.mv_daily_sales_summary(cadena);
CREATE INDEX idx_mv_daily_sales_region ON retail.mv_daily_sales_summary(region);

COMMENT ON MATERIALIZED VIEW retail.mv_daily_sales_summary IS 'Agregado diario de ventas para dashboards. Refrescar diariamente.';

-- ====================================================================
-- VISTA 2: Rendimiento de Productos (mv_product_performance)
-- Objetivo: Acelerar el análisis de top productos por mes y categoría.
-- ====================================================================

DROP MATERIALIZED VIEW IF EXISTS retail.mv_product_performance;

CREATE MATERIALIZED VIEW retail.mv_product_performance AS
WITH monthly_product_sales AS (
    SELECT
        DATE_TRUNC('month', v.fecha)::date as mes,
        p.id_producto,
        p.nombre_producto,
        p.categoria,
        p.marca,
        SUM(v.cantidad) as unidades_vendidas,
        SUM(v.cantidad * v.precio_unitario * (1 - v.descuento_pct/100)) as ventas_netas
    FROM retail.fact_ventas v
    JOIN retail.dim_producto p ON v.id_producto = p.id_producto
    GROUP BY 1, 2, 3, 4, 5
)
SELECT
    mes,
    id_producto,
    nombre_producto,
    categoria,
    marca,
    unidades_vendidas,
    ventas_netas,
    RANK() OVER (PARTITION BY categoria, mes ORDER BY ventas_netas DESC) as ranking_categoria_mes
FROM monthly_product_sales;

CREATE INDEX idx_mv_product_perf_mes ON retail.mv_product_performance(mes);
CREATE INDEX idx_mv_product_perf_categoria ON retail.mv_product_performance(categoria);

COMMENT ON MATERIALIZED VIEW retail.mv_product_performance IS 'Ranking mensual de productos por ventas netas. Refrescar mensualmente.';

-- ====================================================================
-- Refrescar las Vistas
-- En un entorno de producción, esto sería un job agendado.
-- ====================================================================
-- NOTA: La primera vez que se crea una vista materializada, se puebla automáticamente.
-- Para actualizarla, se debe ejecutar el siguiente comando:

/*
REFRESH MATERIALIZED VIEW CONCURRENTLY retail.mv_daily_sales_summary;
REFRESH MATERIALIZED VIEW CONCURRENTLY retail.mv_product_performance;
*/

-- (CONCURRENTLY requiere un índice UNIQUE en la vista, lo omitimos por simplicidad en el challenge)

REFRESH MATERIALIZED VIEW retail.mv_daily_sales_summary;
REFRESH MATERIALIZED VIEW retail.mv_product_performance;

SELECT 'Vistas materializadas creadas y refrescadas exitosamente.' as status;