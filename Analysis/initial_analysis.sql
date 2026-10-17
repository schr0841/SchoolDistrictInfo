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
