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














