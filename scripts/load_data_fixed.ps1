# load_data_fixed.ps1
# Fixed data loading script for PowerShell on Windows 11
# Data Engineer II Challenge

# Set error action preference to stop on errors
$ErrorActionPreference = "Stop"

# Database connection parameters
$DB_HOST = if ($env:DB_HOST) { $env:DB_HOST } else { "kimetrics-challenge-db.cgbk2ksi4vny.us-east-1.rds.amazonaws.com" }
$DB_USER = if ($env:DB_USER) { $env:DB_USER } else { "postgres" }
$DB_NAME = if ($env:DB_NAME) { $env:DB_NAME } else { "retail" }

Write-Host "🔄 Starting fixed data loading process..." -ForegroundColor Cyan
Write-Host "📡 Connecting to: $DB_HOST" -ForegroundColor Yellow

# Function to run SQL file with error handling
function Run-SqlFile {
    param(
        [string]$FilePath,
        [string]$Description
    )
    
    Write-Host "📋 $Description..." -ForegroundColor Blue
    
    try {
        # Convert relative path to absolute path for Windows
        $AbsolutePath = Resolve-Path $FilePath -ErrorAction Stop
        
        # Run psql command
        & psql -h $DB_HOST -U $DB_USER -d $DB_NAME -f $AbsolutePath
        
        if ($LASTEXITCODE -eq 0) {
            Write-Host "✅ $Description completed successfully" -ForegroundColor Green
        } else {
            throw "psql command failed with exit code $LASTEXITCODE"
        }
    }
    catch {
        Write-Host "❌ Error in $Description" -ForegroundColor Red
        Write-Host "Error details: $($_.Exception.Message)" -ForegroundColor Red
        exit 1
    }
}

# Step 1: Ensure schema exists
Run-SqlFile "sql\01_create_schema.sql" "Creating schema and tables"

# Step 2: Populate calendar
Run-SqlFile "sql\03_populate_calendar.sql" "Populating calendar dimension"

# Step 3: Generate fresh data (if needed)
if (-not (Test-Path "data\productos.csv")) {
    Write-Host "📊 Generating fresh data..." -ForegroundColor Yellow
    try {
        python 00_generate_data.py
        if ($LASTEXITCODE -ne 0) {
            throw "Python script failed with exit code $LASTEXITCODE"
        }
    }
    catch {
        Write-Host "❌ Error generating data: $($_.Exception.Message)" -ForegroundColor Red
        exit 1
    }
}

# Step 4: Load data with fixed column mappings
Run-SqlFile "sql\04_load_data.sql" "Loading business data"

# Step 5: Reset sequences
Run-SqlFile "sql\05_reset_sequences.sql" "Resetting sequences"

# Step 6: Create indexes for performance
Run-SqlFile "sql\02_create_indexes.sql" "Creating indexes"

# Step 7: Final validation
Write-Host "🔍 Running final data validation..." -ForegroundColor Blue

$ValidationQuery = @"
SELECT 
    'Products' as table_name, 
    COUNT(*) as records,
    MIN(id_producto) as min_id,
    MAX(id_producto) as max_id
FROM retail.dim_producto
UNION ALL
SELECT 
    'Stores' as table_name, 
    COUNT(*) as records,
    MIN(id_tienda) as min_id,
    MAX(id_tienda) as max_id  
FROM retail.dim_tienda
UNION ALL
SELECT 
    'Sales' as table_name, 
    COUNT(*) as records,
    MIN(id_producto) as min_product_id,
    MAX(id_producto) as max_product_id
FROM retail.fact_ventas
UNION ALL
SELECT 
    'Inventory' as table_name, 
    COUNT(*) as records,
    MIN(id_producto) as min_product_id,
    MAX(id_producto) as max_product_id
FROM retail.fact_inventario;
"@

try {
    & psql -h $DB_HOST -U $DB_USER -d $DB_NAME -c $ValidationQuery
    if ($LASTEXITCODE -ne 0) {
        throw "Validation query failed with exit code $LASTEXITCODE"
    }
}
catch {
    Write-Host "❌ Error in validation: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}

Write-Host "✅ Data loading process completed successfully!" -ForegroundColor Green
Write-Host "🎯 Next steps:" -ForegroundColor Cyan
Write-Host "   • Run business queries: psql -h $DB_HOST -U $DB_USER -d $DB_NAME -f queries\business_cases.sql" -ForegroundColor White
Write-Host "   • Test performance: psql -h $DB_HOST -U $DB_USER -d $DB_NAME -f explain\01_daily_sales_query.sql" -ForegroundColor White
Write-Host "   • View documentation: docs\diccionario_datos.md" -ForegroundColor White

Write-Host "`n💡 To run this script, use: .\scripts\load_data_fixed.ps1" -ForegroundColor Yellow
