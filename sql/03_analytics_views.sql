-- ANALYTICAL VIEWS: explanatory notes
-- A view is a saved SELECT query. It reads the underlying tables when queried;
-- it does not store a separate copy of the data like a regular table.
-- Find these objects under Schemas > public > Views in pgAdmin.
-- You can query a view just like a table: SELECT * FROM student_year_metrics;
--
-- This script creates views in dependency order: school_year_metrics uses
-- student_year_metrics. CREATE VIEW is initial setup; do not rerun this file
-- merely to read these comments if the views already exist.
-- Editing comments in this file does not change views already in PostgreSQL.
--
-- SQL notation used below:
--   WITH defines named query steps (CTEs), used within that view's query.
--   GROUP BY 1,2 groups by the first and second selected expressions.
--   ::numeric converts a value so division retains decimal places.
--   NULLIF(value,0) returns NULL for zero, preventing division-by-zero errors.
--   COALESCE(value,0) substitutes zero when value is NULL.
--   USING(student_id,school_year) joins on BOTH columns, keeping years separate.
--   Aliases such as e, s, and a are short names for tables or query steps.
-- Rates are stored as proportions: 0.95 means 95%, not 0.95%.

-- =====================================================================
-- 1. student_year_metrics: annual student-level analysis
-- =====================================================================
-- Purpose: combine enrollment, demographics, attendance, course performance,
-- and discipline into one row per student_id + school_year.
-- Expected size for this dataset: 60,000 rows (20,000 students x 3 years).
--
-- Attendance, course grades, and incidents each contain multiple records per
-- student-year. Aggregate each fact BEFORE joining so monthly attendance is
-- not multiplied by the number of course grades or incidents.
-- Enrollment supplies the school, grade level, and annual program flags.
CREATE VIEW student_year_metrics AS
WITH attendance AS (
 -- Step A: roll monthly attendance up to annual totals for each student.
 -- Both excused and unexcused absences count toward total absent days.
 -- Membership days are enrolled instructional days (180 per year here).
 SELECT student_id, school_year, SUM(membership_days) AS membership_days,
        SUM(present_days) AS present_days,
        SUM(excused_absent_days + unexcused_absent_days) AS absent_days
 FROM attendance_monthly GROUP BY 1,2
), grades AS (
 -- Step B: summarize all available subject-semester grades for each student-year.
 -- mean_course_grade is a simple average, not a GPA or credit-weighted average.
 -- Each grade below 60 counts as one failed course-semester, so failing the
 -- same subject in both semesters counts twice. Credits cover four subjects
 -- only; they are not a complete transcript or graduation eligibility measure.
 SELECT student_id, school_year, AVG(percent_grade) AS mean_course_grade,
        SUM(credits_earned) AS credits_earned,
        SUM(CASE WHEN percent_grade < 60 THEN 1 ELSE 0 END) AS failed_course_semesters
 FROM course_grades GROUP BY 1,2
), incidents AS (
 -- Step C: count incident records and sum assigned suspension days annually.
 -- Suspension days can overlap with attendance absences; do not add the two.
 SELECT student_id, school_year, COUNT(*) AS incident_count,
        SUM(suspension_days) AS suspension_days
 FROM discipline_incidents GROUP BY 1,2
)
-- Step D: combine the annual summaries with enrollment and demographics.
-- attendance_rate = present days / membership days.
-- chronically_absent is TRUE when annual absences / membership >= 10%.
-- With 180 membership days, 18 or more absent days meets that definition.
-- No incident summary means zero recorded incidents, so COALESCE supplies 0.
-- Missing grade records remain NULL: this differs from a grade or credit of 0.
SELECT e.*, s.student_alias, s.gender, s.race_ethnicity, s.home_language,
 a.membership_days, a.present_days, a.absent_days,
 a.present_days::numeric / NULLIF(a.membership_days,0) AS attendance_rate,
 (a.absent_days::numeric / NULLIF(a.membership_days,0) >= 0.10) AS chronically_absent,
 g.mean_course_grade, g.credits_earned, g.failed_course_semesters,
 COALESCE(d.incident_count,0) AS incident_count, COALESCE(d.suspension_days,0) AS suspension_days
-- Inner joins require matching student and attendance records. An enrollment
-- with no annual attendance summary would be excluded; source validation is
-- therefore important. LEFT JOINs retain students without grades or incidents.
FROM enrollment e JOIN students s USING(student_id)
JOIN attendance a USING(student_id,school_year)
LEFT JOIN grades g USING(student_id,school_year)
LEFT JOIN incidents d USING(student_id,school_year);

