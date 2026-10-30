-- Project 8, Part 2: Independent attendance reconciliation controls
-- Synthetic demonstration — not an actual district.
-- READ ONLY: run each numbered query separately in pgAdmin.
-- Database: schooldistrictinfo. No student_year_metrics view is used.
-- Compare only CSV and PostgreSQL data representing the SAME snapshot.
-- Missing day values are reported, not changed to zero.

-- ================================================================
-- QUERY 1: Monthly source controls, one row per school year
-- Compare against Power Query Control_Monthly.
-- Student-year keys use the TWO columns together, not student_id alone.
-- ================================================================
SELECT
    school_year,
    COUNT(*) AS monthly_rows,
    COUNT(DISTINCT (student_id, school_year)) AS unique_student_year_keys,
    SUM(membership_days) AS total_membership_days,
    SUM(excused_absent_days + unexcused_absent_days) AS total_absent_days,
    COUNT(*) FILTER (
        WHERE membership_days IS NULL
           OR excused_absent_days IS NULL
           OR unexcused_absent_days IS NULL
    ) AS rows_with_missing_control_values
FROM public.attendance_monthly
GROUP BY school_year
ORDER BY school_year;

-- ================================================================
-- QUERY 2: Independent annual aggregation, one row per school year
-- Compare against Power Query Control_StudentYear.
-- Rebuild student/year totals directly from monthly PostgreSQL records.
-- annual_rows and unique_student_year_keys should match.
-- This equality checks this SQL grouping's grain, not Excel's grain:
-- Excel must independently calculate its own row and distinct-key counts.
-- ================================================================
WITH student_year_attendance AS (
    SELECT
        student_id,
        school_year,
        SUM(membership_days) AS membership_days,
        SUM(excused_absent_days + unexcused_absent_days) AS absent_days
    FROM public.attendance_monthly
    GROUP BY student_id, school_year
)
SELECT
    school_year,
    COUNT(*) AS annual_rows,
    COUNT(DISTINCT (student_id, school_year)) AS unique_student_year_keys,
    SUM(membership_days) AS total_membership_days,
    SUM(absent_days) AS total_absent_days
FROM student_year_attendance
GROUP BY school_year
ORDER BY school_year;

-- ================================================================
-- QUERY 3: Key integrity (expected: 0 in every result column)
-- Duplicate monthly key = repeated student_id + school_year + month_start.
-- Repeated student/year across DIFFERENT months is expected, not duplicate.
-- Duplicate extras counts records beyond the first in each repeated key.
-- Missing-key check runs separately from the distinct-key controls.
-- ================================================================
WITH duplicate_month_keys AS (
    SELECT
        student_id,
        school_year,
        month_start,
        COUNT(*) AS records_for_key
    FROM public.attendance_monthly
    GROUP BY student_id, school_year, month_start
    HAVING COUNT(*) > 1
)
SELECT
    (SELECT COUNT(*)
     FROM public.attendance_monthly
     WHERE student_id IS NULL OR BTRIM(student_id) = ''
        OR school_year IS NULL OR BTRIM(school_year) = ''
        OR month_start IS NULL) AS rows_with_missing_key_parts,
    (SELECT COUNT(*) FROM duplicate_month_keys) AS duplicate_month_key_groups,
    (SELECT COALESCE(SUM(records_for_key - 1), 0)
     FROM duplicate_month_keys) AS extra_duplicate_month_rows;

-- ================================================================
-- QUERY 4: Optional all-years control totals
-- 60000 student-year keys is NOT 60000 distinct individual students.
-- Absent-day total must be calculated; no target value is hard-coded.
-- ================================================================
SELECT
    COUNT(*) AS monthly_rows,
    COUNT(DISTINCT student_id) AS unique_students_across_all_years,
    COUNT(DISTINCT (student_id, school_year)) AS unique_student_year_keys,
    SUM(membership_days) AS total_membership_days,
    SUM(excused_absent_days + unexcused_absent_days) AS total_absent_days,
    COUNT(*) FILTER (
        WHERE membership_days IS NULL
           OR excused_absent_days IS NULL
           OR unexcused_absent_days IS NULL
    ) AS rows_with_missing_control_values
