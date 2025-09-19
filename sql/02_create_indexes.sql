-- 02_create_indexes.sql
-- Performance indexes for retail analytics queries
-- Data Engineer II Challenge

SET search_path TO retail, public;

-- =====================================================
-- DIMENSION TABLE INDEXES
-- =====================================================

-- Product dimension indexes
CREATE INDEX idx_producto_categoria ON retail.dim_producto (categoria);
CREATE INDEX idx_producto_marca ON retail.dim_producto (marca);
CREATE INDEX idx_producto_activo ON retail.dim_producto (activo) WHERE activo = true;
CREATE INDEX idx_producto_sku ON retail.dim_producto (sku); -- Already unique, but for lookups

-- Store dimension indexes
CREATE INDEX idx_tienda_cadena ON retail.dim_tienda (cadena);
CREATE INDEX idx_tienda_region ON retail.dim_tienda (region);
CREATE INDEX idx_tienda_formato ON retail.dim_tienda (formato);
CREATE INDEX idx_tienda_activo ON retail.dim_tienda (activo) WHERE activo = true;
CREATE INDEX idx_tienda_cadena_region ON retail.dim_tienda (cadena, region);

-- Calendar dimension indexes
CREATE INDEX idx_calendario_anno ON retail.dim_calendario (anno);
CREATE INDEX idx_calendario_mes ON retail.dim_calendario (anno, mes);
CREATE INDEX idx_calendario_trimestre ON retail.dim_calendario (anno, trimestre);
CREATE INDEX idx_calendario_fin_semana ON retail.dim_calendario (es_fin_de_semana);

-- =====================================================
-- FACT TABLE INDEXES (Applied to each partition)
-- =====================================================

-- Sales fact table indexes - these will be created on each partition
-- Main query patterns: filter by date, join by product/store, group by time periods

-- Primary lookup indexes
CREATE INDEX idx_ventas_fecha ON retail.fact_ventas (fecha);
CREATE INDEX idx_ventas_producto ON retail.fact_ventas (id_producto);
CREATE INDEX idx_ventas_tienda ON retail.fact_ventas (id_tienda);

-- Composite indexes for common query patterns
CREATE INDEX idx_ventas_fecha_tienda ON retail.fact_ventas (fecha, id_tienda);
CREATE INDEX idx_ventas_fecha_producto ON retail.fact_ventas (fecha, id_producto);
CREATE INDEX idx_ventas_tienda_producto ON retail.fact_ventas (id_tienda, id_producto);

-- Ticket analysis index
CREATE INDEX idx_ventas_ticket ON retail.fact_ventas (ticket_id, fecha) WHERE ticket_id IS NOT NULL;

-- Channel analysis index
CREATE INDEX idx_ventas_canal ON retail.fact_ventas (canal, fecha);

-- Time-based analysis (for hourly patterns)
CREATE INDEX idx_ventas_hora ON retail.fact_ventas (fecha, hora) WHERE hora IS NOT NULL;

-- Inventory fact table indexes
CREATE INDEX idx_inventario_fecha ON retail.fact_inventario (fecha);
CREATE INDEX idx_inventario_producto ON retail.fact_inventario (id_producto);
CREATE INDEX idx_inventario_tienda ON retail.fact_inventario (id_tienda);
CREATE INDEX idx_inventario_fecha_tienda ON retail.fact_inventario (fecha, id_tienda);
CREATE INDEX idx_inventario_producto_tienda ON retail.fact_inventario (id_producto, id_tienda);

-- Low stock analysis index
CREATE INDEX idx_inventario_stock_bajo ON retail.fact_inventario (id_tienda, id_producto, fecha) 
    WHERE stock_final < 10;

-- =====================================================
-- SPECIALIZED INDEXES FOR BUSINESS QUERIES
-- =====================================================

-- Index for top products analysis (covering index)
CREATE INDEX idx_ventas_top_productos ON retail.fact_ventas (id_producto, fecha) 
    INCLUDE (cantidad, precio_unitario);

-- Index for regional sales analysis
CREATE INDEX idx_ventas_regional ON retail.fact_ventas (fecha, id_tienda) 
    INCLUDE (cantidad, precio_unitario);

-- Index for seasonal analysis
CREATE INDEX idx_ventas_estacional ON retail.fact_ventas (fecha, id_producto) 
    INCLUDE (cantidad, precio_unitario);

-- =====================================================
-- MAINTENANCE INDEXES
-- =====================================================

-- Indexes for data loading and ETL processes
CREATE INDEX idx_ventas_created_at ON retail.fact_ventas (created_at);
CREATE INDEX idx_inventario_created_at ON retail.fact_inventario (created_at);

-- =====================================================
-- INDEX STATISTICS AND COMMENTS
-- =====================================================

-- Update table statistics for better query planning
ANALYZE retail.dim_producto;
ANALYZE retail.dim_tienda;
ANALYZE retail.dim_calendario;

-- Comments for index documentation
COMMENT ON INDEX retail.idx_ventas_fecha_tienda IS 'Composite index for daily sales by store queries';
COMMENT ON INDEX retail.idx_ventas_top_productos IS 'Covering index for top products analysis';
COMMENT ON INDEX retail.idx_inventario_stock_bajo IS 'Partial index for low stock alerts';
