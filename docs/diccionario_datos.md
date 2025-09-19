# Diccionario de Datos - Retail Analytics

## Data Engineer II Challenge

## Esquema: retail

### Tablas de Dimensiones

#### retail.dim_producto

Dimensión de productos que contiene la información maestra de todos los productos del catálogo.

| Campo | Tipo | Descripción | Restricciones |
|-------|------|-------------|---------------|
| id_producto | SERIAL | Identificador único del producto (PK) | NOT NULL, PRIMARY KEY |
| sku | VARCHAR(50) | Stock Keeping Unit - código único del producto | NOT NULL, UNIQUE |
| nombre_producto | VARCHAR(200) | Nombre comercial del producto | NOT NULL, LENGTH > 0 |
| marca | VARCHAR(100) | Marca del producto | NOT NULL |
| categoria | VARCHAR(50) | Categoría principal del producto | NOT NULL |
| subcategoria | VARCHAR(50) | Subcategoría del producto | NULL permitido |
| precio_sugerido | NUMERIC(12,2) | Precio sugerido de venta al público | >= 0 |
| activo | BOOLEAN | Indica si el producto está activo en el catálogo | DEFAULT true |
| created_at | TIMESTAMP WITH TIME ZONE | Fecha y hora de creación del registro | DEFAULT now() |
| updated_at | TIMESTAMP WITH TIME ZONE | Fecha y hora de última actualización | DEFAULT now() |

**Nivel de detalle**: Un registro por producto único en el catálogo.  
**Identificación única**: id_producto (PK), sku (UNIQUE)

#### retail.dim_tienda

Dimensión de tiendas que contiene la jerarquía organizacional: cadena → formato → tienda individual.

| Campo | Tipo | Descripción | Restricciones |
|-------|------|-------------|---------------|
| id_tienda | SERIAL | Identificador único de la tienda (PK) | NOT NULL, PRIMARY KEY |
| codigo_tienda | VARCHAR(20) | Código único de la tienda | NOT NULL, UNIQUE |
| nombre_tienda | VARCHAR(200) | Nombre de la tienda | NOT NULL, LENGTH > 0 |
| cadena | VARCHAR(100) | Cadena a la que pertenece la tienda | NOT NULL |
| formato | VARCHAR(50) | Formato de la tienda (Super, Express, Hiper, Convenience) | NOT NULL |
| region | VARCHAR(50) | Región geográfica | NOT NULL |
| ciudad | VARCHAR(100) | Ciudad donde se ubica la tienda | NOT NULL |
| estado | VARCHAR(50) | Estado o entidad federativa | NULL permitido |
| codigo_postal | VARCHAR(10) | Código postal | NULL permitido |
| superficie_m2 | INTEGER | Superficie de la tienda en metros cuadrados | > 0 |
| fecha_apertura | DATE | Fecha de apertura de la tienda | NULL permitido |
| activo | BOOLEAN | Indica si la tienda está activa | DEFAULT true |
| created_at | TIMESTAMP WITH TIME ZONE | Fecha y hora de creación del registro | DEFAULT now() |
| updated_at | TIMESTAMP WITH TIME ZONE | Fecha y hora de última actualización | DEFAULT now() |

**Nivel de detalle**: Un registro por tienda física o virtual.  
**Identificación única**: id_tienda (PK), codigo_tienda (UNIQUE)

#### retail.dim_calendario

Dimensión de calendario pre-poblada para análisis temporal y estacionalidad.

| Campo | Tipo | Descripción | Restricciones |
|-------|------|-------------|---------------|
| fecha | DATE | Fecha específica (PK) | NOT NULL, PRIMARY KEY |
| dia | INTEGER | Día del mes (1-31) | NOT NULL |
| dia_semana | INTEGER | Día de la semana (1=Lunes, 7=Domingo) | NOT NULL |
| nombre_dia | VARCHAR(20) | Nombre del día de la semana | NOT NULL |
| semana_anno | INTEGER | Número de semana del año (1-53) | NOT NULL |
| mes | INTEGER | Mes del año (1-12) | NOT NULL |
| nombre_mes | VARCHAR(20) | Nombre del mes | NOT NULL |
| trimestre | INTEGER | Trimestre del año (1-4) | NOT NULL |
| anno | INTEGER | Año | NOT NULL |
| es_fin_de_semana | BOOLEAN | Indica si es fin de semana | NOT NULL |
| es_festivo | BOOLEAN | Indica si es día festivo | DEFAULT false |
| nombre_festivo | VARCHAR(100) | Nombre del día festivo | NULL permitido |
| periodo_fiscal | VARCHAR(10) | Período fiscal (Q1-2024, Q2-2024, etc.) | NULL permitido |

**Nivel de detalle**: Un registro por día calendario.  
**Identificación única**: fecha (PK)  
**Rango de datos**: 2021-01-01 a 2025-12-31

### Tablas de Hechos

#### retail.fact_ventas

Tabla de hechos principal que contiene todas las transacciones de venta. **Particionada por fecha** para optimizar rendimiento.

