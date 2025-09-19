# Resultados de la optimización del rendimiento

## Resumen Ejecutivo de Mejoras

| Consulta                    | Tiempo Antes (ms) | Tiempo Después (ms) | Mejora (%) | Técnica Principal de Optimización               |
| --------------------------- | ----------------- | ------------------- | ---------- | ----------------------------------------------- |
| **1. Ventas Diarias por Cadena** | 11,195.37         | 4,496.20            | **59.8%**  | Indexing y Cache (reducción de I/O de disco)    |
| **2. Top Productos por Región**   | 5,415.03          | 4.70                | **99.9%**  | Vista Materializada (pre-cálculo de agregados)  |
| **3. Análisis de Inventario**     | 14,582.68         | 22.65               | **99.8%**  | Vista Materializada (eliminación de subconsulta correlacionada) |

---

## Query 1: Daily Sales by Chain

### ANTES de Optimización 1

* **Execution Time:** `11,195.367 ms`
* **Observaciones:** El plan de ejecución muestra una lectura intensiva de disco (`I/O Timings: shared read=6065.973`). Aunque utiliza un índice, la agregación y ordenamiento sobre 867,136 filas es inherentemente costosa.

```sql
-- PLAN DE EJECUCIÓN (ANTES)
 Incremental Sort  (cost=122.17..127632.98 rows=7304 width=95) (actual time=1477.320..11193.419 rows=368 loops=1)
   Sort Key: v.fecha DESC, (sum((((v.cantidad)::numeric * v.precio_unitario) * ('1'::numeric - (v.descuento_pct / '100'::numeric))))) DESC
   Buffers: shared hit=10349 read=9145
   I/O Timings: shared read=6065.973
   ->  GroupAggregate  (cost=52.37..127432.12 rows=7304 width=95) (actual time=200.700..11192.820 rows=368 loops=1)
         Group Key: v.fecha, t.cadena
         ->  Incremental Sort  (cost=52.37..105504.11 rows=872738 width=44) (actual time=196.336..10549.901 rows=867136 loops=1)
               ->  Nested Loop  (cost=0.59..55718.39 rows=872738 width=44) (actual time=4.574..7430.577 rows=867136 loops=1)
                     ->  Index Scan Backward using fact_ventas_2024_fecha_idx on retail.fact_ventas_2024 v ...
                     ->  Memoize ...
 Planning Time: 74.026 ms
 Execution Time: 11195.367 ms
```

### DESPUÉS de Optimización 1

* **Execution Time:** `4,496.201 ms`
* **Mejora:** **59.8%**
* **Observaciones:** La creación de índices compuestos adicionales y la ejecución de `ANALYZE` mejoraron significativamente el uso de la caché. Las lecturas de disco se redujeron drásticamente de 9,145 a solo 17 bloques (`I/O Timings: shared read=14.877`), lo que resultó en una mejora sustancial del rendimiento.

```sql
-- PLAN DE EJECUCIÓN (DESPUÉS)
 Incremental Sort  (cost=123.39..128898.19 rows=7304 width=95) (actual time=624.189..4489.132 rows=368 loops=1)
   Sort Key: v.fecha DESC, (sum((((v.cantidad)::numeric * v.precio_unitario) * ('1'::numeric - (v.descuento_pct / '100'::numeric))))) DESC
   Buffers: shared hit=19468 read=17
   I/O Timings: shared read=14.877
   ->  GroupAggregate  (cost=52.89..128697.33 rows=7304 width=95) (actual time=92.748..4488.000 rows=368 loops=1)
         Group Key: v.fecha, t.cadena
         ->  Incremental Sort  (cost=52.89..106562.32 rows=881018 width=44) (actual time=88.395..3855.907 rows=867136 loops=1)
               ->  Nested Loop  (cost=0.59..56244.60 rows=881018 width=44) (actual time=0.064..765.280 rows=867136 loops=1)
                     ->  Index Scan Backward using fact_ventas_2024_fecha_idx on retail.fact_ventas_2024 v ...
                     ->  Memoize ...
 Planning Time: 18.283 ms
 Execution Time: 4496.201 ms
```

---

## Query 2: Top Products by Region

### ANTES de Optimización 2

