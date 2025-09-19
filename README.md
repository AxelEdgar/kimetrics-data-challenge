# Data Engineer II Challenge - Retail Analytics Platform (PostgreSQL + AWS RDS)

## "De los Datos Crudos a la Decisión de Negocio: Una Plataforma Analítica Optimizada para el Retail"

---

### **Resumen Ejecutivo del Proyecto**

Este repositorio contiene la solución completa al desafío de Data Engineer II. El proyecto consiste en el diseño, implementación y despliegue de un **modelo de datos analítico (OLAP)** para el sector retail, utilizando **PostgreSQL** sobre una infraestructura gestionada de **AWS RDS (Free Tier)**.

La solución es integral y abarca todo el ciclo de vida de un proyecto de datos:

1. **Generación de Datos a Gran Escala:** Creación de un dataset que supera ampliamente los requisitos del reto. Se generaron más de **12.9 millones de registros de ventas** para simular patrones de negocio realistas y realizar pruebas de rendimiento significativas.
2. **Modelado de Datos Dimensional:** Diseño de un **esquema en estrella optimizado**, el estándar de la industria para consultas analíticas de alto rendimiento.
3. **Ingeniería de Datos (DDL/DML):** Construcción de la base de datos con scripts SQL robustos, incluyendo **particionamiento de tablas**, constraints de integridad y procesos de carga masiva de datos (`\copy`).
4. **Optimización Extrema de Rendimiento:** Un análisis profundo de consultas complejas, aplicando técnicas avanzadas como **Vistas Materializadas** e índices estratégicos para lograr mejoras de rendimiento de hasta un **99.9%**, reduciendo tiempos de ejecución de minutos a milisegundos.
5. **Documentación Exhaustiva y Profesional:** Creación de artefactos clave como un Modelo Entidad-Relación (MER), un diccionario de datos detallado y un documento de decisiones de arquitectura para garantizar la mantenibilidad y escalabilidad del sistema.

El proyecto demuestra la capacidad de construir una solución de datos de extremo a extremo, aplicando las mejores prácticas en modelado, rendimiento y documentación técnica.

---

### **Tabla de Contenidos**

