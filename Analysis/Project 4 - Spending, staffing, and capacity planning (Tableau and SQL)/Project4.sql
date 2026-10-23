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



-- 3. EXPLAIN VARIANCE BY SPENDING CATEGORY
-- Expected: 15 rows (5 categories x 3 years).
-- Summing category budgets, actuals, and variances within each year must
-- reproduce query 1's totals. Do not sum or average category percentages
-- to calculate the overall percentage: divide summed variance by summed budget.
-- Category variances may offset; an overall near-zero variance can conceal
-- overspending in one category and underspending in another.
SELECT
    school_year,
    category,
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
GROUP BY school_year, category
ORDER BY school_year, budget_variance DESC;

-- SAVE THE EVIDENCE
-- Export each query result separately with column headers, for example:
-- Project4_Annual_Budget_Totals.csv
-- Project4_Budget_Reconciliation.csv
-- Project4_Category_Variance.csv
-- Document whether query 2 passes for every year and which categories merit
-- further investigation. Treat these as patterns to investigate, not causes.


-- Annual budget and actual spending totals reconciled between the finance source 
-- table and the school-year analytical view, with zero differences. Budget variance 
-- is defined as actual minus budget: positive values indicate unfavorable 
-- overspending, negative values indicate favorable underspending, and zero indicates
-- spending on budget.



-- PROJECT 4 (part 2): SCHOOL-YEAR RESOURCE MEASURES
-- Calculate school-year operating spending per enrolled student, 
-- students per teacher FTE, and capacity utilization
-- Run in pgAdmin Query Tool, connected to schooldistrictinfo.
-- Highlight ONE complete numbered query, including its WITH section, and run.
-- Read-only; no database objects or records are changed.
--
-- Grain before computing ratios: ONE row per school + school year.
-- Each source is aggregated BEFORE joining. Raw category/role/student joins
-- would multiply rows and inflate enrollment, spending, and staffing.
-- Spending uses actual operating dollars, not budget or actual + budget.
-- Teacher FTE excludes Counselor, Support, and Administrator roles.
-- FTE is full-time-equivalent staffing, not employee headcount or class size.
-- Nominal partial operating expenses exclude capital, debt, and central office.
-- Do not add staffing compensation to finance amounts; finance covers staffing.
-- NULLIF prevents division by zero. NULL results are undefined, not zero rates.
-- Round only at final display; reconciliation uses unrounded values.

-- 1. CALCULATE AND COMPARE INDIVIDUAL SCHOOLS WITHIN ONE LEVEL
-- Default: 2025-26 Elementary. Expected: 15 rows for the original dataset.
-- Change the final WHERE to 'Middle' (6 schools) or 'High' (9 schools).
-- ORDER BY can use spending_per_student DESC, students_per_teacher_fte DESC,
-- or capacity_utilization_percentage DESC for different comparisons.
WITH enrollment_totals AS (
    SELECT school_id, school_year, COUNT(*) AS enrolled_students
    FROM public.enrollment
    GROUP BY school_id, school_year
),
spending_totals AS (
    SELECT school_id, school_year, SUM(actual) AS actual_operating_spending
    FROM public.finance
    GROUP BY school_id, school_year
),
teacher_totals AS (
    SELECT school_id, school_year, SUM(fte) AS teacher_fte
    FROM public.staffing
    WHERE staff_role = 'Teacher'
    GROUP BY school_id, school_year
),
school_inputs AS (
    SELECT
        s.school_id, s.school_name, s.school_level, y.school_year,
        COALESCE(e.enrolled_students, 0) AS enrolled_students,
        f.actual_operating_spending,
        t.teacher_fte,
        s.capacity
    FROM public.schools s
    CROSS JOIN public.school_years y
    LEFT JOIN enrollment_totals e
        ON s.school_id = e.school_id AND y.school_year = e.school_year
    LEFT JOIN spending_totals f
        ON s.school_id = f.school_id AND y.school_year = f.school_year
    LEFT JOIN teacher_totals t
        ON s.school_id = t.school_id AND y.school_year = t.school_year
),
school_calculations AS (
    SELECT
        *,
        actual_operating_spending / NULLIF(enrolled_students, 0)
            AS spending_per_student,
        enrolled_students::numeric / NULLIF(teacher_fte, 0)
            AS students_per_teacher_fte,
        enrolled_students::numeric / NULLIF(capacity, 0)
            AS capacity_utilization
    FROM school_inputs
)
SELECT
    school_year,
    school_id,
    school_name,
    school_level,
    enrolled_students,
    actual_operating_spending,
    teacher_fte,
    capacity,
    ROUND(spending_per_student, 2) AS spending_per_student,
    ROUND(students_per_teacher_fte, 2) AS students_per_teacher_fte,
    ROUND(100 * capacity_utilization, 2) AS capacity_utilization_percentage
