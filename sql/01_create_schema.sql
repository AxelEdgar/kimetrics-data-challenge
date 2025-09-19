-- 01_create_schema.sql
-- Retail Analytics Data Model - PostgreSQL Implementation
-- Data Engineer II Challenge

-- Create schema
CREATE SCHEMA IF NOT EXISTS retail AUTHORIZATION postgres;

-- Set search path for convenience
SET search_path TO retail, public;

-- =====================================================
-- DIMENSION TABLES
-- =====================================================

-- Dimension: Products
-- Contains product master data with brand, category hierarchy
CREATE TABLE retail.dim_producto (
    id_producto       SERIAL PRIMARY KEY,
    sku               VARCHAR(50) NOT NULL UNIQUE,
    nombre_producto   VARCHAR(200) NOT NULL,
    marca             VARCHAR(100) NOT NULL,
    categoria         VARCHAR(50) NOT NULL,
    subcategoria      VARCHAR(50),
    precio_sugerido   NUMERIC(12,2) CHECK (precio_sugerido >= 0),
    activo            BOOLEAN DEFAULT true,
    created_at        TIMESTAMP WITH TIME ZONE DEFAULT now(),
    updated_at        TIMESTAMP WITH TIME ZONE DEFAULT now()
);

-- Dimension: Stores
-- Contains store hierarchy: chain -> format -> individual store
CREATE TABLE retail.dim_tienda (
    id_tienda         SERIAL PRIMARY KEY,
    codigo_tienda     VARCHAR(20) NOT NULL UNIQUE,
    nombre_tienda     VARCHAR(200) NOT NULL,
    cadena            VARCHAR(100) NOT NULL,
    formato           VARCHAR(50) NOT NULL, -- Super, Express, Hiper
    region            VARCHAR(50) NOT NULL,
    ciudad            VARCHAR(100) NOT NULL,
    estado            VARCHAR(50),
    codigo_postal     VARCHAR(10),
    superficie_m2     INTEGER CHECK (superficie_m2 > 0),
    fecha_apertura    DATE,
    activo            BOOLEAN DEFAULT true,
    created_at        TIMESTAMP WITH TIME ZONE DEFAULT now(),
    updated_at        TIMESTAMP WITH TIME ZONE DEFAULT now()
);

-- Dimension: Calendar
-- Pre-populated calendar dimension for time-based analysis
CREATE TABLE retail.dim_calendario (
    fecha             DATE PRIMARY KEY,
    dia               INTEGER NOT NULL,
    dia_semana        INTEGER NOT NULL, -- 1=Monday, 7=Sunday
    nombre_dia        VARCHAR(20) NOT NULL,
    semana_anno       INTEGER NOT NULL,
    mes               INTEGER NOT NULL,
    nombre_mes        VARCHAR(20) NOT NULL,
    trimestre         INTEGER NOT NULL,
    anno              INTEGER NOT NULL,
    es_fin_de_semana  BOOLEAN NOT NULL,
    es_festivo        BOOLEAN DEFAULT false,
    nombre_festivo    VARCHAR(100),
    periodo_fiscal    VARCHAR(10) -- Q1-2024, Q2-2024, etc.
);

-- =====================================================
-- FACT TABLES (Partitioned by date for performance)
-- =====================================================

-- Fact: Sales Transactions
-- Main transactional table with sales data
CREATE TABLE retail.fact_ventas (
    venta_id          BIGSERIAL,
    id_producto       INTEGER NOT NULL,
    id_tienda         INTEGER NOT NULL,
    fecha             DATE NOT NULL,
    hora              TIME,
    ticket_id         VARCHAR(50), -- Groups items in same transaction
    cantidad          INTEGER NOT NULL CHECK (cantidad > 0),
    precio_unitario   NUMERIC(12,2) NOT NULL CHECK (precio_unitario >= 0),
    descuento_pct     NUMERIC(5,2) DEFAULT 0 CHECK (descuento_pct >= 0 AND descuento_pct <= 100),
    impuesto_pct      NUMERIC(5,2) DEFAULT 16 CHECK (impuesto_pct >= 0),
    canal             VARCHAR(20) DEFAULT 'in-store', -- in-store, online, mobile
    vendedor_id       INTEGER,
    created_at        TIMESTAMP WITH TIME ZONE DEFAULT now(),
    PRIMARY KEY (venta_id, fecha) -- Composite key for partitioning
) PARTITION BY RANGE (fecha);

-- Create partitions for each year (2021-2025)
CREATE TABLE retail.fact_ventas_2021 PARTITION OF retail.fact_ventas 
    FOR VALUES FROM ('2021-01-01') TO ('2022-01-01');
CREATE TABLE retail.fact_ventas_2022 PARTITION OF retail.fact_ventas 
    FOR VALUES FROM ('2022-01-01') TO ('2023-01-01');
CREATE TABLE retail.fact_ventas_2023 PARTITION OF retail.fact_ventas 
    FOR VALUES FROM ('2023-01-01') TO ('2024-01-01');
CREATE TABLE retail.fact_ventas_2024 PARTITION OF retail.fact_ventas 
    FOR VALUES FROM ('2024-01-01') TO ('2025-01-01');
CREATE TABLE retail.fact_ventas_2025 PARTITION OF retail.fact_ventas 
    FOR VALUES FROM ('2025-01-01') TO ('2026-01-01');
CREATE TABLE retail.fact_ventas_default PARTITION OF retail.fact_ventas DEFAULT;

