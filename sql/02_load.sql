-- Run psql from repository root so paths resolve.
\set ON_ERROR_STOP on
BEGIN;
\copy schools FROM 'data/schools.csv' WITH (FORMAT csv, HEADER true, NULL '')
\copy students FROM 'data/students.csv' WITH (FORMAT csv, HEADER true, NULL '')
\copy school_years FROM 'data/school_years.csv' WITH (FORMAT csv, HEADER true, NULL '')
\copy enrollment FROM 'data/enrollment.csv' WITH (FORMAT csv, HEADER true, NULL '')
\copy attendance_monthly FROM 'data/attendance_monthly.csv' WITH (FORMAT csv, HEADER true, NULL '')
\copy assessments FROM 'data/assessments.csv' WITH (FORMAT csv, HEADER true, NULL '')
\copy course_grades FROM 'data/course_grades.csv' WITH (FORMAT csv, HEADER true, NULL '')
\copy interventions FROM 'data/interventions.csv' WITH (FORMAT csv, HEADER true, NULL '')
\copy discipline_incidents FROM 'data/discipline_incidents.csv' WITH (FORMAT csv, HEADER true, NULL '')
\copy staffing FROM 'data/staffing.csv' WITH (FORMAT csv, HEADER true, NULL '')
\copy finance FROM 'data/finance.csv' WITH (FORMAT csv, HEADER true, NULL '')
\copy survey_responses FROM 'data/survey_responses.csv' WITH (FORMAT csv, HEADER true, NULL '')
COMMIT;
ANALYZE;