FROM school_calculations
WHERE school_year = '2025-26'
  AND school_level = 'High'
ORDER BY spending_per_student DESC;


-- 2. CHECK THE EXISTING REPORTING VIEW AGAINST INDEPENDENT SOURCE CALCULATIONS
-- Checks all 90 school-years, not just the selection in query 1.
-- Expected: ZERO rows. Each returned row is a discrepancy to investigate.
-- IS DISTINCT FROM compares NULLs safely. No rounding is used in this check.
-- Pair this with existing completeness checks; matching NULLs do not establish
-- that an input is present or adequate for analysis.
WITH enrollment_totals AS (
    SELECT school_id, school_year, COUNT(*) AS enrolled_students
    FROM public.enrollment
    GROUP BY school_id, school_year
),
spending_totals AS (
    SELECT school_id, school_year, SUM(actual) AS actual_operating_spending
    FROM public.finance
    GROUP BY school_id, school_year
),
teacher_totals AS (
    SELECT school_id, school_year, SUM(fte) AS teacher_fte
    FROM public.staffing
    WHERE staff_role = 'Teacher'
    GROUP BY school_id, school_year
),
school_inputs AS (
    SELECT
        s.school_id, s.school_name, s.school_level, y.school_year,
        COALESCE(e.enrolled_students, 0) AS enrolled_students,
        f.actual_operating_spending,
        t.teacher_fte,
        s.capacity
    FROM public.schools s
    CROSS JOIN public.school_years y
    LEFT JOIN enrollment_totals e
        ON s.school_id = e.school_id AND y.school_year = e.school_year
    LEFT JOIN spending_totals f
        ON s.school_id = f.school_id AND y.school_year = f.school_year
    LEFT JOIN teacher_totals t
        ON s.school_id = t.school_id AND y.school_year = t.school_year
),
school_calculations AS (
    SELECT
        *,
        actual_operating_spending / NULLIF(enrolled_students, 0)
            AS spending_per_student,
        enrolled_students::numeric / NULLIF(teacher_fte, 0)
            AS students_per_teacher_fte,
        enrolled_students::numeric / NULLIF(capacity, 0)
            AS capacity_utilization
    FROM school_inputs
)
SELECT
    COALESCE(c.school_id, v.school_id) AS school_id,
    COALESCE(c.school_year, v.school_year) AS school_year,
    c.enrolled_students AS source_enrollment,
    v.enrollment AS view_enrollment,
    c.actual_operating_spending AS source_actual,
    v.actual AS view_actual,
    c.teacher_fte AS source_teacher_fte,
    v.teacher_fte AS view_teacher_fte,
    c.capacity AS source_capacity,
    v.capacity AS view_capacity,
    c.spending_per_student AS source_spending_per_student,
    v.spending_per_student AS view_spending_per_student,
    c.students_per_teacher_fte AS source_students_per_teacher_fte,
    v.students_per_teacher_fte AS view_students_per_teacher_fte,
    c.capacity_utilization AS source_capacity_utilization,
    v.capacity_utilization AS view_capacity_utilization
FROM school_calculations c
FULL OUTER JOIN public.school_year_metrics v
    ON c.school_id = v.school_id
   AND c.school_year = v.school_year
WHERE c.school_id IS NULL
   OR v.school_id IS NULL
   OR c.enrolled_students IS DISTINCT FROM v.enrollment
   OR c.actual_operating_spending IS DISTINCT FROM v.actual
   OR c.teacher_fte IS DISTINCT FROM v.teacher_fte
   OR c.capacity IS DISTINCT FROM v.capacity
   OR c.spending_per_student IS DISTINCT FROM v.spending_per_student
   OR c.students_per_teacher_fte IS DISTINCT FROM v.students_per_teacher_fte
   OR c.capacity_utilization IS DISTINCT FROM v.capacity_utilization;




