-- Start with a participation summary

SELECT
    school_year,
    subject,
    "window" AS test_window,
    COUNT(*) AS expected_assessment_records,
    COUNT(score) AS valid_scores,
    COUNT(*) - COUNT(score) AS missing_scores,
    ROUND(
        100.0 * COUNT(score) / COUNT(*),
        1
    ) AS participation_percentage
FROM assessments
GROUP BY school_year, subject, "window"
ORDER BY school_year, subject, "window";


-- PROJECT 3: FIRST REQUIREMENT ONLY
-- Calculate participation, Spring proficiency, and matched Fall-to-Spring growth.
-- Run in pgAdmin Query Tool, connected to schooldistrictinfo.
-- Highlight and run ONE complete numbered query at a time.
-- All three queries use: school year 2025-26, subject Math, grade 5.
-- Each query has a settings CTE: change it consistently in all three queries
-- when you are ready to explore another year, subject, or eligible grade.
-- Eligible grades: 3,4,5,6,7,8,11. Subjects: Math or Reading.
-- All data, score scales, and proficiency cutoffs are fictional.

-- =====================================================================
-- QUERY 1: TESTED / EXPECTED COUNTS
-- Expected output: two rows, one for Fall and one for Spring.
-- Expected tests come from enrollment, not just assessment rows already present.
-- Tested means score IS NOT NULL. NULL scores are not zero scores.
-- =====================================================================
WITH settings AS (
    SELECT '2025-26' AS school_year, 'Math' AS subject, 5 AS grade_level
),
test_windows (test_window) AS (
    VALUES ('Fall'), ('Spring')
)
SELECT
    p.school_year,
    p.grade_level,
    p.subject,
    w.test_window,
    COUNT(*) AS expected_tests,
    COUNT(a.score) AS tested_students,
    COUNT(*) - COUNT(a.score) AS without_valid_score,
    ROUND(
        100.0 * COUNT(a.score) / NULLIF(COUNT(*), 0),
        2
    ) AS participation_percentage
FROM settings p
JOIN public.enrollment e
    ON e.school_year = p.school_year
   AND e.grade_level = p.grade_level
CROSS JOIN test_windows w
LEFT JOIN public.assessments a
    ON a.student_id = e.student_id
   AND a.school_year = e.school_year
   AND a.subject = p.subject
   AND a."window" = w.test_window
GROUP BY p.school_year, p.grade_level, p.subject, w.test_window
ORDER BY w.test_window;


-- =====================================================================
-- QUERY 2: SPRING PROFICIENCY AMONG VALID TESTS
-- Expected output: one summary row.
-- Proficient means score >= 510 on this fictional assessment scale.
-- Denominator = valid Spring scores, NOT all enrolled/expected students.
-- Untested students are excluded from proficiency, not counted as failures.
-- If no valid scores exist, proficiency_percentage is NULL, not zero.
-- =====================================================================
WITH settings AS (
    SELECT '2025-26' AS school_year, 'Math' AS subject, 5 AS grade_level
)
SELECT
    p.school_year,
    p.grade_level,
    p.subject,
    'Spring' AS test_window,
    COUNT(*) AS expected_tests,
    COUNT(a.score) AS valid_spring_tests,
    COUNT(*) - COUNT(a.score) AS without_valid_score,
    COUNT(*) FILTER (
        WHERE a.score >= 510
    ) AS proficient_students,
    ROUND(
        100.0 * COUNT(*) FILTER (WHERE a.score >= 510)
        / NULLIF(COUNT(a.score), 0),
        2
    ) AS proficiency_percentage
FROM settings p
JOIN public.enrollment e
    ON e.school_year = p.school_year
   AND e.grade_level = p.grade_level
LEFT JOIN public.assessments a
    ON a.student_id = e.student_id
   AND a.school_year = e.school_year
   AND a.subject = p.subject
   AND a."window" = 'Spring'
GROUP BY p.school_year, p.grade_level, p.subject;



-- =====================================================================
-- QUERY 3: FALL-TO-SPRING GROWTH FOR MATCHED STUDENT-SUBJECT PAIRS
-- Expected output: one summary row for this selection if pairs exist.
-- assessment_growth already matches the SAME student, year, and subject,
-- requiring nonmissing Fall AND Spring scores.
-- Each growth_points value = Spring score - Fall score for that pair.
-- This summary averages those paired differences, in score points, not percent.
-- Both displayed mean scores use the SAME paired group.
-- paired_students may be smaller than either window's tested count in query 1.
-- This is raw growth on a fictional scale, not a validated growth percentile.
-- =====================================================================
WITH settings AS (
    SELECT '2025-26' AS school_year, 'Math' AS subject, 5 AS grade_level
)
SELECT
    g.school_year,
    g.grade_level,
    g.subject,
    COUNT(*) AS paired_students,
    ROUND(AVG(g.fall_score), 2) AS paired_mean_fall_score,
    ROUND(AVG(g.spring_score), 2) AS paired_mean_spring_score,
    ROUND(AVG(g.growth_points), 2) AS mean_growth_points
FROM public.assessment_growth g
JOIN settings p
    ON g.school_year = p.school_year
   AND g.subject = p.subject
   AND g.grade_level = p.grade_level
GROUP BY g.school_year, g.grade_level, g.subject;


