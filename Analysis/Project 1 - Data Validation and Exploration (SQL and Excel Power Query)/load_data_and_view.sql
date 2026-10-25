-- ingest data. create database schooldistrictinfo
-- tools -> psql tool
\cd 'C:/Users/schre/GitHub/SchoolDistrictInfo'

\set ON_ERROR_STOP on

\i sql/01_schema.sql

\i sql/02_load.sql

\i sql/03_analytics_views.sql

\i sql/05_validation.sql

-- Query tool:

SELECT
    (SELECT COUNT(*) FROM students) AS students,
    (SELECT COUNT(*) FROM enrollment) AS enrollment_records,
    (SELECT COUNT(*) FROM attendance_monthly) AS attendance_records;


-- student_year_metrics is a view created from other tables

SELECT
    school_year,
    COUNT(*) AS enrolled_students,
    SUM(membership_days) AS total_membership_days,
    SUM(absent_days) AS total_absence_days
FROM student_year_metrics
GROUP BY school_year
ORDER BY school_year;

-- Explore the data
SELECT * FROM assessments LIMIT 10;

SELECT * FROM attendance_monthly LIMIT 10;

SELECT * FROM course_grades LIMIT 10;


-- Check that only students in grades 9-12 may earn credits towards graduation
SELECT
    e.grade_level,
    g.credits_attempted,
    g.credits_earned,
    COUNT(*) AS course_records
FROM course_grades g
JOIN enrollment e
    ON g.student_id = e.student_id
   AND g.school_year = e.school_year
GROUP BY
    e.grade_level,
    g.credits_attempted,
    g.credits_earned
ORDER BY
    e.grade_level,
    g.credits_attempted,
    g.credits_earned;

SELECT * FROM discipline_incidents LIMIT 10;

SELECT * FROM enrollment LIMIT 10;

SELECT * FROM finance LIMIT 10;

SELECT * FROM interventions LIMIT 10;

SELECT * FROM school_years LIMIT 10;

SELECT * FROM schools LIMIT 10;

SELECT * FROM staffing LIMIT 10;

SELECT * FROM students LIMIT 10;

SELECT * FROM survey_responses LIMIT 10;


-- Answering basic questions with PostgreSQL


-- 1. How many students are in each grade each year?

SELECT
    school_year,
    grade_level,
    COUNT(*) AS student_count
FROM enrollment
GROUP BY school_year, grade_level
ORDER BY school_year, grade_level;


-- 2. Which schools have the most students in 2025–26?

SELECT
    s.school_name,
    s.school_level,
    COUNT(*) AS student_count
FROM enrollment e
JOIN schools s
    ON e.school_id = s.school_id
WHERE e.school_year = '2025-26'
GROUP BY s.school_name, s.school_level
ORDER BY student_count DESC;


-- 3. What is the district’s attendance rate each year?

SELECT
    school_year,
    SUM(membership_days) AS possible_attendance_days,
    SUM(present_days) AS days_present,
    SUM(excused_absent_days + unexcused_absent_days) AS days_absent,
    ROUND(
        100.0 * SUM(present_days) / SUM(membership_days),
        2
    ) AS attendance_percentage
FROM attendance_monthly
GROUP BY school_year
ORDER BY school_year;


-- 4. How do average course grades differ by subject and year?

SELECT
    school_year,
    subject,
    COUNT(*) AS course_records,
    ROUND(AVG(percent_grade), 1) AS average_grade,
    SUM(
        CASE WHEN percent_grade < 60 THEN 1 ELSE 0 END
    ) AS failing_course_records
FROM course_grades
GROUP BY school_year, subject
ORDER BY school_year, subject;


-- 5. How many students participate in each intervention program?

SELECT
    school_year,
    intervention_type,
    COUNT(*) AS participating_students,
    SUM(planned_sessions) AS planned_sessions,
    SUM(attended_sessions) AS attended_sessions
FROM interventions
GROUP BY school_year, intervention_type
ORDER BY school_year, participating_students DESC;