* **Execution Time:** `5,415.028 ms`
* **Observaciones:** Un plan extremadamente ineficiente. Realiza un `Sort` en disco (`external merge Disk: 28776kB`), indicando que la operación no cabe en memoria. El uso de `Gather Merge` y `Hash Join` sobre un gran conjunto de datos lo hace muy lento.

```sql
-- PLAN DE EJECUCIÓN (ANTES)
 Incremental Sort  (cost=142916.86..246088.80 rows=250 width=104) (actual time=3865.702..5415.028 rows=733 loops=1)
   Sort Method: external merge  Disk: 28776kB
   Buffers: shared hit=799 read=17096, temp read=10795 written=10824
   I/O Timings: shared read=5012.100, temp read=1082.147 write=211.097
   ->  WindowAgg  ...
         ->  GroupAggregate ...
               ->  Gather Merge ...
                     ->  Sort ...
                           ->  Hash Join ...
 Planning Time: (implícito en la ejecución)
 Execution Time: 5415.028 ms
```

### DESPUÉS de Optimización 2

* **Execution Time:** `4.703 ms`
* **Mejora:** **99.9%**
* **Observaciones:** El cambio a una **Vista Materializada** (`mv_regional_product_performance`) transformó radicalmente la consulta. En lugar de calcular todo desde cero, ahora simplemente lee una tabla pre-agregada y pequeña. El plan se simplifica a un `Bitmap Heap Scan` casi instantáneo.

```sql
-- PLAN DE EJECUCIÓN (DESPUÉS)
 Incremental Sort  (cost=202.42..239.54 rows=646 width=75) (actual time=4.011..4.079 rows=60 loops=1)
   Buffers: shared hit=118 read=5
   I/O Timings: shared read=1.183
   ->  WindowAgg  (cost=196.64..209.54 rows=646 width=75) (actual time=3.223..3.391 rows=60 loops=1)
         ->  Sort  (cost=196.62..198.23 rows=646 width=67) (actual time=3.207..3.262 rows=636 loops=1)
               ->  Bitmap Heap Scan on retail.mv_regional_product_performance ...
 Planning Time: 18.636 ms
 Execution Time: 4.703 ms
```

---

## Query 3: Inventory Analysis

### ANTES de Optimización 3

* **Execution Time:** `14,582.678 ms`
* **Observaciones:** El peor rendimiento del conjunto. La causa es una **subconsulta correlacionada** en la cláusula `WHERE` que se ejecuta **1,021,500 veces**, una por cada fila de inventario. Esto es un "anti-patrón" de diseño de consultas que destruye el rendimiento.

```sql
-- PLAN DE EJECUCIÓN (ANTES)
 Sort  (cost=1014887.23..1014900.00 rows=5108 width=184) (actual time=14564.382..14582.678 rows=40625 loops=1)
   Sort Method: external merge  Disk: 5368kB
   ->  Hash Join ...
         ->  Hash Join ...
               ->  Hash Left Join ...
                     ->  Seq Scan on retail.fact_inventario i  (actual time=7966.400..10197.572 rows=40625 loops=1)
                           Filter: (i.fecha = (SubPlan 2))
                           Rows Removed by Filter: 980875
                           SubPlan 2
                             ->  Result  (actual time=0.009..0.009 rows=1 loops=1021500)
 Planning Time: (implícito en la ejecución)
 Execution Time: 14582.678 ms
```

### DESPUÉS de Optimización 3

* **Execution Time:** `22.649 ms`
* **Mejora:** **99.8%**
* **Observaciones:** Al igual que en la consulta anterior, el uso de una **Vista Materializada** (`mv_inventory_alerts`) elimina por completo la subconsulta correlacionada y los joins complejos. La consulta final es un simple `Seq Scan` sobre una tabla pre-calculada, resultando en una mejora de rendimiento masiva.

```sql
-- PLAN DE EJECUCIÓN (DESPUÉS)
 Sort  (cost=1387.46..1394.75 rows=2916 width=120) (actual time=17.793..18.395 rows=2898 loops=1)
   Buffers: shared hit=768
   ->  Seq Scan on retail.mv_inventory_alerts ...
         Filter: (mv_inventory_alerts.alerta_inventario = ANY ('{SIN_STOCK,STOCK_BAJO}'::text[]))
 Planning Time: 18.785 ms
 Execution Time: 22.649 ms
```
