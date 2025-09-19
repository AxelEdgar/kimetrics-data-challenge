#!/bin/bash
# deploy_to_rds.sh
# Automated deployment script for AWS RDS
# Data Engineer II Challenge

set -e  # Exit on any error

echo "🚀 Data Engineer II Challenge - RDS Deployment Script"
echo "=================================================="

# Configuration
RDS_ENDPOINT=${1:-"your-rds-endpoint.amazonaws.com"}
DB_NAME="retail"
DB_USER="postgres"
DB_PASSWORD=${2:-"your-password"}

if [ "$RDS_ENDPOINT" = "your-rds-endpoint.amazonaws.com" ]; then
    echo "❌ Error: Please provide RDS endpoint as first argument"
    echo "Usage: $0 <rds-endpoint> [password]"
    exit 1
fi

echo "📊 Target RDS: $RDS_ENDPOINT"
echo "📅 Database: $DB_NAME"

# Test connection
echo "🔍 Testing connection..."
psql -h $RDS_ENDPOINT -U $DB_USER -d postgres -c "SELECT version();" || {
    echo "❌ Connection failed. Check endpoint and credentials."
    exit 1
}

echo "✅ Connection successful!"

# Step 1: Create schema
echo "🏗️  Creating schema and tables..."
psql -h $RDS_ENDPOINT -U $DB_USER -d $DB_NAME -f sql/01_create_schema.sql

# Step 2: Populate calendar
echo "📅 Populating calendar dimension..."
psql -h $RDS_ENDPOINT -U $DB_USER -d $DB_NAME -f sql/03_populate_calendar.sql

# Step 3: Load data (check if files exist)
echo "📦 Loading data..."
if [ ! -f "data/productos.csv" ]; then
    echo "⚠️  Data files not found. Running data generation..."
    python3 00_generate_data.py
fi

# Load dimension data
echo "  📋 Loading products..."
psql -h $RDS_ENDPOINT -U $DB_USER -d $DB_NAME -c "\copy retail.dim_producto(sku,nombre_producto,marca,categoria,subcategoria,precio_sugerido) FROM 'data/productos.csv' CSV HEADER;"

echo "  🏪 Loading stores..."
psql -h $RDS_ENDPOINT -U $DB_USER -d $DB_NAME -c "\copy retail.dim_tienda(codigo_tienda,nombre_tienda,cadena,formato,region,ciudad,estado,superficie_m2,fecha_apertura) FROM 'data/tiendas.csv' CSV HEADER;"

# Load fact data by year
for year in 2021 2022 2023 2024 2025; do
    if [ -f "data/ventas_${year}.csv" ]; then
        echo "  💰 Loading sales $year..."
        psql -h $RDS_ENDPOINT -U $DB_USER -d $DB_NAME -c "\copy retail.fact_ventas(id_producto,id_tienda,fecha,hora,ticket_id,cantidad,precio_unitario,descuento_pct,canal) FROM 'data/ventas_${year}.csv' CSV HEADER;"
    fi
done

echo "  📦 Loading inventory..."
psql -h $RDS_ENDPOINT -U $DB_USER -d $DB_NAME -c "\copy retail.fact_inventario(id_producto,id_tienda,fecha,stock_inicial,stock_final,entradas,salidas,costo_unitario) FROM 'data/inventarios.csv' CSV HEADER;"

# Step 4: Create indexes
echo "⚡ Creating optimized indexes..."
psql -h $RDS_ENDPOINT -U $DB_USER -d $DB_NAME -f sql/02_create_indexes.sql

# Step 5: Create materialized views
echo "📊 Creating materialized views..."
psql -h $RDS_ENDPOINT -U $DB_USER -d $DB_NAME -f explain/materialized_views.sql

# Step 6: Create reviewer user
echo "👤 Creating reviewer user..."
psql -h $RDS_ENDPOINT -U $DB_USER -d $DB_NAME << 'EOF'
DO $$
BEGIN
    IF NOT EXISTS (SELECT FROM pg_catalog.pg_roles WHERE rolname = 'kimetrics_reviewer') THEN
        CREATE USER kimetrics_reviewer WITH PASSWORD 'KimetricsCh4ll3ng3!';
    END IF;
END
$$;

GRANT CONNECT ON DATABASE retail TO kimetrics_reviewer;
GRANT USAGE ON SCHEMA retail TO kimetrics_reviewer;
GRANT SELECT ON ALL TABLES IN SCHEMA retail TO kimetrics_reviewer;
GRANT SELECT ON ALL SEQUENCES IN SCHEMA retail TO kimetrics_reviewer;
ALTER DEFAULT PRIVILEGES IN SCHEMA retail GRANT SELECT ON TABLES TO kimetrics_reviewer;
EOF

# Step 7: Validation
echo "🔍 Running validation checks..."
psql -h $RDS_ENDPOINT -U $DB_USER -d $DB_NAME << 'EOF'
-- Data volume check
SELECT 'Products' as table_name, COUNT(*) as records FROM retail.dim_producto
UNION ALL
SELECT 'Stores', COUNT(*) FROM retail.dim_tienda  
UNION ALL
SELECT 'Calendar', COUNT(*) FROM retail.dim_calendario
UNION ALL
SELECT 'Sales', COUNT(*) FROM retail.fact_ventas
UNION ALL
SELECT 'Inventory', COUNT(*) FROM retail.fact_inventario;

-- Date range check
SELECT 
    'Sales date range' as check_type,
    MIN(fecha) as min_date,
    MAX(fecha) as max_date,
    COUNT(DISTINCT fecha) as unique_dates
FROM retail.fact_ventas;

-- MV check
SELECT 'Materialized Views' as check_type, COUNT(*) as count
FROM pg_matviews WHERE schemaname = 'retail';
EOF

# Step 8: Performance test
echo "⚡ Running performance test..."
psql -h $RDS_ENDPOINT -U $DB_USER -d $DB_NAME << 'EOF'
\timing on
-- Test optimized query
SELECT 
    fecha,
    cadena,
    SUM(cantidad * precio_unitario * (1 - descuento_pct/100)) as ventas_netas
FROM retail.fact_ventas v
JOIN retail.dim_tienda t ON v.id_tienda = t.id_tienda
WHERE fecha BETWEEN '2024-10-01' AND '2024-12-31'
GROUP BY fecha, cadena
ORDER BY fecha DESC, ventas_netas DESC
LIMIT 10;
\timing off
EOF

echo ""
echo "✅ Deployment completed successfully!"
echo ""
echo "📊 Connection Information:"
echo "Host: $RDS_ENDPOINT"
echo "Port: 5432"
echo "Database: $DB_NAME"
echo "Reviewer User: kimetrics_reviewer"
echo "Reviewer Password: KimetricsCh4ll3ng3!"
echo ""
echo "🔍 Test Queries:"
echo "SELECT * FROM retail.mv_daily_sales_summary LIMIT 5;"
echo "SELECT * FROM retail.mv_product_performance WHERE ranking_categoria_mes <= 3;"
echo "SELECT * FROM retail.mv_inventory_alerts WHERE alerta_inventario = 'STOCK_BAJO';"
echo ""
echo "⚠️  Remember to:"
echo "1. Remove public access after validation"
echo "2. Delete instance to avoid charges"
echo "3. Send connection info to reviewer"