-- 3. CALCULATE SCHOOL-LEVEL BENCHMARKS FOR THE SELECTED YEAR
-- Expected: three rows. Compare each school to its OWN level's benchmark.
-- These are ratios of pooled totals, not simple averages of school ratios.
-- Change the final school_year filter consistently with query 1.
WITH enrollment_totals AS (
    SELECT school_id, school_year, COUNT(*) AS enrolled_students
    FROM public.enrollment
    GROUP BY school_id, school_year
),
spending_totals AS (
    SELECT school_id, school_year, SUM(actual) AS actual_operating_spending
    FROM public.finance
    GROUP BY school_id, school_year
),
teacher_totals AS (
    SELECT school_id, school_year, SUM(fte) AS teacher_fte
    FROM public.staffing
    WHERE staff_role = 'Teacher'
    GROUP BY school_id, school_year
),
school_inputs AS (
    SELECT
        s.school_id, s.school_name, s.school_level, y.school_year,
        COALESCE(e.enrolled_students, 0) AS enrolled_students,
        f.actual_operating_spending,
        t.teacher_fte,
        s.capacity
    FROM public.schools s
    CROSS JOIN public.school_years y
    LEFT JOIN enrollment_totals e
        ON s.school_id = e.school_id AND y.school_year = e.school_year
    LEFT JOIN spending_totals f
        ON s.school_id = f.school_id AND y.school_year = f.school_year
    LEFT JOIN teacher_totals t
        ON s.school_id = t.school_id AND y.school_year = t.school_year
),
school_calculations AS (
    SELECT
        *,
        actual_operating_spending / NULLIF(enrolled_students, 0)
            AS spending_per_student,
        enrolled_students::numeric / NULLIF(teacher_fte, 0)
            AS students_per_teacher_fte,
        enrolled_students::numeric / NULLIF(capacity, 0)
            AS capacity_utilization
    FROM school_inputs
)
SELECT
    school_year,
    school_level,
    COUNT(*) AS schools,
    SUM(enrolled_students) AS enrolled_students,
    SUM(actual_operating_spending) AS actual_operating_spending,
    SUM(teacher_fte) AS teacher_fte,
    SUM(capacity) AS capacity,
    ROUND(
        SUM(actual_operating_spending) / NULLIF(SUM(enrolled_students), 0),
        2
    ) AS level_spending_per_student,
    ROUND(
        SUM(enrolled_students)::numeric / NULLIF(SUM(teacher_fte), 0),
        2
    ) AS level_students_per_teacher_fte,
    ROUND(
        100.0 * SUM(enrolled_students) / NULLIF(SUM(capacity), 0),
        2
    ) AS level_capacity_utilization_percentage
FROM school_calculations
WHERE school_year = '2025-26'
GROUP BY school_year, school_level
ORDER BY CASE school_level
    WHEN 'Elementary' THEN 1
    WHEN 'Middle' THEN 2
    WHEN 'High' THEN 3
    ELSE 4
END;

-- VALIDATION AND INTERPRETATION
-- * Query 1: actual / enrolled = spending per student.
-- * Query 1: enrolled / Teacher FTE = students per Teacher FTE.
-- * Query 1: enrolled / capacity x 100 = capacity utilization percentage.
-- * Query 2: zero rows means source/view measures match for the tested keys.
-- * Query 3: total annual enrollment across the three levels = 20,000.
-- * Capacity utilization >100 means enrollment exceeds fictional capacity.
-- * These school/student ratios do not measure classroom sizes or service quality.
-- * Closed-cohort grade progression affects school enrollment across years.
-- * Resource differences identify discussion topics; they do not establish
--   efficiency, adequacy, or the effect of spending on outcomes.
-- * For Tableau later, raw capacity_utilization is a proportion (0.80 = 80%).
--   This export uses capacity_utilization_percentage (80.00); do not format
--   that already-multiplied value as Percentage without dividing by 100.




