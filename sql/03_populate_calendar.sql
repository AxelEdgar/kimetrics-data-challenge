-- 03_populate_calendar.sql
-- Populate calendar dimension with 5 years of data (2021-2025)
-- Data Engineer II Challenge

SET search_path TO retail, public;

-- =====================================================
-- CALENDAR DIMENSION POPULATION
-- =====================================================

-- Generate calendar data for 5 years (2021-2025)
INSERT INTO retail.dim_calendario (
    fecha, dia, dia_semana, nombre_dia, semana_anno, mes, nombre_mes, 
    trimestre, anno, es_fin_de_semana, es_festivo, nombre_festivo, periodo_fiscal
)
SELECT 
    date_series::date as fecha,
    EXTRACT(DAY FROM date_series)::integer as dia,
    EXTRACT(ISODOW FROM date_series)::integer as dia_semana,
    TO_CHAR(date_series, 'Day') as nombre_dia,
    EXTRACT(WEEK FROM date_series)::integer as semana_anno,
    EXTRACT(MONTH FROM date_series)::integer as mes,
    TO_CHAR(date_series, 'Month') as nombre_mes,
    EXTRACT(QUARTER FROM date_series)::integer as trimestre,
    EXTRACT(YEAR FROM date_series)::integer as anno,
    CASE WHEN EXTRACT(ISODOW FROM date_series) IN (6,7) THEN true ELSE false END as es_fin_de_semana,
    false as es_festivo, -- Will update specific holidays below
    null as nombre_festivo,
    'Q' || EXTRACT(QUARTER FROM date_series) || '-' || EXTRACT(YEAR FROM date_series) as periodo_fiscal
FROM generate_series('2021-01-01'::date, '2025-12-31'::date, '1 day'::interval) as date_series;

-- =====================================================
-- MEXICAN HOLIDAYS SETUP
-- =====================================================

-- Update major Mexican holidays
-- New Year's Day
UPDATE retail.dim_calendario 
SET es_festivo = true, nombre_festivo = 'Año Nuevo'
WHERE mes = 1 AND dia = 1;

-- Constitution Day (First Monday of February)
UPDATE retail.dim_calendario 
SET es_festivo = true, nombre_festivo = 'Día de la Constitución'
WHERE fecha IN (
    SELECT fecha FROM retail.dim_calendario 
    WHERE mes = 2 AND dia_semana = 1 AND dia <= 7
);

-- Benito Juárez Birthday (Third Monday of March)
UPDATE retail.dim_calendario 
SET es_festivo = true, nombre_festivo = 'Natalicio de Benito Juárez'
WHERE fecha IN (
    SELECT fecha FROM retail.dim_calendario 
    WHERE mes = 3 AND dia_semana = 1 AND dia BETWEEN 15 AND 21
);

-- Labor Day
UPDATE retail.dim_calendario 
SET es_festivo = true, nombre_festivo = 'Día del Trabajo'
WHERE mes = 5 AND dia = 1;

-- Independence Day
UPDATE retail.dim_calendario 
SET es_festivo = true, nombre_festivo = 'Día de la Independencia'
WHERE mes = 9 AND dia = 16;

-- Revolution Day (Third Monday of November)
UPDATE retail.dim_calendario 
SET es_festivo = true, nombre_festivo = 'Día de la Revolución'
WHERE fecha IN (
    SELECT fecha FROM retail.dim_calendario 
    WHERE mes = 11 AND dia_semana = 1 AND dia BETWEEN 15 AND 21
);

-- Christmas Day
UPDATE retail.dim_calendario 
SET es_festivo = true, nombre_festivo = 'Navidad'
WHERE mes = 12 AND dia = 25;

-- Christmas Eve (important for retail)
UPDATE retail.dim_calendario 
SET es_festivo = true, nombre_festivo = 'Nochebuena'
WHERE mes = 12 AND dia = 24;

-- New Year's Eve (important for retail)
UPDATE retail.dim_calendario 
SET es_festivo = true, nombre_festivo = 'Fin de Año'
WHERE mes = 12 AND dia = 31;

-- =====================================================
-- CALENDAR VALIDATION
-- =====================================================

-- Verify calendar population
SELECT 
    anno,
    COUNT(*) as dias_totales,
    COUNT(*) FILTER (WHERE es_fin_de_semana) as fines_de_semana,
    COUNT(*) FILTER (WHERE es_festivo) as festivos
FROM retail.dim_calendario 
GROUP BY anno 
ORDER BY anno;

-- Show holidays by year
SELECT anno, fecha, nombre_festivo, nombre_dia
FROM retail.dim_calendario 
WHERE es_festivo = true 
ORDER BY anno, fecha;
