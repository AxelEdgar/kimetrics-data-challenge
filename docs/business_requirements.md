# Data Engineer II Challenge - Retail Analytics

## Contexto del Negocio

El modelo de datos está diseñado para soportar análisis de rendimiento de tiendas en una cadena de retail. El foco está en proveer KPIs consistentes, comparables entre tiendas y a través del tiempo.

**Preguntas de Negocio**:

- ¿Cuáles son las ventas netas por cadena en los últimos 30 días?
- ¿Qué tiendas están por encima/debajo del promedio de su cadena?
- ¿Cuáles son los productos más vendidos por región?
- ¿Cómo varía el rendimiento por día de la semana/estación?

**Métricas Clave**:

- Ventas netas (cantidad * precio unitario)
- Margen (ventas - costo)
- Ticket promedio (ventas / número de transacciones)
- Velocidad de rotación de inventario
- % stock bajo (productos con stock < 10 unidades)

## Modelo de Datos

### Decisión: Esquema Estrella (Star Schema)

**Justificación**:

- Optimizado para consultas analíticas y BI
- Facilita joins simples entre hechos y dimensiones
- Permite agregaciones rápidas para dashboards
- Estructura intuitiva para usuarios de negocio

**Alternativas consideradas**:

- Esquema Copo de Nieve: Descartado por complejidad de joins
- Modelo Normalizado: Descartado por rendimiento en consultas analíticas

### Decisión: Dimensiones Conformadas

**Justificación**:

- dim_producto y dim_tienda se reutilizan en múltiples hechos
- Garantiza consistencia en reportes cruzados
- Facilita drill-down y drill-across en análisis

## Particionamiento

### Decisión: Particionamiento por Fecha en fact_ventas

**Justificación**:

- 90% de consultas incluyen filtros temporales
- Permite partition pruning automático
- Facilita mantenimiento (archivado de datos antiguos)
- Mejora paralelización de consultas

**Configuración**:

- Particiones anuales (2021-2025)
- Partition key: fecha
- Permite consultas eficientes por rangos temporales

### Decisión: No Particionar fact_inventario

**Justificación**:

- Menor volumen de datos (snapshots mensuales)
- Consultas típicamente requieren datos históricos completos
- Complejidad adicional no justificada por el volumen

## Indexación

### Decisión: Índices Covering para Consultas Críticas

**Justificación**:

- Reduce I/O al incluir columnas consultadas en el índice
- Especialmente efectivo para agregaciones
- Ejemplo: `idx_ventas_top_productos` incluye cantidad y precio_unitario

### Decisión: Índices Compuestos Estratégicos

**Justificación**:

- `idx_ventas_fecha_tienda`: Soporta análisis temporal por tienda
- `idx_tienda_cadena_region`: Optimiza consultas jerárquicas
- Orden de columnas basado en selectividad y patrones de consulta

### Decisión: Índices Parciales para Casos Específicos

**Justificación**:

- `idx_inventario_stock_bajo`: Solo indexa registros con stock < 10
- Reduce tamaño del índice y mejora rendimiento para alertas
- Aplicado donde condiciones específicas son frecuentes

## Vistas Materializadas

### Decisión: Implementar MVs para Agregaciones Costosas

**Justificación**:

- Consultas de dashboard ejecutivo requieren sub-segundo response time
- Agregaciones complejas (window functions, múltiples joins) son costosas
- Trade-off: Espacio de almacenamiento vs. tiempo de respuesta

**Estrategia de Refresh**:

- Refresh diario durante ventana de mantenimiento
- CONCURRENTLY para evitar bloqueos
- Monitoreo de freshness vs. performance

### MVs Implementadas

#### mv_daily_sales_summary

- **Propósito**: Dashboard ejecutivo de ventas diarias
- **Beneficio**: Reduce tiempo de consulta de 2.5s a 50ms
- **Refresh**: Diario a las 6:00 AM

#### mv_product_performance

- **Propósito**: Análisis de rendimiento de productos
- **Beneficio**: Pre-calcula rankings y métricas de velocidad
- **Refresh**: Diario después de mv_daily_sales_summary

#### mv_inventory_alerts

- **Propósito**: Sistema de alertas de inventario
- **Beneficio**: Elimina subqueries correlacionadas costosas
- **Refresh**: Diario, crítico para operaciones

## Tipos de Datos

