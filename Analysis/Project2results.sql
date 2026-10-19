SELECT
    school_year,
    COUNT(DISTINCT student_id) AS students,
    ROUND(
        100.0 * SUM(present_days) / SUM(membership_days),
        1
    ) AS attendance_percentage
FROM attendance_monthly
GROUP BY school_year
ORDER BY school_year;


-- Check your Tableau results against SQL

WITH annual_attendance AS (
    SELECT
        student_id,
        school_year,
        SUM(
            excused_absent_days + unexcused_absent_days
        ) AS absent_days,
        SUM(membership_days) AS membership_days
    FROM attendance_monthly
    GROUP BY student_id, school_year
)
SELECT
    school_year,
    COUNT(*) AS students,
    COUNT(*) FILTER (
        WHERE absent_days::numeric
              / NULLIF(membership_days, 0) >= 0.10
    ) AS chronically_absent_students,
    ROUND(
        100.0
        * COUNT(*) FILTER (
            WHERE absent_days::numeric
                  / NULLIF(membership_days, 0) >= 0.10
        )
        / COUNT(*),
        1
    ) AS chronic_absence_percentage
FROM annual_attendance
GROUP BY school_year
ORDER BY school_year;
