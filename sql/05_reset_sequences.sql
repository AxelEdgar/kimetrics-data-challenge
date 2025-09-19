-- 05_reset_sequences.sql
-- Reset sequences after loading data with explicit IDs
-- Data Engineer II Challenge

SET search_path TO retail, public;

-- =====================================================
-- SEQUENCE RESET COMMANDS
-- =====================================================

-- Reset product sequence to max ID + 1
-- This ensures new inserts don't conflict with loaded data
SELECT setval('retail.dim_producto_id_producto_seq', 
    COALESCE((SELECT MAX(id_producto) FROM retail.dim_producto), 1), 
    false);

-- Reset store sequence to max ID + 1
SELECT setval('retail.dim_tienda_id_tienda_seq', 
    COALESCE((SELECT MAX(id_tienda) FROM retail.dim_tienda), 1), 
    false);

-- Verify sequence values
SELECT 'dim_producto' as table_name, 
       currval('retail.dim_producto_id_producto_seq') as current_sequence_value,
       (SELECT MAX(id_producto) FROM retail.dim_producto) as max_table_id;

SELECT 'dim_tienda' as table_name,
       currval('retail.dim_tienda_id_tienda_seq') as current_sequence_value, 
       (SELECT MAX(id_tienda) FROM retail.dim_tienda) as max_table_id;

\echo 'Sequences reset successfully!';
