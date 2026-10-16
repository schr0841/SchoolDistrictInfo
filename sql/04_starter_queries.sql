-- 1. Board overview: district rates are weighted, not averages of school rates.
SELECT school_year, SUM(enrollment) AS students,
 SUM(present_days)::numeric/NULLIF(SUM(membership_days),0) AS attendance_rate,
 SUM(chronically_absent_students)::numeric/NULLIF(SUM(enrollment),0) AS chronic_absence_rate,
 SUM(actual)/NULLIF(SUM(enrollment),0) AS operating_spend_per_student
FROM school_year_metrics GROUP BY 1 ORDER BY 1;

-- 2. School attendance trends. Compare within levels and retain denominator.
SELECT school_name,school_level,school_year,enrollment,chronic_absence_rate,
 chronic_absence_rate-LAG(chronic_absence_rate) OVER(PARTITION BY school_id ORDER BY school_year) AS change_from_prior_year
FROM school_year_metrics ORDER BY school_level,school_name,school_year;

-- 3. Spring proficiency and participation; missing scores are not failures.
SELECT e.school_year,e.grade_level,a.subject,COUNT(*) AS expected_tests,
 COUNT(a.score) AS valid_tests,
 COUNT(a.score)::numeric/NULLIF(COUNT(*),0) AS participation_rate,
 COUNT(*) FILTER(WHERE a.score>=510)::numeric/NULLIF(COUNT(a.score),0) AS proficiency_among_tested
FROM enrollment e JOIN assessments a USING(student_id,school_year)
WHERE a."window"='Spring' GROUP BY 1,2,3 ORDER BY 1,2,3;

-- 4. Matched growth, not change in two independently composed averages.
SELECT school_year,grade_level,subject,COUNT(*) AS paired_students,
 AVG(growth_points) AS mean_growth FROM assessment_growth GROUP BY 1,2,3 ORDER BY 1,2,3;

-- 5. Program participants: descriptive association only; selection is biased.
SELECT m.school_year,COALESCE(i.intervention_type,'No program') AS program,
 COUNT(*) AS students,AVG(m.attendance_rate) AS mean_attendance,
 AVG(m.mean_course_grade) AS mean_course_grade
FROM student_year_metrics m LEFT JOIN interventions i USING(student_id,school_year)
GROUP BY 1,2 ORDER BY 1,2;

-- 6. Public summary: suppress small groups; complementary suppression may also
-- be needed if totals permit reconstruction. This query alone is NOT a privacy policy.
SELECT school_year,race_ethnicity,COUNT(*) AS students,
 CASE WHEN COUNT(*)>=10 THEN AVG(chronically_absent::integer) END AS chronic_absence_rate
FROM student_year_metrics GROUP BY 1,2 ORDER BY 1,2;

-- 7. Per-student spending must use a single school-year before comparisons.
SELECT school_name,school_year,enrollment,actual,budget_variance,
 spending_per_student,students_per_teacher_fte,capacity_utilization
FROM school_year_metrics ORDER BY school_year,spending_per_student DESC NULLS LAST;
