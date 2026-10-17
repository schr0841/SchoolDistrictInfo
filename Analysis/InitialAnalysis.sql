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