| Campo | Tipo | Descripción | Restricciones |
|-------|------|-------------|---------------|
| venta_id | BIGSERIAL | Identificador único de la línea de venta | NOT NULL |
| id_producto | INTEGER | Referencia al producto vendido (FK) | NOT NULL, FK → dim_producto |
| id_tienda | INTEGER | Referencia a la tienda donde se realizó la venta (FK) | NOT NULL, FK → dim_tienda |
| fecha | DATE | Fecha de la transacción (FK) | NOT NULL, FK → dim_calendario |
| hora | TIME | Hora de la transacción | NULL permitido |
| ticket_id | VARCHAR(50) | Identificador del ticket (agrupa items de la misma transacción) | NULL permitido |
| cantidad | INTEGER | Cantidad de unidades vendidas | > 0 |
| precio_unitario | NUMERIC(12,2) | Precio unitario de venta | >= 0 |
| descuento_pct | NUMERIC(5,2) | Porcentaje de descuento aplicado | 0-100, DEFAULT 0 |
| impuesto_pct | NUMERIC(5,2) | Porcentaje de impuesto aplicado | >= 0, DEFAULT 16 |
| canal | VARCHAR(20) | Canal de venta | in-store, online, mobile, phone |
| vendedor_id | INTEGER | Identificador del vendedor | NULL permitido |
| created_at | TIMESTAMP WITH TIME ZONE | Fecha y hora de creación del registro | DEFAULT now() |

**Nivel de detalle**: Un registro por línea de producto en cada transacción.  
**Identificación única**: (venta_id, fecha) - PK compuesta para particionamiento  
**Particionamiento**: Por rango de fecha (particiones anuales 2021-2025)  

**Métricas calculadas**:

- Venta neta = cantidad × precio_unitario × (1 - descuento_pct/100)  
- Venta bruta = cantidad × precio_unitario  

#### retail.fact_inventario

Tabla de hechos que contiene snapshots periódicos de inventario por producto y tienda.

| Campo | Tipo | Descripción | Restricciones |
|-------|------|-------------|---------------|
| inventario_id | BIGSERIAL | Identificador único del registro de inventario (PK) | NOT NULL, PRIMARY KEY |
| id_producto | INTEGER | Referencia al producto (FK) | NOT NULL, FK → dim_producto |
| id_tienda | INTEGER | Referencia a la tienda (FK) | NOT NULL, FK → dim_tienda |
| fecha | DATE | Fecha del snapshot de inventario (FK) | NOT NULL, FK → dim_calendario |
| stock_inicial | INTEGER | Stock al inicio del período | >= 0 |
| stock_final | INTEGER | Stock al final del período | >= 0 |
| entradas | INTEGER | Unidades que ingresaron al inventario | >= 0, DEFAULT 0 |
| salidas | INTEGER | Unidades que salieron del inventario | >= 0, DEFAULT 0 |
| costo_unitario | NUMERIC(12,2) | Costo unitario del producto | >= 0 |
| valor_inventario | NUMERIC(15,2) | Valor total del inventario (CALCULADO) | GENERATED ALWAYS AS (stock_final × costo_unitario) |
| created_at | TIMESTAMP WITH TIME ZONE | Fecha y hora de creación del registro | DEFAULT now() |

**Nivel de detalle**: Un registro por producto, por tienda, por fecha de snapshot.  
**Identificación única**: inventario_id (PK), (id_producto, id_tienda, fecha) UNIQUE  
**Regla de negocio**: stock_inicial + entradas - salidas = stock_final  
**Frecuencia típica**: Snapshots mensuales o semanales  

## Índices Principales

### Índices de Dimensiones

- `idx_producto_categoria` - Consultas por categoría  
- `idx_producto_marca` - Consultas por marca  
- `idx_tienda_cadena_region` - Análisis regional por cadena  
- `idx_calendario_anno_mes` - Filtros temporales  

### Índices de Hechos

- `idx_ventas_fecha` - Filtros por fecha (crítico para particionamiento)  
- `idx_ventas_fecha_tienda` - Análisis de ventas por tienda y período  
- `idx_ventas_top_productos` - Análisis de productos más vendidos (covering index)  
- `idx_inventario_producto_tienda_fecha` - Consultas de inventario por producto/tienda  

## Vistas Materializadas

### retail.mv_daily_sales_summary

Pre-agrega ventas diarias por cadena, formato, región y categoría para dashboards ejecutivos.

### retail.mv_product_performance

Métricas de rendimiento de productos con rankings y cálculos de velocidad de venta.

### retail.mv_store_performance

Métricas integrales de rendimiento de tiendas incluyendo productividad y mix de canales.

### retail.mv_inventory_alerts

Alertas de inventario pre-calculadas con días de suministro y clasificación de riesgo.

## Reglas de Calidad de Datos

1. **Integridad Referencial**: Todas las FK deben tener registros válidos en tablas padre  
2. **Valores Obligatorios**: Campos NOT NULL no pueden estar vacíos  
3. **Rangos Válidos**: Precios, cantidades y porcentajes dentro de rangos lógicos  
4. **Consistencia Temporal**: Fechas de inventario y ventas dentro de rangos válidos  
5. **Unicidad**: SKUs y códigos de tienda únicos en el sistema  
6. **Balance de Inventario**: Ecuación de inventario debe balancear en fact_inventario  

## Consideraciones de Rendimiento

- **Particionamiento**: fact_ventas particionada por fecha para consultas temporales eficientes  
- **Índices Covering**: Incluyen columnas frecuentemente consultadas para reducir I/O  
- **Vistas Materializadas**: Pre-calculan agregaciones costosas, refrescadas diariamente  
- **Estadísticas**: Actualizadas automáticamente después de cargas masivas  
- **Compresión**: Particiones antiguas pueden comprimirse para ahorrar espacio  
