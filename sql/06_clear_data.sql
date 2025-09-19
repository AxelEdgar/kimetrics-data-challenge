-- 06_clear_data.sql
-- Clear existing data before reloading
-- Data Engineer II Challenge

SET search_path TO retail, public;

-- Clear fact tables first (due to foreign key constraints)
\echo 'Clearing sales data...'
TRUNCATE TABLE retail.fact_ventas CASCADE;

\echo 'Clearing inventory data...'
TRUNCATE TABLE retail.fact_inventario CASCADE;

-- Clear dimension tables
\echo 'Clearing stores data...'
TRUNCATE TABLE retail.dim_tienda CASCADE;

\echo 'Clearing products data...'
TRUNCATE TABLE retail.dim_producto CASCADE;

-- Reset sequences to start from 1
ALTER SEQUENCE retail.dim_producto_id_producto_seq RESTART WITH 1;
ALTER SEQUENCE retail.dim_tienda_id_tienda_seq RESTART WITH 1;

\echo 'Data cleared successfully!';
