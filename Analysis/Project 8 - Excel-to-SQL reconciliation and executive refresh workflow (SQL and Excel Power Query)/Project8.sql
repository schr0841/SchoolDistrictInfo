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
