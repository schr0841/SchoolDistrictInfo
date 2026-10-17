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


SELECT
    school_year,
    COUNT(*) AS enrolled_students,
    SUM(membership_days) AS total_membership_days,
    SUM(absent_days) AS total_absence_days
FROM student_year_metrics
GROUP BY school_year
ORDER BY school_year;

