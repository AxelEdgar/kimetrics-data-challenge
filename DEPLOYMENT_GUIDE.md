# Guía de Despliegue AWS RDS
**Data Engineer II Challenge - Retail Analytics**

## 🎯 Objetivo

Desplegar el modelo de datos de retail analytics en AWS RDS PostgreSQL Free Tier para validación del challenge.

## 📋 Pre-requisitos

- Cuenta AWS activa
- AWS CLI configurado (opcional)
- Cliente PostgreSQL (psql, pgAdmin, DBeaver)
- Datos generados localmente (`python 00_generate_data.py`)

## 🚀 Paso 1: Crear Instancia RDS

### Via AWS Console

1. **Navegar a RDS**
   - Ir a AWS Console → RDS → Create database

2. **Configuración del Motor**
   ```
   Engine type: PostgreSQL
   Version: PostgreSQL 15.x (latest)
   Templates: Free tier
   ```

3. **Configuración de la Instancia**
   ```
   DB instance identifier: retail-analytics-challenge
   Master username: postgres
   Master password: [SECURE_PASSWORD]
   DB instance class: db.t3.micro
   ```

4. **Almacenamiento**
   ```
   Storage type: General Purpose SSD (gp2)
   Allocated storage: 20 GB
   Enable storage autoscaling: No
   ```

5. **Conectividad**
   ```
   VPC: Default VPC
   Subnet group: default
   Public access: Yes (SOLO para validación)
   VPC security group: Create new
   Database port: 5432
   ```

6. **Configuración Adicional**
   ```
   Initial database name: retail
   DB parameter group: default.postgres15
   Backup retention: 1 day
   Monitoring: Enable Enhanced Monitoring (1 minute)
   Log exports: PostgreSQL log
   ```

### Via AWS CLI (Alternativo)

```bash
aws rds create-db-instance \
    --db-instance-identifier retail-analytics-challenge \
    --db-instance-class db.t3.micro \
    --engine postgres \
    --engine-version 15.4 \
    --master-username postgres \
    --master-user-password YOUR_SECURE_PASSWORD \
    --allocated-storage 20 \
    --vpc-security-group-ids sg-xxxxxxxxx \
    --db-name retail \
    --publicly-accessible \
    --no-multi-az \
    --storage-type gp2 \
    --enable-cloudwatch-logs-exports postgresql
```

## 🔐 Paso 2: Configurar Seguridad

### Security Group

1. **Crear Security Group**
   ```
   Name: retail-analytics-sg
   Description: Security group for retail analytics RDS
   VPC: Default VPC
   ```

2. **Reglas de Entrada**
   ```
   Type: PostgreSQL
   Protocol: TCP
   Port: 5432
   Source: Your IP address (My IP)
   Description: PostgreSQL access for validation
   ```

### Usuario de Validación

```sql
-- Conectar como postgres
CREATE USER kimetrics_reviewer WITH PASSWORD 'secure_reviewer_password';
GRANT CONNECT ON DATABASE retail TO kimetrics_reviewer;
GRANT USAGE ON SCHEMA retail TO kimetrics_reviewer;
GRANT SELECT ON ALL TABLES IN SCHEMA retail TO kimetrics_reviewer;
GRANT SELECT ON ALL SEQUENCES IN SCHEMA retail TO kimetrics_reviewer;

-- Para futuras tablas
ALTER DEFAULT PRIVILEGES IN SCHEMA retail 
GRANT SELECT ON TABLES TO kimetrics_reviewer;
```

## 📊 Paso 3: Desplegar Esquema y Datos

### 3.1 Crear Esquema

```bash
# Obtener endpoint de RDS
export RDS_ENDPOINT="your-instance.xxxxxxxxx.region.rds.amazonaws.com"

# Crear esquema
psql -h $RDS_ENDPOINT -U postgres -d retail -f sql/01_create_schema.sql
```

### 3.2 Poblar Calendario

```bash
psql -h $RDS_ENDPOINT -U postgres -d retail -f sql/03_populate_calendar.sql
```

### 3.3 Cargar Datos

