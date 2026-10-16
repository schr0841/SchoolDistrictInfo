-- One row per student-year. Aggregate each fact BEFORE joining.
CREATE VIEW student_year_metrics AS
WITH attendance AS (
 SELECT student_id, school_year, SUM(membership_days) AS membership_days,
        SUM(present_days) AS present_days,
        SUM(excused_absent_days + unexcused_absent_days) AS absent_days
 FROM attendance_monthly GROUP BY 1,2
), grades AS (
 SELECT student_id, school_year, AVG(percent_grade) AS mean_course_grade,
        SUM(credits_earned) AS credits_earned,
        SUM(CASE WHEN percent_grade < 60 THEN 1 ELSE 0 END) AS failed_course_semesters
 FROM course_grades GROUP BY 1,2
), incidents AS (
 SELECT student_id, school_year, COUNT(*) AS incident_count,
        SUM(suspension_days) AS suspension_days
 FROM discipline_incidents GROUP BY 1,2
)
SELECT e.*, s.student_alias, s.gender, s.race_ethnicity, s.home_language,
 a.membership_days, a.present_days, a.absent_days,
 a.present_days::numeric / NULLIF(a.membership_days,0) AS attendance_rate,
 (a.absent_days::numeric / NULLIF(a.membership_days,0) >= 0.10) AS chronically_absent,
 g.mean_course_grade, g.credits_earned, g.failed_course_semesters,
 COALESCE(d.incident_count,0) AS incident_count, COALESCE(d.suspension_days,0) AS suspension_days
FROM enrollment e JOIN students s USING(student_id)
JOIN attendance a USING(student_id,school_year)
LEFT JOIN grades g USING(student_id,school_year)
LEFT JOIN incidents d USING(student_id,school_year);

-- One row per school-year, including schools with zero enrolled students.
CREATE VIEW school_year_metrics AS
WITH pupils AS (
 SELECT school_id, school_year, COUNT(*) AS enrollment,
 SUM(present_days) AS present_days, SUM(membership_days) AS membership_days,
 COUNT(*) FILTER (WHERE chronically_absent) AS chronically_absent_students
 FROM student_year_metrics GROUP BY 1,2
), spending AS (
 SELECT school_id,school_year,SUM(budget) AS budget,SUM(actual) AS actual
 FROM finance GROUP BY 1,2
), teachers AS (
 SELECT school_id,school_year,SUM(fte) FILTER (WHERE staff_role='Teacher') AS teacher_fte
 FROM staffing GROUP BY 1,2
)
SELECT s.school_id,s.school_name,s.school_level,s.capacity,y.school_year,
 COALESCE(p.enrollment,0) AS enrollment,p.present_days,p.membership_days,
 p.chronically_absent_students,
 p.present_days::numeric/NULLIF(p.membership_days,0) AS attendance_rate,
 p.chronically_absent_students::numeric/NULLIF(p.enrollment,0) AS chronic_absence_rate,
 COALESCE(p.enrollment,0)::numeric/s.capacity AS capacity_utilization,
 f.budget,f.actual,f.actual-f.budget AS budget_variance,
 f.actual/NULLIF(p.enrollment,0) AS spending_per_student,
 t.teacher_fte,p.enrollment::numeric/NULLIF(t.teacher_fte,0) AS students_per_teacher_fte
FROM schools s CROSS JOIN school_years y
LEFT JOIN pupils p ON p.school_id=s.school_id AND p.school_year=y.school_year
LEFT JOIN spending f ON f.school_id=s.school_id AND f.school_year=y.school_year
LEFT JOIN teachers t ON t.school_id=s.school_id AND t.school_year=y.school_year;

-- One row per matched student-year-subject. Only paired nonmissing scores.
CREATE VIEW assessment_growth AS
SELECT f.student_id,f.school_year,e.school_id,e.grade_level,f.subject,
 f.score AS fall_score,sp.score AS spring_score,sp.score-f.score AS growth_points
FROM assessments f JOIN assessments sp
 ON sp.student_id=f.student_id AND sp.school_year=f.school_year AND sp.subject=f.subject AND sp."window"='Spring'
JOIN enrollment e ON e.student_id=f.student_id AND e.school_year=f.school_year
WHERE f."window"='Fall' AND f.score IS NOT NULL AND sp.score IS NOT NULL;
