-- 04_load_data.sql
-- Data loading commands using COPY for bulk insert performance
-- Data Engineer II Challenge

SET search_path TO retail, public;

-- =====================================================
-- BULK LOAD COMMANDS
-- =====================================================

-- Load dimension tables first (master data)
-- Note: Run these commands from psql command line, not as a script

-- Load products
-- Include id_producto column to match CSV format
\echo 'Loading products...'
\copy retail.dim_producto(id_producto,sku,nombre_producto,marca,categoria,subcategoria,precio_sugerido) FROM 'data/productos.csv' CSV HEADER ENCODING 'UTF8';

-- Load stores  
-- Include id_tienda column to match CSV format
\echo 'Loading stores...'
\copy retail.dim_tienda(id_tienda,codigo_tienda,nombre_tienda,cadena,formato,region,ciudad,estado,superficie_m2,fecha_apertura) FROM 'data/tiendas.csv' CSV HEADER ENCODING 'UTF8';

-- Load sales data by year (partitioned loading)
\echo 'Loading sales 2021...'
\copy retail.fact_ventas(id_producto,id_tienda,fecha,hora,ticket_id,cantidad,precio_unitario,descuento_pct,canal) FROM 'data/ventas_2021.csv' CSV HEADER ENCODING 'UTF8';

\echo 'Loading sales 2022...'
\copy retail.fact_ventas(id_producto,id_tienda,fecha,hora,ticket_id,cantidad,precio_unitario,descuento_pct,canal) FROM 'data/ventas_2022.csv' CSV HEADER ENCODING 'UTF8';

\echo 'Loading sales 2023...'
\copy retail.fact_ventas(id_producto,id_tienda,fecha,hora,ticket_id,cantidad,precio_unitario,descuento_pct,canal) FROM 'data/ventas_2023.csv' CSV HEADER ENCODING 'UTF8';

\echo 'Loading sales 2024...'
\copy retail.fact_ventas(id_producto,id_tienda,fecha,hora,ticket_id,cantidad,precio_unitario,descuento_pct,canal) FROM 'data/ventas_2024.csv' CSV HEADER ENCODING 'UTF8';

\echo 'Loading sales 2025...'
\copy retail.fact_ventas(id_producto,id_tienda,fecha,hora,ticket_id,cantidad,precio_unitario,descuento_pct,canal) FROM 'data/ventas_2025.csv' CSV HEADER ENCODING 'UTF8';

-- Load inventory data
\echo 'Loading inventory...'
\copy retail.fact_inventario(id_producto,id_tienda,fecha,stock_inicial,stock_final,entradas,salidas,costo_unitario) FROM 'data/inventarios.csv' CSV HEADER ENCODING 'UTF8';

-- =====================================================
-- POST-LOAD VALIDATION
-- =====================================================

-- Update table statistics after bulk load
ANALYZE retail.dim_producto;
ANALYZE retail.dim_tienda;
ANALYZE retail.fact_ventas;
ANALYZE retail.fact_inventario;

-- Data quality checks
\echo 'Running data quality checks...'

-- Check for orphaned records
SELECT 'Orphaned sales records' as check_type, COUNT(*) as count
FROM retail.fact_ventas v
LEFT JOIN retail.dim_producto p ON v.id_producto = p.id_producto
WHERE p.id_producto IS NULL;

SELECT 'Orphaned inventory records' as check_type, COUNT(*) as count  
FROM retail.fact_inventario i
LEFT JOIN retail.dim_producto p ON i.id_producto = p.id_producto
WHERE p.id_producto IS NULL;

-- Check data volumes
SELECT 'Products' as table_name, COUNT(*) as record_count FROM retail.dim_producto
UNION ALL
SELECT 'Stores' as table_name, COUNT(*) as record_count FROM retail.dim_tienda  
UNION ALL
SELECT 'Calendar' as table_name, COUNT(*) as record_count FROM retail.dim_calendario
UNION ALL
SELECT 'Sales' as table_name, COUNT(*) as record_count FROM retail.fact_ventas
UNION ALL
SELECT 'Inventory' as table_name, COUNT(*) as record_count FROM retail.fact_inventario;

-- Check date ranges
SELECT 
    'Sales date range' as check_type,
    MIN(fecha) as min_date,
    MAX(fecha) as max_date,
    COUNT(DISTINCT fecha) as unique_dates
FROM retail.fact_ventas;

\echo 'Data loading completed!';