```bash
# Subir archivos CSV a instancia (si es necesario)
# O usar \copy desde cliente local

psql -h $RDS_ENDPOINT -U postgres -d retail << 'EOF'
\copy retail.dim_producto(sku,nombre_producto,marca,categoria,subcategoria,precio_sugerido) FROM 'data/productos.csv' CSV HEADER;
\copy retail.dim_tienda(codigo_tienda,nombre_tienda,cadena,formato,region,ciudad,estado,superficie_m2,fecha_apertura) FROM 'data/tiendas.csv' CSV HEADER;
\copy retail.fact_ventas(id_producto,id_tienda,fecha,hora,ticket_id,cantidad,precio_unitario,descuento_pct,canal) FROM 'data/ventas_2021.csv' CSV HEADER;
\copy retail.fact_ventas(id_producto,id_tienda,fecha,hora,ticket_id,cantidad,precio_unitario,descuento_pct,canal) FROM 'data/ventas_2022.csv' CSV HEADER;
\copy retail.fact_ventas(id_producto,id_tienda,fecha,hora,ticket_id,cantidad,precio_unitario,descuento_pct,canal) FROM 'data/ventas_2023.csv' CSV HEADER;
\copy retail.fact_ventas(id_producto,id_tienda,fecha,hora,ticket_id,cantidad,precio_unitario,descuento_pct,canal) FROM 'data/ventas_2024.csv' CSV HEADER;
\copy retail.fact_ventas(id_producto,id_tienda,fecha,hora,ticket_id,cantidad,precio_unitario,descuento_pct,canal) FROM 'data/ventas_2025.csv' CSV HEADER;
\copy retail.fact_inventario(id_producto,id_tienda,fecha,stock_inicial,stock_final,entradas,salidas,costo_unitario) FROM 'data/inventarios.csv' CSV HEADER;
EOF
```

### 3.4 Crear Índices y Optimizaciones

```bash
psql -h $RDS_ENDPOINT -U postgres -d retail -f sql/02_create_indexes.sql
psql -h $RDS_ENDPOINT -U postgres -d retail -f explain/materialized_views.sql
```

## 📈 Paso 4: Validar Deployment

### 4.1 Verificar Carga de Datos

```sql
-- Conectar y verificar
psql -h $RDS_ENDPOINT -U postgres -d retail

-- Verificar conteos
SELECT 'Products' as table_name, COUNT(*) as records FROM retail.dim_producto
UNION ALL
SELECT 'Stores', COUNT(*) FROM retail.dim_tienda  
UNION ALL
SELECT 'Calendar', COUNT(*) FROM retail.dim_calendario
UNION ALL
SELECT 'Sales', COUNT(*) FROM retail.fact_ventas
UNION ALL
SELECT 'Inventory', COUNT(*) FROM retail.fact_inventario;

-- Verificar rangos de fechas
SELECT 
    MIN(fecha) as min_date,
    MAX(fecha) as max_date,
    COUNT(DISTINCT fecha) as unique_dates
FROM retail.fact_ventas;
```

### 4.2 Probar Consultas de Performance

```sql
-- Test query 1: Daily sales
EXPLAIN ANALYZE
SELECT 
    fecha,
    cadena,
    SUM(cantidad * precio_unitario * (1 - descuento_pct/100)) as ventas_netas
FROM retail.fact_ventas v
JOIN retail.dim_tienda t ON v.id_tienda = t.id_tienda
WHERE fecha BETWEEN '2024-10-01' AND '2024-12-31'
GROUP BY fecha, cadena
ORDER BY fecha DESC, ventas_netas DESC;
```

### 4.3 Verificar Vistas Materializadas

```sql
-- Verificar MVs
SELECT schemaname, matviewname, hasindexes 
FROM pg_matviews 
WHERE schemaname = 'retail';

-- Test MV query
SELECT COUNT(*) FROM retail.mv_daily_sales_summary;
```

## 🔧 Paso 5: Configurar Monitoreo

### CloudWatch Logs

1. **Verificar Logs Habilitados**
   - RDS Console → Databases → Your Instance → Logs and events
   - Confirmar que "postgresql" está habilitado