FROM public.attendance_monthly;

-- Expected for the original, unmodified supplied dataset:
-- Queries 1 and 2: 3 year rows; each year 180000 monthly records,
-- 20000 annual rows/keys, and 3600000 membership days.
-- Query 3: all zeros. Queries 1/4 missing-control-value counts: zero.
-- Query 4: 540000 monthly rows; 20000 unique people;
-- 60000 student-year keys; 10800000 membership days.
-- Totals agreeing does not prove individual records agree; these are
-- control totals. Detailed exceptions and refresh controls follow later.





-- Project 8, Part 3: Missingness exceptions and referential-integrity checks
-- Synthetic demonstration — not an actual district.
-- Run each numbered section separately in pgAdmin.
-- Section 1 creates a NEW VIEW; it does not change or fill source data.
-- In this synthetic source, eligible assessments have an expected row even
-- when not tested. A missing expected ROW merits a completeness investigation.

-- ================================================================
-- SECTION 1: Create the exception reporting view
-- Assessment grain: student/year/subject/window (missing score or missing row).
-- Survey grain: responding student/year/item (one row per skipped item).
-- ================================================================
CREATE OR REPLACE VIEW public.project8_missingness_exceptions AS
WITH expected_assessments AS (
    SELECT e.student_id, e.school_year, e.school_id, e.grade_level,
           s.subject, w.test_window
    FROM public.enrollment e
    CROSS JOIN (VALUES ('Math'::text), ('Reading'::text)) s(subject)
    CROSS JOIN (VALUES ('Fall'::text), ('Spring'::text)) w(test_window)
    WHERE e.grade_level BETWEEN 3 AND 8 OR e.grade_level = 11
), assessment_exceptions AS (
    SELECT e.student_id, e.school_year, e.school_id, e.grade_level,
           'assessments'::text AS source_table,
           a.assessment_id AS source_record_id,
           e.subject, e.test_window,
           'score'::text AS item_or_field,
           CASE WHEN a.assessment_id IS NULL
                THEN 'Expected assessment row missing'
                ELSE 'Missing assessment score' END AS exception_type,
           CASE WHEN a.assessment_id IS NULL
                THEN 'Completeness review required'
                ELSE 'Expected missingness in synthetic source' END AS classification,
           CASE WHEN a.assessment_id IS NULL
                THEN 'Investigate missing source record; do not infer a score or participation.'
                ELSE 'Recorded assessment opportunity has no score; retain NULL and report not tested.'
           END AS interpretation
    FROM expected_assessments e
    LEFT JOIN public.assessments a
      ON a.student_id = e.student_id AND a.school_year = e.school_year
     AND a.subject = e.subject AND a."window" = e.test_window
    WHERE a.assessment_id IS NULL OR a.score IS NULL
), survey_exceptions AS (
    SELECT e.student_id, e.school_year, e.school_id, e.grade_level,
           'survey_responses'::text AS source_table,
           r.response_id AS source_record_id,
           NULL::text AS subject, NULL::text AS test_window,
           x.item_name AS item_or_field,
           'Skipped survey item'::text AS exception_type,
           'Expected missingness in synthetic source'::text AS classification,
           'Survey response exists but this item was skipped; retain NULL, not rating 0.'::text
               AS interpretation
    FROM public.survey_responses r
    JOIN public.enrollment e
      ON e.student_id = r.student_id AND e.school_year = r.school_year
    CROSS JOIN LATERAL (VALUES
        ('belonging'::text, r.belonging),
        ('safety'::text, r.safety),
        ('adult_support'::text, r.adult_support)
    ) x(item_name, rating)
    WHERE x.rating IS NULL
)
SELECT * FROM assessment_exceptions
UNION ALL
SELECT * FROM survey_exceptions;

-- inspect results
SELECT * FROM public.project8_missingness_exceptions LIMIT 50;


