-- PROJECT 4: RECONCILE BUDGET AND ACTUAL SPENDING
-- Open in pgAdmin Query Tool, connected to schooldistrictinfo.
-- Highlight and run one complete numbered query at a time.
-- All queries are read-only; no database objects or records are changed.
--
-- Finance grain: school_id + school_year + category.
-- Monetary amounts are nominal, partial school operating dollars.
-- They exclude capital, debt, and central office costs.
-- Staffing compensation is already represented in finance totals.
-- Do NOT add staffing.salary_benefits to these totals.
--
-- SIGN CONVENTION FOR EXPENSES
-- variance = actual - budget
-- positive: unfavorable / over budget
-- negative: favorable / under budget
-- zero: on budget
-- Financially favorable does not establish better educational outcomes.
-- Actual and budget need not equal each other. Reconciliation checks that
-- each amount is preserved between the source and the reporting view.

-- 1. SOURCE TOTALS BY SCHOOL YEAR
-- Expected: three rows. Original dataset: 30 schools and 150 finance rows/year
-- (30 schools x 5 categories), 450 finance rows across all three years.
SELECT
    school_year,
    COUNT(*) AS finance_records,
    COUNT(DISTINCT school_id) AS schools,
    SUM(budget) AS total_budget,
    SUM(actual) AS total_actual,
    SUM(actual) - SUM(budget) AS budget_variance,
    ROUND(
        100.0 * (SUM(actual) - SUM(budget)) / NULLIF(SUM(budget), 0),
        2
    ) AS variance_percentage_of_budget,
    CASE
        WHEN SUM(actual) > SUM(budget) THEN 'Unfavorable - over budget'
        WHEN SUM(actual) < SUM(budget) THEN 'Favorable - under budget'
        ELSE 'On budget'
    END AS variance_status
FROM public.finance
GROUP BY school_year
ORDER BY school_year;


-- 2. RECONCILE ANNUAL SOURCE TOTALS TO THE SCHOOL-YEAR VIEW
-- Aggregate each independently; do not join raw finance category rows to
-- school-year view rows and then sum view amounts, which would repeat them.
-- Expected: three rows, all three differences = 0 and status = PASS.
-- Also check that all source schools are represented with nonmissing amounts.
WITH source_totals AS (
    SELECT
        school_year,
        COUNT(DISTINCT school_id) AS source_schools,
        SUM(budget) AS source_budget,
        SUM(actual) AS source_actual,
        SUM(actual) - SUM(budget) AS source_variance
    FROM public.finance
    GROUP BY school_year
),
view_totals AS (
    SELECT
        school_year,
        COUNT(*) AS view_school_year_rows,
        COUNT(budget) AS view_budget_records,
        COUNT(actual) AS view_actual_records,
        SUM(budget) AS view_budget,
        SUM(actual) AS view_actual,
        SUM(budget_variance) AS view_variance
    FROM public.school_year_metrics
    GROUP BY school_year
)
SELECT
    COALESCE(s.school_year, v.school_year) AS school_year,
    s.source_budget,
    v.view_budget,
    v.view_budget - s.source_budget AS budget_difference,
    s.source_actual,
    v.view_actual,
    v.view_actual - s.source_actual AS actual_difference,
    v.view_variance - s.source_variance AS variance_difference,
    CASE
        WHEN s.school_year IS NOT NULL
         AND v.school_year IS NOT NULL
         AND v.view_school_year_rows = s.source_schools
         AND v.view_budget_records = s.source_schools
         AND v.view_actual_records = s.source_schools
         AND v.view_budget = s.source_budget
         AND v.view_actual = s.source_actual
         AND v.view_variance = s.source_variance
        THEN 'PASS'
        ELSE 'CHECK'
    END AS reconciliation_status
FROM source_totals s
FULL OUTER JOIN view_totals v
    ON s.school_year = v.school_year
ORDER BY school_year;