-- =====================================================================
-- 2. school_year_metrics: school-level reporting for a board dashboard
-- =====================================================================
-- Purpose: combine annual enrollment, attendance, capacity, spending, and
-- teacher staffing into one row per school_id + school_year.
-- Expected size: 90 rows (30 schools x 3 years), even for zero-enrollment schools.
-- Student totals come from student_year_metrics; missing attendance there would
-- also affect this view's enrollment totals, so validate against enrollment.
--
-- Each input is summarized to school-year BEFORE joining. Joining raw finance
-- categories to staffing roles or individual students would duplicate costs.
CREATE VIEW school_year_metrics AS
WITH pupils AS (
 -- Step A: count annual student rows and sum attendance within each school-year.
 -- FILTER counts only students whose annual chronic absence flag is TRUE.
 SELECT school_id, school_year, COUNT(*) AS enrollment,
 SUM(present_days) AS present_days, SUM(membership_days) AS membership_days,
 COUNT(*) FILTER (WHERE chronically_absent) AS chronically_absent_students
 FROM student_year_metrics GROUP BY 1,2
), spending AS (
 -- Step B: total budget and actual spending across all finance categories.
 -- These are nominal school operating dollars, excluding central office,
 -- capital, and debt. Staffing compensation is already represented in finance;
 -- do not add salary_benefits from staffing to these spending totals.
 SELECT school_id,school_year,SUM(budget) AS budget,SUM(actual) AS actual
 FROM finance GROUP BY 1,2
), teachers AS (
 -- Step C: sum only Teacher FTE (full-time equivalents), excluding counselors,
 -- support staff, and administrators. FTE is not the number of staff members.
 SELECT school_id,school_year,SUM(fte) FILTER (WHERE staff_role='Teacher') AS teacher_fte
 FROM staffing GROUP BY 1,2
)
-- Step D: calculate school-year indicators.
-- attendance_rate = total present days / total membership days (weighted).
-- chronic_absence_rate = chronically absent students / annual enrollment.
-- capacity_utilization = annual enrollment / building capacity; >1 means >100%.
-- budget_variance = actual - budget; positive means spending exceeded budget.
-- spending_per_student = annual actual operating spending / annual enrollment.
-- students_per_teacher_fte = enrollment / Teacher FTE; this is NOT class size.
-- NULLIF makes ratios NULL when the denominator is zero. For a school without
-- pupil rows, enrollment and utilization become 0, while pupil measures and
-- enrollment-based rates remain NULL. A missing measure is not always zero.
SELECT s.school_id,s.school_name,s.school_level,s.capacity,y.school_year,
 COALESCE(p.enrollment,0) AS enrollment,p.present_days,p.membership_days,
 p.chronically_absent_students,
 p.present_days::numeric/NULLIF(p.membership_days,0) AS attendance_rate,
 p.chronically_absent_students::numeric/NULLIF(p.enrollment,0) AS chronic_absence_rate,
 COALESCE(p.enrollment,0)::numeric/s.capacity AS capacity_utilization,
 f.budget,f.actual,f.actual-f.budget AS budget_variance,
 f.actual/NULLIF(p.enrollment,0) AS spending_per_student,
 t.teacher_fte,p.enrollment::numeric/NULLIF(t.teacher_fte,0) AS students_per_teacher_fte
-- CROSS JOIN builds every school/year combination as a reporting scaffold.
-- LEFT JOINs preserve that scaffold even if a summary is missing. Each annual
-- summary must match on BOTH school_id and school_year.
-- For district totals, sum numerators and denominators before dividing; do not
-- simply average school rates. Filter to one year for annual headcounts.
FROM schools s CROSS JOIN school_years y
LEFT JOIN pupils p ON p.school_id=s.school_id AND p.school_year=y.school_year
LEFT JOIN spending f ON f.school_id=s.school_id AND f.school_year=y.school_year
LEFT JOIN teachers t ON t.school_id=s.school_id AND t.school_year=y.school_year;

-- =====================================================================
-- 3. assessment_growth: matched Fall-to-Spring academic score changes
-- =====================================================================
-- Purpose: compare the same student's Fall and Spring scores in the same
-- subject and school year. Grain: student_id + school_year + subject.
-- This is a self-join: assessments appears twice, as f (Fall) and sp (Spring).
-- Matching on student, year, AND subject prevents mixing students, years,
-- or subjects. The source's unique constraint prevents duplicate test pairs.
-- Enrollment adds that year's school_id and grade_level.
--
-- fall_score and spring_score retain the paired scores for review.
-- growth_points = spring_score - fall_score: positive means an increase,
-- negative means a decrease, and zero means no change on this fictional scale.
-- This is a raw score difference, not a validated growth percentile or proof
-- of an intervention's effect. Do not compare unmatched Fall/Spring averages
-- and assume they describe the same group of students.
--
-- Rows require BOTH scores to be nonmissing. Untested students and incomplete
-- pairs are excluded, so this view cannot establish participation rates.
-- Use assessments for missingness and participation analysis instead.
-- A student can have separate Math and Reading rows; filter by subject or use
-- COUNT(DISTINCT student_id) when counting unique students across subjects.
-- Assessed grades are 3-8 and 11; this view does not cover every enrolled grade.
CREATE VIEW assessment_growth AS
SELECT f.student_id,f.school_year,e.school_id,e.grade_level,f.subject,
 f.score AS fall_score,sp.score AS spring_score,sp.score-f.score AS growth_points
FROM assessments f JOIN assessments sp
 ON sp.student_id=f.student_id AND sp.school_year=f.school_year AND sp.subject=f.subject AND sp."window"='Spring'
JOIN enrollment e ON e.student_id=f.student_id AND e.school_year=f.school_year
-- Keep only Fall records on the left, Spring records on the right, and pairs
-- with both scores. "window" is quoted because WINDOW is a SQL keyword.
WHERE f."window"='Fall' AND f.score IS NOT NULL AND sp.score IS NOT NULL;
