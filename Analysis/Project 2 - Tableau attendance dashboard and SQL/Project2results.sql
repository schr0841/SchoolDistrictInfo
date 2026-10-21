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
-- Define chronic absence as total annual absences divided by membership days >=10%. 
-- Excused and unexcused days both count in this exercise.
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


-- Part 2: Compute school-year rates and year-over-year percentage-point change with LAG.
-- Keep numerators and denominators.

-- Calculate each school’s annual counts of chronic absence
SELECT
    school_id,
    school_year,
    COUNT(*) AS enrolled_students,
    COUNT(*) FILTER (
        WHERE chronically_absent
    ) AS chronically_absent_students
FROM public.student_year_metrics
GROUP BY school_id, school_year
ORDER BY school_id, school_year;

-- Each school has one result per year in which students are enrolled.

-- Calculate absence rates and use LAG

WITH school_counts AS (
    -- One row per school and school year.
    SELECT
        school_id,
        school_year,
        COUNT(*) AS enrolled_students,
        COUNT(*) FILTER (
            WHERE chronically_absent
        ) AS chronically_absent_students
    FROM public.student_year_metrics
    GROUP BY school_id, school_year
),
school_rates AS (
    -- Keep the rate unrounded for subsequent calculations.
    SELECT
        school_id,
        school_year,
        enrolled_students,
        chronically_absent_students,
        chronically_absent_students::numeric
            / NULLIF(enrolled_students, 0)
            AS chronic_absence_rate
    FROM school_counts
),
school_comparisons AS (
    -- Retrieve the previous available year within the same school.
    SELECT
        *,
        LAG(school_year) OVER (
            PARTITION BY school_id
            ORDER BY school_year
        ) AS prior_school_year,
        LAG(chronic_absence_rate) OVER (
            PARTITION BY school_id
            ORDER BY school_year
        ) AS prior_chronic_absence_rate,
        LAG(chronically_absent_students) OVER (
            PARTITION BY school_id
            ORDER BY school_year
        ) AS prior_chronically_absent_students,
        LAG(enrolled_students) OVER (
            PARTITION BY school_id
            ORDER BY school_year
        ) AS prior_enrolled_students
    FROM school_rates
)
SELECT
    c.school_id,
    s.school_name,
    s.school_level,
    c.school_year,

    -- Current-year numerator and denominator.
    c.chronically_absent_students,
    c.enrolled_students,

    -- Raw proportion for Tableau percentage formatting.
    c.chronic_absence_rate,

    -- Readable percentage for checking results in SQL.
    ROUND(
        100 * c.chronic_absence_rate,
        2
    ) AS chronic_absence_percentage,

    -- Prior-year context and counts.
    c.prior_school_year,
    c.prior_chronically_absent_students,
    c.prior_enrolled_students,
    c.prior_chronic_absence_rate,

    -- Percentage-point change, not relative percent change.
    ROUND(
        100 * (
            c.chronic_absence_rate
            - c.prior_chronic_absence_rate
        ),
        2
    ) AS chronic_absence_change_pp

FROM school_comparisons c
JOIN public.schools s
    ON c.school_id = s.school_id
ORDER BY c.school_id, c.school_year;

-- output shows each school's chronic absence rate plus prior year change

-- verifying that there are 30 schools in the district
SELECT COUNT(DISTINCT school_id) AS total_schools
FROM schools;