-- Suggested Validation Evidence
-- Confirm expected record counts
SELECT
    (SELECT COUNT(*) FROM students) AS student_rows,
    (SELECT COUNT(*) FROM enrollment) AS student_year_rows,
    (SELECT COUNT(*) FROM attendance_monthly) AS student_month_rows,
    (SELECT COUNT(*) FROM student_year_metrics) AS analytical_student_year_rows;
-- ANALYSIS VERIFIED


-- Confirm that the analytical view has no duplicate student-years
SELECT
    student_id,
    school_year,
    COUNT(*) AS row_count
FROM student_year_metrics
GROUP BY student_id, school_year
HAVING COUNT(*) > 1;
-- ANALYSIS VERIFIED


-- Confirm that every enrollment appears in the analytical view
SELECT
    e.student_id,
    e.school_year
FROM enrollment e
LEFT JOIN student_year_metrics m
    ON e.student_id = m.student_id
   AND e.school_year = m.school_year
WHERE m.student_id IS NULL;
-- Expected result: zero rows. 
-- ANALYSIS VERIFIED

-- Next: A good demonstration is to compare the original totals, the incorrect joined totals, 
-- and the corrected totals for the same student-year.

-- This finds a high school student-year:
SELECT student_id, school_year, grade_level
FROM enrollment
WHERE grade_level >= 9
ORDER BY student_id, school_year
LIMIT 1;

-- use the result in the next query
-- S000008 and 2025-26

-- Establish the correct totals separately
-- First, examine attendance:
SELECT
    COUNT(*) AS attendance_rows,
    SUM(membership_days) AS membership_days,
    SUM(present_days) AS present_days
FROM attendance_monthly
WHERE student_id = 'S000008'
  AND school_year = '2025-26';

-- We find 9 attendance rows and 180 membership days
-- Next, examine grades

SELECT
    COUNT(*) AS course_grade_rows,
    SUM(credits_attempted) AS credits_attempted,
    SUM(credits_earned) AS credits_earned
FROM course_grades
WHERE student_id = 'S000008'
  AND school_year = '2025-26';

-- You should find 8 course-grade rows and 4.0 attempted credits. Earned credits depend on passing grades.

-- Deliberately create the incorrect join:

SELECT
    COUNT(*) AS joined_rows,
    SUM(a.membership_days) AS membership_days,
    SUM(a.present_days) AS present_days,
    SUM(g.credits_attempted) AS credits_attempted,
    SUM(g.credits_earned) AS credits_earned
FROM attendance_monthly a
JOIN course_grades g
    ON a.student_id = g.student_id
   AND a.school_year = g.school_year
WHERE a.student_id = 'S000008'
  AND a.school_year = '2025-26';


-- Run this query to see the individual joined rows:

SELECT
    a.month_start,
    a.membership_days,
    g.subject,
    g.semester,
    g.credits_attempted
FROM attendance_monthly a
JOIN course_grades g
    ON a.student_id = g.student_id
   AND a.school_year = g.school_year
WHERE a.student_id = 'S000008'
  AND a.school_year = '2025-26'
ORDER BY a.month_start, g.subject, g.semester;


-- Step 4: Aggregate each table before joining

-- Use two common table expressions (CTEs) to summarize attendance and grades separately. Each CTE produces one row per student-year. Joining those summaries then matches one row to one row.

WITH annual_attendance AS (
    SELECT
        student_id,
        school_year,
        SUM(membership_days) AS membership_days,
        SUM(present_days) AS present_days
    FROM attendance_monthly
    WHERE student_id = 'S000008'
      AND school_year = '2025-26'
    GROUP BY student_id, school_year
),
annual_grades AS (
    SELECT
        student_id,
        school_year,
        COUNT(*) AS course_grade_rows,
        SUM(credits_attempted) AS credits_attempted,
        SUM(credits_earned) AS credits_earned
    FROM course_grades
    WHERE student_id = 'S000008'
      AND school_year = '2025-26'
    GROUP BY student_id, school_year
)
SELECT
    a.student_id,
    a.school_year,
    a.membership_days,
    a.present_days,
    g.course_grade_rows,
    g.credits_attempted,
    g.credits_earned