-- ================================================================
-- SECTION 2: Full exception detail; export as Project8_Missingness_Exceptions.csv
-- No LIMIT: export all result rows, not just the first displayed page.
-- If pgAdmin limits returned rows, set its result limit to unlimited first.
-- ================================================================
SELECT *
FROM public.project8_missingness_exceptions
ORDER BY school_year, source_table, student_id, subject, test_window, item_or_field;

-- ================================================================
-- SECTION 3: Summary for reconciliation with the Excel exception table
-- exception_rows is NOT a unique student count. A student can have several.
-- affected_student_years is distinct within each displayed summary group.
-- ================================================================
SELECT school_year, source_table, exception_type, classification,
       item_or_field,
       COUNT(*) AS exception_rows,
       COUNT(DISTINCT (student_id, school_year)) AS affected_student_years
FROM public.project8_missingness_exceptions
GROUP BY school_year, source_table, exception_type, classification, item_or_field
ORDER BY school_year, source_table, exception_type, item_or_field;

-- ================================================================
-- SECTION 4: Referential-integrity audit (expected orphan_rows = 0 for both)
-- A missing parent enrollment is different from a NULL score or item rating.
-- Existing enforced foreign keys should already prevent these orphan records.
-- Run separately; do not append these counts to expected-missingness totals.
-- ================================================================
SELECT 'assessments'::text AS source_table, COUNT(*) AS orphan_rows
FROM public.assessments a
WHERE NOT EXISTS (
    SELECT 1 FROM public.enrollment e
    WHERE e.student_id = a.student_id AND e.school_year = a.school_year
)
UNION ALL
SELECT 'survey_responses'::text, COUNT(*)
FROM public.survey_responses r
WHERE NOT EXISTS (
    SELECT 1 FROM public.enrollment e
    WHERE e.student_id = r.student_id AND e.school_year = r.school_year
);


-- ================================================================
-- SECTION 5: Direct-source count checks, independent of the exception view
-- Compare with Section 3 for the SAME year/type/item grouping.
-- Missing-score counts here describe source rows linked to eligible enrollment.
-- The missing-ROW category is evaluated by the expected-record scaffold above.
-- ================================================================
SELECT a.school_year, 'Missing assessment score'::text AS exception_type,
       'score'::text AS item_or_field, COUNT(*) AS exception_rows
FROM public.assessments a
JOIN public.enrollment e
  ON e.student_id = a.student_id AND e.school_year = a.school_year
WHERE a.score IS NULL
  AND (e.grade_level BETWEEN 3 AND 8 OR e.grade_level = 11)
GROUP BY a.school_year
UNION ALL
SELECT r.school_year, 'Skipped survey item'::text,
       x.item_name, COUNT(*)
FROM public.survey_responses r
JOIN public.enrollment e
  ON e.student_id = r.student_id AND e.school_year = r.school_year
CROSS JOIN LATERAL (VALUES
    ('belonging'::text, r.belonging),
    ('safety'::text, r.safety),
    ('adult_support'::text, r.adult_support)
) x(item_name, rating)
WHERE x.rating IS NULL
GROUP BY r.school_year, x.item_name
ORDER BY school_year, exception_type, item_or_field;

-- Whole-survey nonresponse is not a skipped ITEM: no respondent row exists.
-- It is not included in this item-skipping table. Survey eligibility is grades4-12;
-- assessment eligibility is grades3-8 and11. Ineligible students are not missing tests.
-- Missingness may be expected in the simulation but can bias conclusions.
-- No missing result is changed to 0, nonproficient, or an unfavorable response.


-- Missing assessment scores and skipped survey items are expected features of 
-- this synthetic dataset. The associated records can still reference valid 
-- enrolled student-years, so missing values do not by themselves indicate
-- referential-integrity failures. Existing records without matching enrollment
-- are checked separately. Missing results remain NULL rather than being replaced 
-- with zero, classified as nonproficient, or treated as unfavorable survey 
-- responses. Expected missingness is still reported because it can affect 
-- interpretation.
