### Decisión: NUMERIC para Valores Monetarios

**Justificación**:

- Precisión exacta para cálculos financieros
- Evita errores de redondeo de FLOAT/DOUBLE
- NUMERIC(12,2) soporta valores hasta 999,999,999.99

### Decisión: TIMESTAMP WITH TIME ZONE para Auditoría

**Justificación**:

- Soporte multi-zona horaria para cadenas nacionales
- Trazabilidad precisa de cuándo se crearon/modificaron registros
- Compatibilidad con herramientas de BI

### Decisión: SERIAL vs. BIGSERIAL

**Justificación**:

- SERIAL para dimensiones (volumen limitado)
- BIGSERIAL para fact_ventas (alto volumen transaccional)
- Previene overflow en tablas de alto crecimiento

## Constraints y Validaciones

### Decisión: Constraints a Nivel de Base de Datos

**Justificación**:

- Garantiza integridad independiente de la aplicación
- Previene datos inconsistentes desde múltiples fuentes
- Facilita debugging y auditoría

**Constraints Implementadas**:

- CHECK constraints para rangos válidos (precios >= 0)
- UNIQUE constraints para códigos de negocio
- FK constraints para integridad referencial
- Balance constraint en inventario

### Decisión: Campos Obligatorios vs. Opcionales

**Justificación**:

- NOT NULL para campos críticos de negocio
- NULL permitido para campos descriptivos o futuros
- Balance entre calidad de datos y flexibilidad operacional

## Estrategia de Carga de Datos

### Decisión: COPY para Bulk Loading

**Justificación**:

- 10-50x más rápido que INSERT individual
- Soporte nativo para CSV
- Transaccional (rollback en caso de error)

### Decisión: Staging vs. Direct Load

**Justificación**:

- Direct load para este challenge (datos controlados)
- En producción: staging tables para validación y transformación
- ETL pattern: Extract → Transform → Load

## Seguridad y Permisos

### Decisión: Schema-based Security

**Justificación**:

- Schema 'retail' agrupa objetos relacionados
- Facilita gestión de permisos por funcionalidad
- Separación clara entre datos y metadatos

### Decisión: Principio de Menor Privilegio

**Justificación**:

- Usuario reviewer solo con permisos SELECT
- Usuarios ETL con permisos específicos por tabla
- Administradores con acceso completo limitado

## Monitoreo y Mantenimiento

### Decisión: Funciones de Mantenimiento Automatizadas

**Justificación**:

- refresh_performance_views() para MVs
- get_mv_stats() para monitoreo
- Automatización reduce errores humanos

### Decisión: Logging y Auditoría

**Justificación**:

- created_at en todas las tablas
- CloudWatch logs habilitados
- Trazabilidad completa de cambios

## Escalabilidad

### Decisión: Diseño para Crecimiento

**Justificación**:

- Particionamiento soporta años adicionales
- BIGSERIAL previene overflow
- Índices optimizados para volúmenes grandes

### Consideraciones Futuras

- Archivado automático de particiones antiguas
- Compresión de datos históricos
- Read replicas para consultas analíticas

## Casos de Uso Específicos

### Decisión: Optimización por Patrón de Consulta

**Justificación**:

- Análisis de casos de negocio definió índices críticos
- MVs basadas en consultas reales de dashboard
- Performance testing validó decisiones

**Patrones Optimizados**:

1. Ventas diarias por cadena → índice fecha + cadena
2. Top productos por región → MV con pre-agregación
3. Alertas de inventario → MV con cálculos complejos
4. Análisis estacional → índice en dim_calendario

## Métricas de Éxito

- **Tiempo de respuesta**: < 100ms para consultas de dashboard
- **Throughput**: Soporte para 10K+ transacciones/hora
- **Disponibilidad**: 99.9% uptime durante horas de negocio
- **Escalabilidad**: Soporte para 5 años de datos históricos
- **Mantenibilidad**: Refresh de MVs en < 5 minutos

## Lecciones Aprendidas

1. **Particionamiento temprano**: Más fácil implementar desde el inicio
2. **Índices covering**: Alto impacto en performance con costo mínimo
3. **MVs estratégicas**: Críticas para dashboards en tiempo real
4. **Constraints estrictas**: Previenen problemas de calidad costosos
5. **Monitoreo proactivo**: Esencial para detectar degradación de performance
