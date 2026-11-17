/*
  AI & Tech Layoffs: SQL Server data cleaning (T-SQL)
  Table: layoffs_staging (raw Kaggle layoffs CSV imported with the SSMS Import Flat File wizard)
  Result: 4,581 imported rows -> 3,837 clean rows

  Run once, top to bottom, on a fresh import. The script is not re-runnable,
  because it adds and later drops a column.
*/

-- 1. Convert funds_raised (text like '$1,200') into a numeric column
ALTER TABLE layoffs_staging ADD funds_raised_millions FLOAT NULL;
GO

UPDATE layoffs_staging
SET funds_raised_millions = TRY_CAST(REPLACE(REPLACE(funds_raised, '$', ''), ',', '') AS FLOAT);
GO

-- 2. Check categorical columns for inconsistent spellings (before)
SELECT DISTINCT industry FROM layoffs_staging ORDER BY industry;
SELECT DISTINCT country  FROM layoffs_staging ORDER BY country;

-- 3. Trim whitespace and convert blank strings to NULL
UPDATE layoffs_staging
SET company  = NULLIF(LTRIM(RTRIM(company)),  ''),
    location = NULLIF(LTRIM(RTRIM(location)), ''),
    industry = NULLIF(LTRIM(RTRIM(industry)), ''),
    stage    = NULLIF(LTRIM(RTRIM(stage)),    ''),
    country  = NULLIF(LTRIM(RTRIM(country)),  '');

-- 4. Remove exact duplicates, keeping one row per identical record
WITH dupes AS (
  SELECT *,
    ROW_NUMBER() OVER (
      PARTITION BY company, location, industry, total_laid_off, percentage_laid_off,
                   date, stage, country, funds_raised, source, date_added
      ORDER BY (SELECT NULL)
    ) AS rn
  FROM layoffs_staging
)
DELETE FROM dupes WHERE rn > 1;

-- 5. Remove rows with neither a headcount nor a percentage (no measurable layoff)
DELETE FROM layoffs_staging
WHERE total_laid_off IS NULL AND percentage_laid_off IS NULL;

-- 6. Validate the result
SELECT COUNT(*) AS final_row_count FROM layoffs_staging;   -- expected: 3,837

SELECT DISTINCT industry FROM layoffs_staging ORDER BY industry;   -- (after)
SELECT DISTINCT country  FROM layoffs_staging ORDER BY country;    -- (after)

SELECT
    COUNT(*) AS total_rows,
    SUM(CASE WHEN total_laid_off       IS NULL THEN 1 ELSE 0 END) AS missing_total_laid_off,
    SUM(CASE WHEN percentage_laid_off  IS NULL THEN 1 ELSE 0 END) AS missing_pct,
    SUM(CASE WHEN funds_raised_millions IS NULL THEN 1 ELSE 0 END) AS missing_funds,
    MIN(date) AS earliest_date,
    MAX(date) AS latest_date
FROM layoffs_staging;

-- 7. Drop the original text column now that the numeric one is in place
ALTER TABLE layoffs_staging DROP COLUMN funds_raised;
