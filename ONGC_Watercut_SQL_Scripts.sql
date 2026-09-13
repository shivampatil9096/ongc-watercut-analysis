-- ONGC WATERCUT ANALYSIS — SQL (simple version)
-- Load file: watercut_oilrate_enriched.csv

-- 1. SCHEMA -----------------------------------------------------------
CREATE TABLE watercut_data (
    record_id       INT PRIMARY KEY,
    reading_date    DATE,
    asset           VARCHAR(20),
    field_group     VARCHAR(30),
    watercut_pct    DECIMAL(5,2),
    data_type       VARCHAR(10),
    oil_rate_bopd   DECIMAL(10,2)
);

-- 2. LOAD ---------------------------------------------------------------
COPY watercut_data (record_id, reading_date, asset, field_group, watercut_pct, data_type, oil_rate_bopd)
FROM 'watercut_oilrate_enriched.csv'
WITH (FORMAT csv, HEADER true);
-- (SQL Server: use BULK INSERT with the same column order instead)

-- 3. ROW COUNT CHECK ------------------------------------------------
SELECT COUNT(*) FROM watercut_data;                              -- expect 9432
SELECT asset, COUNT(*) FROM watercut_data GROUP BY asset;         -- expect 786 each

-- 4. MONTH-OVER-MONTH WATERCUT TREND ----------------------------------
WITH monthly AS (
    SELECT asset,
           DATE_TRUNC('month', reading_date) AS month_start,
           AVG(watercut_pct) AS avg_wc
    FROM watercut_data
    GROUP BY asset, DATE_TRUNC('month', reading_date)
)
SELECT asset, month_start, ROUND(avg_wc, 2) AS avg_watercut_pct,
       ROUND(avg_wc - LAG(avg_wc) OVER (PARTITION BY asset ORDER BY month_start), 2) AS mom_change
FROM monthly
ORDER BY asset, month_start;

-- 5. WATER-OIL RATIO (WOR) ------------------------------------------
SELECT asset, reading_date, watercut_pct,
       ROUND((watercut_pct/100.0) / (1 - watercut_pct/100.0), 3) AS wor
FROM watercut_data
ORDER BY asset, reading_date;

-- 6. OIL RATE DECLINE % (month-over-month) ------------------------------
WITH monthly_oil AS (
    SELECT asset,
           DATE_TRUNC('month', reading_date) AS month_start,
           AVG(oil_rate_bopd) AS avg_oil
    FROM watercut_data
    GROUP BY asset, DATE_TRUNC('month', reading_date)
)
SELECT asset, month_start, ROUND(avg_oil, 1) AS avg_oil_rate,
       ROUND(100.0 * (avg_oil - LAG(avg_oil) OVER (PARTITION BY asset ORDER BY month_start))
             / LAG(avg_oil) OVER (PARTITION BY asset ORDER BY month_start), 2) AS mom_decline_pct
FROM monthly_oil
ORDER BY asset, month_start;

-- 7. RISK FLAG: WATERCUT > 70% -----------------------------------------
SELECT asset, reading_date, watercut_pct
FROM watercut_data
WHERE watercut_pct > 70
ORDER BY watercut_pct DESC;
-- Returns 94 rows: HUT (URAN) and URAN END

-- 8. ASSET RANKING (join + window function) ----------------------------
SELECT asset, field_group, ROUND(AVG(watercut_pct), 2) AS avg_watercut_pct,
       RANK() OVER (ORDER BY AVG(watercut_pct) DESC) AS rank
FROM watercut_data
GROUP BY asset, field_group
ORDER BY rank;

-- 9. POWER BI SOURCE VIEW ------------------------------------------------
CREATE VIEW vw_watercut_powerbi AS
SELECT asset, field_group, reading_date, watercut_pct, data_type, oil_rate_bopd,
       ROUND((watercut_pct/100.0) / (1 - watercut_pct/100.0), 3) AS wor
FROM watercut_data;