FROM annual_attendance a
JOIN annual_grades g
    ON a.student_id = g.student_id
   AND a.school_year = g.school_year;

-- Independent SQL benchmark to check xlsx calculations
WITH enrollment_totals AS (
    SELECT
        school_year,
        COUNT(*) AS enrolled_students
    FROM enrollment
    GROUP BY school_year
),
attendance_totals AS (
    SELECT
        school_year,
        COUNT(DISTINCT student_id) AS attendance_headcount,
        SUM(membership_days) AS membership_days,
        SUM(present_days) AS present_days,
        SUM(
            excused_absent_days + unexcused_absent_days
        ) AS absent_days
    FROM attendance_monthly
    GROUP BY school_year
)
SELECT
    COALESCE(e.school_year, a.school_year) AS school_year,
    e.enrolled_students,
    a.attendance_headcount,
    a.membership_days,
    a.present_days,
    a.absent_days
FROM enrollment_totals e
FULL OUTER JOIN attendance_totals a
    ON e.school_year = a.school_year
ORDER BY school_year;

-- results matched Big Query xlsx calculations


-- Last step: validate results

-- 1. Record counts - verified

SELECT 'students' AS source, COUNT(*) AS actual_rows
FROM students

UNION ALL

SELECT 'enrollment', COUNT(*)
FROM enrollment

UNION ALL

SELECT 'attendance_monthly', COUNT(*)
FROM attendance_monthly

UNION ALL

SELECT 'student_year_metrics', COUNT(*)
FROM student_year_metrics;


-- 2. Student-year uniqueness
-- This checks whether enrollment or the analytical view 
-- contains more than one row for the same student and year.
-- verified that output has 0 rows
SELECT
    'enrollment' AS source,
    student_id,
    school_year,
    COUNT(*) AS row_count
FROM enrollment
GROUP BY student_id, school_year
HAVING COUNT(*) > 1

UNION ALL

SELECT
    'student_year_metrics',
    student_id,
    school_year,
    COUNT(*)
FROM student_year_metrics
GROUP BY student_id, school_year
HAVING COUNT(*) > 1;


-- 3. Referential integrity
-- Find attendance records without 
-- matching enrollment for the same student and year:
-- verified that output has 0 rows
SELECT
    a.student_id,
    a.school_year,
    a.month_start
FROM attendance_monthly a
LEFT JOIN enrollment e
    ON a.student_id = e.student_id
   AND a.school_year = e.school_year
WHERE e.student_id IS NULL;


-- 4. Attendance coverage
-- Start with enrollment and check that every student-year 
-- has nine monthly records and 180 membership days:
-- verified that this query returns 0 rows
SELECT
    e.student_id,
    e.school_year,
    COUNT(a.month_start) AS months_recorded,
    COALESCE(SUM(a.membership_days), 0) AS membership_days
FROM enrollment e
LEFT JOIN attendance_monthly a
    ON e.student_id = a.student_id
   AND e.school_year = a.school_year
GROUP BY e.student_id, e.school_year
HAVING COUNT(a.month_start) <> 9
    OR COALESCE(SUM(a.membership_days), 0) <> 180;

-- no enrollments disappeared
-- verified 0 rows
SELECT
    e.student_id,
    e.school_year
FROM enrollment e
LEFT JOIN student_year_metrics m
    ON e.student_id = m.student_id
   AND e.school_year = m.school_year
WHERE m.student_id IS NULL;


-- 5. Attendance balance
-- For every monthly record, present days plus both 
-- absence categories should equal membership days:
-- verified expected result of 0 rows
SELECT
    student_id,
    school_year,
    month_start,
    membership_days,
    present_days,
    excused_absent_days,
    unexcused_absent_days
FROM attendance_monthly
WHERE present_days
    + excused_absent_days
    + unexcused_absent_days <> membership_days;
	
-- 6. Join accuracy
-- Your row-multiplication exercise demonstrates the problem for one student-year. This check goes further: it verifies the reporting view against independently
-- aggregated source tables for every student-year.