-- Fact: Inventory Snapshots
-- Periodic inventory levels by product and store
CREATE TABLE retail.fact_inventario (
    inventario_id     BIGSERIAL PRIMARY KEY,
    id_producto       INTEGER NOT NULL,
    id_tienda         INTEGER NOT NULL,
    fecha             DATE NOT NULL,
    stock_inicial     INTEGER NOT NULL CHECK (stock_inicial >= 0),
    stock_final       INTEGER NOT NULL CHECK (stock_final >= 0),
    entradas          INTEGER DEFAULT 0 CHECK (entradas >= 0),
    salidas           INTEGER DEFAULT 0 CHECK (salidas >= 0),
    costo_unitario    NUMERIC(12,2) CHECK (costo_unitario >= 0),
    valor_inventario  NUMERIC(15,2) GENERATED ALWAYS AS (stock_final * costo_unitario) STORED,
    created_at        TIMESTAMP WITH TIME ZONE DEFAULT now(),
    UNIQUE (id_producto, id_tienda, fecha)
);

-- =====================================================
-- FOREIGN KEY CONSTRAINTS
-- =====================================================

-- Sales fact table constraints
ALTER TABLE retail.fact_ventas
    ADD CONSTRAINT fk_ventas_producto 
        FOREIGN KEY (id_producto) REFERENCES retail.dim_producto(id_producto),
    ADD CONSTRAINT fk_ventas_tienda 
        FOREIGN KEY (id_tienda) REFERENCES retail.dim_tienda(id_tienda),
    ADD CONSTRAINT fk_ventas_fecha 
        FOREIGN KEY (fecha) REFERENCES retail.dim_calendario(fecha);

-- Inventory fact table constraints
ALTER TABLE retail.fact_inventario
    ADD CONSTRAINT fk_inventario_producto 
        FOREIGN KEY (id_producto) REFERENCES retail.dim_producto(id_producto),
    ADD CONSTRAINT fk_inventario_tienda 
        FOREIGN KEY (id_tienda) REFERENCES retail.dim_tienda(id_tienda),
    ADD CONSTRAINT fk_inventario_fecha 
        FOREIGN KEY (fecha) REFERENCES retail.dim_calendario(fecha);

-- =====================================================
-- BUSINESS RULES & DATA QUALITY CONSTRAINTS
-- =====================================================

-- Ensure product names are not empty
ALTER TABLE retail.dim_producto 
    ADD CONSTRAINT chk_producto_nombre_not_empty 
        CHECK (LENGTH(TRIM(nombre_producto)) > 0);

-- Ensure store names are not empty
ALTER TABLE retail.dim_tienda 
    ADD CONSTRAINT chk_tienda_nombre_not_empty 
        CHECK (LENGTH(TRIM(nombre_tienda)) > 0);

-- Ensure valid sales channels
ALTER TABLE retail.fact_ventas 
    ADD CONSTRAINT chk_canal_valido 
        CHECK (canal IN ('in-store', 'online', 'mobile', 'phone'));

-- Ensure inventory balance makes sense
ALTER TABLE retail.fact_inventario 
    ADD CONSTRAINT chk_inventario_balance 
        CHECK (stock_inicial + entradas - salidas = stock_final);

-- =====================================================
-- SEQUENCE MANAGEMENT FOR EXPLICIT ID LOADING
-- =====================================================

-- Add sequence reset commands to handle explicit ID loading
-- These commands should be run after data loading to sync sequences

-- Reset product sequence to max ID + 1
-- SELECT setval('retail.dim_producto_id_producto_seq', (SELECT MAX(id_producto) FROM retail.dim_producto));

-- Reset store sequence to max ID + 1  
-- SELECT setval('retail.dim_tienda_id_tienda_seq', (SELECT MAX(id_tienda) FROM retail.dim_tienda));

-- =====================================================
-- COMMENTS FOR DOCUMENTATION
-- =====================================================

COMMENT ON SCHEMA retail IS 'Retail analytics data warehouse schema';

COMMENT ON TABLE retail.dim_producto IS 'Product dimension - master data for all products';
COMMENT ON COLUMN retail.dim_producto.sku IS 'Stock Keeping Unit - unique product identifier';
COMMENT ON COLUMN retail.dim_producto.precio_sugerido IS 'Manufacturer suggested retail price';

COMMENT ON TABLE retail.dim_tienda IS 'Store dimension - hierarchy from chain to individual store';
COMMENT ON COLUMN retail.dim_tienda.formato IS 'Store format: Super, Express, Hiper';
COMMENT ON COLUMN retail.dim_tienda.superficie_m2 IS 'Store floor area in square meters';

COMMENT ON TABLE retail.dim_calendario IS 'Calendar dimension for time-based analysis';
COMMENT ON COLUMN retail.dim_calendario.periodo_fiscal IS 'Fiscal period identifier (Q1-2024, etc.)';

COMMENT ON TABLE retail.fact_ventas IS 'Sales fact table - partitioned by date for performance';
COMMENT ON COLUMN retail.fact_ventas.ticket_id IS 'Groups multiple items in same transaction';
COMMENT ON COLUMN retail.fact_ventas.descuento_pct IS 'Discount percentage applied to item';

COMMENT ON TABLE retail.fact_inventario IS 'Inventory fact table - periodic stock snapshots';
COMMENT ON COLUMN retail.fact_inventario.valor_inventario IS 'Calculated inventory value (stock * cost)';
