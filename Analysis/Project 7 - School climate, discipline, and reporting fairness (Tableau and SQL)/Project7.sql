WITH enrolled AS (
    SELECT DISTINCT student_id
    FROM enrollment
    WHERE student_id IS NOT NULL
    -- Add reporting-period and eligibility filters.
),
incidents_by_student AS (
    SELECT
        student_id,
        COUNT(DISTINCT incident_id) AS incident_count
    FROM discipline_incidents
    WHERE student_id IS NOT NULL
    -- Add matching reporting-period filters.
    GROUP BY student_id
),
student_level AS (
    SELECT
        e.student_id,
        COALESCE(i.incident_count, 0) AS incident_count
    FROM enrolled e
    LEFT JOIN incidents_by_student i
        ON e.student_id = i.student_id
)
SELECT
    COUNT(DISTINCT student_id) AS enrolled_students,
    SUM(incident_count) AS incidents,
    COUNT(DISTINCT CASE
        WHEN incident_count > 0 THEN student_id
    END) AS students_with_any_incident,
    100.0 * SUM(incident_count)
        / NULLIF(COUNT(DISTINCT student_id), 0)
        AS incidents_per_100_students,
    100.0 * COUNT(DISTINCT CASE
        WHEN incident_count > 0 THEN student_id
    END) / NULLIF(COUNT(DISTINCT student_id), 0)
        AS pct_students_with_any_incident
FROM student_level;