1. [🎯 Visión y Objetivos del Proyecto](#-visión-y-objetivos-del-proyecto)
2. [📊 Casos de Negocio Implementados](#-casos-de-negocio-implementados)
3. [🚀 Guía Rápida de Despliegue (Quick Start)](#-guía-rápida-de-despliegue-quick-start)
4. [📁 Estructura Detallada del Repositorio](#-estructura-detallada-del-repositorio)
5. [🏗️ Arquitectura Profunda del Modelo](#️-arquitectura-profunda-del-modelo)
6. [⚡ Análisis de Optimización de Performance](#-análisis-de-optimización-de-performance)
7. [📈 Lógica de Generación de Datos](#-lógica-de-generación-de-datos)
8. [🔧 Despliegue en AWS RDS](#-despliegue-en-aws-rds)
9. [🔍 Protocolos de Validación y Calidad de Datos](#-protocolos-de-validación-y-calidad-de-datos)
10. [📚 Documentación del Proyecto](#-documentación-del-proyecto)
11. [🔮 Trabajo Futuro y Escalabilidad](#-trabajo-futuro-y-escalabilidad)
12. [📧 Contacto](#-contacto)

---

## 🎯 Visión y Objetivos del Proyecto

El objetivo principal es **diseñar e implementar un modelo analítico de datos para retail que sea escalable, performante y mantenible**, utilizando PostgreSQL y desplegado en un entorno de nube realista como AWS RDS.

### Objetivos Secundarios

- **Demostrar maestría en modelado dimensional**, aplicando el concepto de esquema en estrella para optimizar consultas OLAP.
- **Probar la capacidad de generar datos sintéticos de alta calidad** que imiten la complejidad del mundo real, sirviendo como una base sólida para pruebas de rendimiento.
- **Aplicar y cuantificar técnicas avanzadas de optimización de bases de datos** en PostgreSQL, demostrando cómo reducir drásticamente la latencia de las consultas.
- **Producir documentación técnica de nivel profesional** que permita a otros ingenieros entender, utilizar y extender el sistema fácilmente.
- **Validar la solución en un entorno cloud (AWS RDS)**, considerando aspectos prácticos como la configuración, la seguridad y el monitoreo.

---

## 📊 Casos de Negocio Implementados

El modelo de datos fue construido para responder a preguntas de negocio críticas. A continuación se detallan los casos de uso principales y cómo el modelo los habilita.

### 1. Dashboard Ejecutivo: Ventas Diarias

- **Valor de Negocio:** Proporciona a la alta dirección una vista en tiempo real del rendimiento de ventas por cadena y tienda, permitiendo una toma de decisiones ágil.
- **Implementación:** Se utiliza una vista materializada (`mv_daily_sales_summary`) que pre-calcula las ventas diarias, los tickets promedio y las comparativas con el día anterior.
- **Consulta de Ejemplo:**

  ```sql
  -- Obtener KPIs de ventas para la última semana para la cadena 'HyperMarket'
  SELECT
      fecha,
      cadena,
      total_ventas,
      numero_tickets,
      ticket_promedio
  FROM retail.mv_daily_sales_summary
  WHERE
      fecha >= CURRENT_DATE - INTERVAL '7 days' AND
      cadena = 'HyperMarket'
  ORDER BY fecha DESC;
  ```

### 2. Merchandising: Top Productos por Región

- **Valor de Negocio:** Permite a los equipos de merchandising y marketing identificar qué productos son más populares en cada región, optimizando así el surtido de inventario y las campañas publicitarias localizadas.
- **Implementación:** Una vista materializada (`mv_product_performance`) calcula el ranking de ventas de cada producto dentro de su categoría y región.
- **Consulta de Ejemplo:**

  ```sql
  -- Encontrar los 5 productos de 'Electrónica' más vendidos en la región 'Norte' durante el último mes
  SELECT
      p.nombre_producto,
      p.marca,
      perf.total_unidades_vendidas,
      perf.total_ingresos
  FROM retail.mv_product_performance perf
  JOIN retail.productos p ON perf.producto_id = p.producto_id
  WHERE
      perf.region = 'Norte' AND
      p.categoria = 'Electrónica' AND
      perf.ranking_categoria_region <= 5
  ORDER BY perf.total_ingresos DESC;
  ```

### 3. Pricing: Ticket Promedio por Formato

- **Valor de Negocio:** Ayuda a los analistas de precios a entender el comportamiento de compra en diferentes formatos de tienda (ej. Hipermercado vs. Tienda de Conveniencia), fundamental para ajustar estrategias de precios y promociones.
- **Implementación:** La consulta agrega datos de la tabla de ventas y la dimensión de tiendas.
- **Consulta de Ejemplo:**

  ```sql
  -- Calcular el ticket promedio y el número de artículos por ticket para cada formato de tienda
  SELECT
      t.formato,
      AVG(v.total_linea) AS ingreso_promedio_por_linea,
      SUM(v.total_linea) / COUNT(DISTINCT v.ticket_id) AS ticket_promedio,
      SUM(v.unidades) / COUNT(DISTINCT v.ticket_id) AS articulos_por_ticket
  FROM retail.ventas v
  JOIN retail.tiendas t ON v.tienda_id = t.tienda_id
  WHERE v.fecha_venta BETWEEN '2025-01-01' AND '2025-03-31'
  GROUP BY t.formato
  ORDER BY ticket_promedio DESC;
  ```

### 4. Operaciones: Alertas de Inventario

- **Valor de Negocio:** Permite una gestión proactiva del inventario, identificando productos con riesgo de quiebre de stock (`stockout`) o con exceso de inventario (`overstock`), optimizando el capital de trabajo.
- **Implementación:** Una vista materializada (`mv_inventory_alerts`) compara el stock actual con umbrales predefinidos (ej. stock de seguridad).
- **Consulta de Ejemplo:**

  ```sql
  -- Identificar todos los productos en la cadena 'Supermercado' con alerta de 'STOCK_BAJO' o 'SIN_STOCK'
  SELECT
      t.nombre_tienda,
      p.nombre_producto,
      inv.stock_actual,
      inv.alerta_inventario
  FROM retail.mv_inventory_alerts inv
  JOIN retail.tiendas t ON inv.tienda_id = t.tienda_id
  JOIN retail.productos p ON inv.producto_id = p.producto_id
  WHERE
      t.cadena = 'Supermercado' AND
      inv.alerta_inventario IN ('SIN_STOCK', 'STOCK_BAJO');
  ```

---

## 🚀 Guía Rápida de Despliegue (Quick Start)

Esta sección proporciona los pasos necesarios para clonar, configurar y ejecutar el proyecto completo.

### Prerrequisitos

- **Git:** Para clonar el repositorio.
- **Python 3.9+ y pip:** Para ejecutar el script de generación de datos.
- **PostgreSQL Client (`psql`):** Para interactuar con la base de datos desde la línea de comandos.
- **Acceso a una instancia de PostgreSQL:** Puede ser una instalación local, una instancia en Docker o una base de datos en la nube como AWS RDS.

### Pasos de Ejecución

```bash
# PASO 1: Clonar el repositorio y navegar a la carpeta del proyecto.
# ----------------------------------------------------------------
git clone https://github.com/tu-usuario/data-engineer-challenge.git
cd data-engineer-challenge

# PASO 2: Crear un entorno virtual de Python e instalar las dependencias.
# Es una buena práctica aislar las dependencias del proyecto.
# ----------------------------------------------------------------
python -m venv venv
source venv/bin/activate  # En Windows: venv\Scripts\activate
pip install -r requirements.txt

# PASO 3: Generar los datos dummy.
# Este script creará varios archivos .csv en la carpeta /data.
# Puede tardar varios minutos debido al gran volumen de datos (+12.9M de filas).
# ----------------------------------------------------------------
echo "Iniciando la generación de datos... Esto puede tardar."
python 00_generate_data.py
echo "Datos generados exitosamente en la carpeta /data."

# PASO 4: Configurar las variables de conexión a la base de datos.
# Se recomienda usar variables de entorno para no exponer credenciales.
# ----------------------------------------------------------------
export HOST="your-rds-endpoint"
export USER="your_user"
export DBNAME="retail"
# Se te pedirá la contraseña de forma interactiva al ejecutar psql.

# PASO 5: Ejecutar los scripts SQL en el orden secuencial correcto.
# El orden es crítico para asegurar que las dependencias (tablas, datos) se cumplan.
# ----------------------------------------------------------------

# 5.a: Crear el esquema, las tablas, las particiones y las secuencias.
echo "Ejecutando DDL: 01_create_schema.sql"
psql -h $HOST -U $USER -d $DBNAME -f sql/01_create_schema.sql

# 5.b: Poblar la dimensión de calendario, que es independiente de los datos generados.
echo "Poblando Dimensión Calendario: 03_populate_calendar.sql"
psql -h $HOST -U $USER -d $DBNAME -f sql/03_populate_calendar.sql

# 5.c: Cargar los datos masivamente usando el comando \copy de psql. Es altamente eficiente.
echo "Cargando Datos Masivos: 04_load_data.sql"
psql -h $HOST -U $USER -d $DBNAME -f sql/04_load_data.sql

# 5.d: Crear los índices después de la carga de datos para acelerar el proceso de ingesta.
echo "Creando Índices Optimizados: 02_create_indexes.sql"
psql -h $HOST -U $USER -d $DBNAME -f sql/02_create_indexes.sql

# 5.e: Crear las vistas materializadas para pre-agregar datos y acelerar los dashboards.
echo "Creando Vistas Materializadas: materialized_views.sql"
psql -h $HOST -U $USER -d $DBNAME -f explain/materialized_views.sql

echo "¡Despliegue completado exitosamente!"
```

---

## ⚡ Análisis de Optimización de Performance

Se logró una mejora drástica en el rendimiento de consultas analíticas complejas mediante la implementación de **Vistas Materializadas**, **Particionamiento de Tablas** e **Índices Estratégicos**.

### Metodología de Benchmarking

- **Entorno:** Instancia `db.t3.micro` de AWS RDS con PostgreSQL 15.
- **Datos:** Tabla `fact_ventas` con +12.9 millones de registros.
- **Proceso:** Se ejecutó cada consulta 5 veces usando `EXPLAIN ANALYZE` antes y después de las optimizaciones. Se reporta el tiempo de ejecución promedio.

### Resultados Cuantitativos

| Consulta Analítica        | Tiempo Antes (ms) | Tiempo Después (ms) | Mejora (%)  | Órdenes de Magnitud de Mejora |
| ------------------------- | ----------------- | ------------------- | ----------- | ----------------------------- |
| Top Productos por Región  | 5,415.03          | 4.70                | **99.9%**   | ~1150x más rápida             |
| Análisis de Inventario    | 14,582.68         | 22.65               | **99.8%**   | ~645x más rápida              |
| Ventas Diarias por Cadena | 11,195.37         | 4,496.20            | **59.8%**   | ~2.5x más rápida              |

*Los análisis detallados, planes de ejecución (`EXPLAIN ANALYZE`) y las consultas optimizadas se encuentran en la carpeta `/explain`.*

### Técnicas Aplicadas en Detalle

- **Vistas Materializadas:** En lugar de calcular agregaciones complejas (SUM, COUNT, RANK) sobre millones de filas en cada ejecución, estas vistas pre-calculan y almacenan físicamente los resultados. Consultar la vista es casi instantáneo. Es la técnica de mayor impacto para dashboards y reportes recurrentes.
- **Particionamiento (Partition Pruning):** Al filtrar por fecha, el motor de PostgreSQL ni siquiera lee las particiones de años que no están en el rango del filtro. Esto reduce drásticamente la cantidad de datos que deben ser procesados en disco (I/O).
- **Índices Covering y Compuestos:** Se crearon índices multicolumna (`Composite Indexes`) en las llaves foráneas y columnas de filtro más comunes (`tienda_id`, `producto_id`, `fecha_venta`). Esto permite al planificador de consultas encontrar los datos de manera extremadamente rápida sin tener que escanear la tabla completa (`Full Table Scan`).

---

## 📈 Lógica de Generación de Datos

Para asegurar que las pruebas de rendimiento fueran válidas y representativas, se puso especial énfasis en la generación de un dataset realista y a gran escala.

### Volumen y Dimensiones

Mientras que el desafío especificaba un mínimo de 1,000 registros por año, esta solución va significativamente más allá para simular un escenario de producción. El script `00_generate_data.py` genera:

- **Tabla de Ventas:** **~12.9 millones** de transacciones distribuidas a lo largo de 5 años.
- **Dimensiones:**
  - 125 productos únicos en 8 categorías.
  - 325 tiendas en 4 cadenas, 6 regiones y 4 formatos distintos.
  - 5 años completos de datos en la dimensión de calendario.

### Simulación de Patrones de Negocio

Los datos no son puramente aleatorios. Se introdujeron patrones para imitar el comportamiento real del consumidor:

- **Estacionalidad:** Un claro pico de ventas en Diciembre y caídas en Enero/Febrero.
- **Patrones Semanales:** Mayor volumen de transacciones los viernes y sábados.
- **Rendimiento por Formato:** Los hipermercados tienen tickets promedio más altos que las tiendas de conveniencia.
- **Distribución de Canales:** 85% de las ventas en tienda física, 12% online y 3% a través de la app móvil.

---

## 📁 Estructura Detallada del Repositorio

```text
data-engineer-challenge/
│
├── 00_generate_data.py             # Script principal en Python para generar todos los archivos CSV.
├── requirements.txt                # Lista de librerías Python necesarias (Pandas, Faker).
├── .gitignore                      # Ignora archivos que no deben ser versionados (ej. /data, /venv).
│
├── sql/                            # Directorio con todos los scripts de lenguaje de definición de datos (DDL).
│   ├── 01_create_schema.sql        # CREA el esquema, las tablas principales, las particiones y las secuencias. Define PKs y FKs.
│   ├── 02_create_indexes.sql       # CREA los índices optimizados (B-Tree, Composite) en las tablas de hechos y dimensiones.
│   ├── 03_populate_calendar.sql    # INSERTA datos en la tabla `dim_calendario` para un rango de 5 años.
│   └── 04_load_data.sql            # UTILIZA el comando `\copy` para cargar eficientemente los datos desde los CSV a las tablas.
│
├── explain/                        # Foco en el análisis y la optimización del rendimiento de consultas.
│   ├── ... (Archivos Antes/Después con EXPLAIN ANALYZE)
│   ├── materialized_views.sql      # DDL para crear todas las vistas materializadas usadas en la optimización.
│   └── performance_results.md      # Documento que presenta los resultados y cuantifica las mejoras.
│
├── docs/                           # Toda la documentación conceptual y de diseño del proyecto.
│   ├── MER.png                     # Diagrama visual del Modelo Entidad-Relación (Esquema en Estrella).
│   ├── diccionario_datos.md        # Descripción detallada de cada tabla, columna, tipo de dato y su propósito.
│   ├── architecture_decisions.md   # Justificaciones técnicas de las decisiones clave de diseño.
│
└── data/                           # (Generado localmente, no versionado) Almacena los archivos CSV de datos dummy.
```

---

## 🏗️ Arquitectura Profunda del Modelo

### Filosofía del Diseño: El Esquema en Estrella

- **¿Por qué un esquema en estrella?**
  - **Simplicidad:** El modelo es fácil de entender para los analistas de negocio. Las consultas son más intuitivas.
  - **Rendimiento:** Las consultas de agregación son inherentemente más rápidas.
  - **Optimización para Lectura:** Este modelo está optimizado para la lectura y agregación masiva de datos.

### Pila Tecnológica y Justificación

- **Base de Datos: PostgreSQL 15+**
  - **¿Por qué?** Es una base de datos de código abierto, robusta, madura y con un soporte excelente para funcionalidades analíticas avanzadas.
- **Generación de Datos: Python + Pandas + Faker**
  - **¿Por qué?** La combinación líder en la industria para la manipulación de datos y la generación de datos sintéticos realistas.
- **Despliegue: AWS RDS Free Tier**
  - **¿Por qué?** Permite validar la solución en un entorno de nube real sin incurrir en costos, demostrando la viabilidad del despliegue en producción.

---

## 🔧 Despliegue en AWS RDS

### Configuración de la Instancia

```yaml
Instance Class: db.t3.micro (Parte del AWS Free Tier)
Storage: 20 GB General Purpose SSD (gp2)
DB Engine: PostgreSQL 15.x
Multi-AZ Deployment: No (Para mantenerse dentro del Free Tier)
Public Access: Yes (Habilitado temporalmente para validación del revisor)
```

### Mejores Prácticas de Seguridad

- **Usuario con Privilegios Mínimos:** Se creó un usuario `kimetrics_reviewer` con permisos de solo `SELECT` en el esquema `retail`.
- **Security Group Restringido:** El grupo de seguridad de la instancia RDS debería estar configurado para permitir el tráfico entrante en el puerto 5432 solo desde la IP del revisor.
- **Gestión de Credenciales:** Las credenciales no están hardcodeadas en los scripts; se utilizan variables de entorno.
- **Post-Validación:** El acceso público a la instancia debe ser deshabilitado una vez que la revisión haya concluido.

---

## 🔍 Protocolos de Validación y Calidad de Datos

- **Integridad Referencial:** Se utilizan `FOREIGN KEY` constraints para asegurar que cada venta o registro de inventario se relacione con un producto y una tienda existentes.
- **Unicidad de Claves:** `PRIMARY KEY` en todas las tablas y constraints `UNIQUE` en códigos de negocio (SKU, código de tienda) para prevenir duplicados.
- **Validación de Rangos:** Constraints `CHECK` aseguran que los valores numéricos como precios y cantidades sean siempre positivos.
- **Calidad de la Carga:** El proceso de carga masiva asegura que el 100% de los campos obligatorios (`NOT NULL`) estén poblados.

---

## 📚 Documentación del Proyecto

Para una comprensión más profunda del proyecto, consulta los siguientes documentos en la carpeta `/docs`:

- **[Modelo Entidad-Relación (MER)](docs/MER.png)**: Diagrama visual de la arquitectura del modelo de datos.
- **[Diccionario de Datos](docs/diccionario_datos.md)**: Descripción detallada de cada tabla, columna, tipo de dato y su propósito de negocio.
- **[Decisiones de Arquitectura](docs/architecture_decisions.md)**: Justificación técnica de las elecciones de diseño.

---

## 🔮 Trabajo Futuro y Escalabilidad

Aunque esta solución es robusta, aquí hay algunas vías para su evolución:

- **Orquestación de ETL/ELT:** Integrar una herramienta como **Apache Airflow** o **dbt (Data Build Tool)** para automatizar, programar y monitorear la ejecución de los scripts de carga y la actualización de las vistas materializadas.
- **Escalado a un Data Warehouse Cloud-Nativo:** Si el volumen de datos creciera a Terabytes, el siguiente paso lógico sería migrar el modelo a una plataforma como **Amazon Redshift**, **Google BigQuery** o **Snowflake**, que están diseñadas para el procesamiento masivo en paralelo.
- **Infraestructura como Código (IaC):** Utilizar **Terraform** para definir y provisionar la instancia de RDS y la configuración de seguridad, permitiendo despliegues consistentes y reproducibles.
- **CI/CD para la Base de Datos:** Implementar un pipeline de CI/CD (ej. con GitHub Actions) que pruebe y despliegue automáticamente los cambios en los scripts SQL a diferentes entornos (desarrollo, producción).

---

## 📧 Contacto

**Desarrollado para:** Kimetrics Data Engineer II Challenge
**Repositorio:** https://github.com/AxelEdgar/kimetrics-data-challenge.git

**Documentación Adicional:** Ver la carpeta `/docs` para detalles técnicos completos.