2. **Configurar Retención**
   ```
   Log retention: 7 days (Free Tier)
   ```

### Performance Insights (Opcional)

```bash
# Habilitar Performance Insights via CLI
aws rds modify-db-instance \
    --db-instance-identifier retail-analytics-challenge \
    --enable-performance-insights \
    --performance-insights-retention-period 7
```

## 📧 Paso 6: Preparar Información para Reviewer

### Email Template

```
Asunto: Acceso RDS - Data Engineer II Challenge - [Tu Nombre]

Hola Aaron,

Adjunto la información de acceso para validación del challenge:

**Repositorio GitHub**: [URL_DEL_REPO]

**Acceso RDS**:
Host: retail-analytics-challenge.xxxxxxxxx.us-east-1.rds.amazonaws.com
Port: 5432
Database: retail
Usuario: kimetrics_reviewer
Password: [SECURE_PASSWORD]

**Ventana de Validación**: 
Fecha: [YYYY-MM-DD]
Hora: 14:00 - 18:00 (America/Mexico_City)
UTC: 20:00 - 00:00

**Queries de Prueba**:
- Dashboard ejecutivo: SELECT * FROM retail.mv_daily_sales_summary LIMIT 10;
- Top productos: SELECT * FROM retail.mv_product_performance WHERE ranking_categoria_mes <= 5;
- Alertas inventario: SELECT * FROM retail.mv_inventory_alerts WHERE alerta_inventario = 'STOCK_BAJO';

**Notas**:
- Instancia será eliminada después de la validación
- CloudWatch logs habilitados con retención de 7 días
- Performance optimizado con índices y MVs

Saludos,
[Tu Nombre]
```

## 🧹 Paso 7: Limpieza Post-Validación

### Eliminar Acceso Público

```bash
aws rds modify-db-instance \
    --db-instance-identifier retail-analytics-challenge \
    --no-publicly-accessible
```

### Eliminar Instancia

```bash
aws rds delete-db-instance \
    --db-instance-identifier retail-analytics-challenge \
    --skip-final-snapshot
```

## ⚠️ Consideraciones de Costos

### Free Tier Limits
- **Instancia**: 750 horas/mes db.t2.micro o db.t3.micro
- **Almacenamiento**: 20 GB SSD
- **Backup**: 20 GB
- **Transferencia**: 1 GB/mes

### Monitoreo de Costos
- Configurar billing alerts
- Revisar AWS Cost Explorer
- Eliminar recursos después de validación

## 🔍 Troubleshooting

### Problemas Comunes

1. **Connection Timeout**
   - Verificar Security Group
   - Confirmar Public Access habilitado
   - Revisar VPC/Subnet configuration

2. **Authentication Failed**
   - Verificar username/password
   - Confirmar usuario tiene permisos CONNECT

3. **Slow Queries**
   - Verificar que índices se crearon correctamente
   - Ejecutar ANALYZE en tablas principales
   - Revisar Performance Insights

### Comandos de Diagnóstico

```sql
-- Verificar conexiones activas
SELECT * FROM pg_stat_activity WHERE datname = 'retail';

-- Verificar tamaño de tablas
SELECT 
    schemaname,
    tablename,
    pg_size_pretty(pg_total_relation_size(schemaname||'.'||tablename)) as size
FROM pg_tables 
WHERE schemaname = 'retail'
ORDER BY pg_total_relation_size(schemaname||'.'||tablename) DESC;

-- Verificar índices
SELECT 
    schemaname,
    tablename,
    indexname,
    indexdef
FROM pg_indexes 
WHERE schemaname = 'retail';
```

## ✅ Checklist Final

- [ ] Instancia RDS creada y disponible
- [ ] Security Group configurado correctamente
- [ ] Esquema y datos cargados completamente
- [ ] Índices y MVs creados
- [ ] Usuario reviewer configurado
- [ ] Consultas de prueba funcionando
- [ ] CloudWatch logs habilitados
- [ ] Email con información enviado
- [ ] Ventana de validación programada
- [ ] Plan de limpieza post-validación

---

**Tiempo estimado de deployment**: 30-45 minutos
**Costo estimado**: $0 (dentro de Free Tier)