WITH attendance_source AS (
    SELECT
        student_id,
        school_year,
        SUM(membership_days) AS membership_days,
        SUM(present_days) AS present_days,
        SUM(
            excused_absent_days + unexcused_absent_days
        ) AS absent_days
    FROM attendance_monthly
    GROUP BY student_id, school_year
),
grades_source AS (
    SELECT
        student_id,
        school_year,
        SUM(credits_attempted) AS credits_attempted,
        SUM(credits_earned) AS credits_earned
    FROM course_grades
    GROUP BY student_id, school_year
)
SELECT
    e.student_id,
    e.school_year,
    a.membership_days AS source_membership_days,
    m.membership_days AS view_membership_days,
    a.present_days AS source_present_days,
    m.present_days AS view_present_days,
    a.absent_days AS source_absent_days,
    m.absent_days AS view_absent_days,
    g.credits_earned AS source_credits_earned,
    m.credits_earned AS view_credits_earned
FROM enrollment e
LEFT JOIN attendance_source a
    ON e.student_id = a.student_id
   AND e.school_year = a.school_year
LEFT JOIN grades_source g
    ON e.student_id = g.student_id
   AND e.school_year = g.school_year
LEFT JOIN student_year_metrics m
    ON e.student_id = m.student_id
   AND e.school_year = m.school_year
WHERE m.student_id IS NULL
   OR a.membership_days IS DISTINCT FROM m.membership_days
   OR a.present_days IS DISTINCT FROM m.present_days
   OR a.absent_days IS DISTINCT FROM m.absent_days
   OR g.credits_earned IS DISTINCT FROM m.credits_earned;

-- verified expected result of 0 rows


-- 7. Excel and SQL agreement
-- Run the independent annual benchmark:

WITH enrollment_totals AS (
    SELECT
        school_year,
        COUNT(*) AS enrolled_students
    FROM enrollment
    GROUP BY school_year
),
attendance_totals AS (
    SELECT
        school_year,
        COUNT(DISTINCT student_id) AS attendance_headcount,
        SUM(membership_days) AS membership_days,
        SUM(present_days) AS present_days,
        SUM(
            excused_absent_days + unexcused_absent_days
        ) AS absent_days
    FROM attendance_monthly
    GROUP BY school_year
)
SELECT
    COALESCE(e.school_year, a.school_year) AS school_year,
    e.enrolled_students,
    a.attendance_headcount,
    a.membership_days,
    a.present_days,
    a.absent_days
FROM enrollment_totals e
FULL OUTER JOIN attendance_totals a
    ON e.school_year = a.school_year
ORDER BY school_year;

-- fully matches output from SQL_Attendance_Benchmark.xlsx



-- 8. Expected missing values
-- This involves distinguishing legitimate missing information from data errors.

-- First, summarize missing assessment scores:
SELECT
    school_year,
    COUNT(*) AS expected_assessment_records,
    COUNT(score) AS valid_scores,
    COUNT(*) - COUNT(score) AS missing_scores
FROM assessments
GROUP BY school_year
ORDER BY school_year;

-- Check that untested assessments have no performance level, and tested assessments have one:
SELECT
    assessment_id,
    student_id,
    school_year,
    score,
    performance_level
FROM assessments
WHERE (score IS NULL AND performance_level IS NOT NULL)
   OR (score IS NOT NULL AND performance_level IS NULL);


-- Finally, check grade-summary eligibility:
SELECT
    student_id,
    school_year,
    grade_level,
    mean_course_grade,
    credits_earned,
    failed_course_semesters
FROM student_year_metrics
WHERE
    (
        grade_level < 6
        AND (
            mean_course_grade IS NOT NULL
            OR credits_earned IS NOT NULL
            OR failed_course_semesters IS NOT NULL
        )
    )
    OR
    (
        grade_level >= 6
        AND (
            mean_course_grade IS NULL
            OR credits_earned IS NULL
            OR failed_course_semesters IS NULL
        )
    );

-- verified expected result of 0 rows returned










