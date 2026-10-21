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

----------------------------------------------------
-- Part 2: Compare grades and school levels separately. 
-- Count missing tests explicitly; do not call missing scores nonproficient.
----------------------------------------------------------------




-- PROJECT 3: COMPARE GRADES AND SCHOOL LEVELS
-- Open in pgAdmin Query Tool, connected to schooldistrictinfo.
-- Highlight and execute ONE full numbered query at a time, starting at WITH.
-- Both queries initially use 2025-26, Math, Spring.
-- Change the settings in BOTH queries consistently when exploring other data.
-- Eligible grades: 3-8 and 11. Scale and cutoff of 510 are fictional.
-- Read-only queries; no schema or data changes.
--
-- Missing scores are NOT nonproficient:
-- * proficient_students counts valid scores >= 510.
-- * tested_below_proficiency counts valid scores < 510.
-- * without_valid_score counts NULL scores and absent assessment records.
-- * recorded_without_score and missing_test_records split that last category.
-- * participation denominator = expected_tests.
-- * proficiency denominator = valid_tests.
-- A zero valid-test denominator yields NULL proficiency, not 0%.

-- =====================================================================
-- QUERY 1: COMPARE GRADES
-- Expected: seven rows in this dataset, one for each eligible grade.
-- school_level is displayed for context; grades stay separate.
-- =====================================================================
WITH settings AS (
    SELECT
        '2025-26' AS school_year,
        'Math' AS subject,
        'Spring' AS test_window
),
expected_tests AS (
    -- Each eligible enrollment contributes one expected test for the selected
    -- subject and window. Starting with enrollment preserves missing records.
    SELECT
        e.student_id,
        e.school_year,
        e.grade_level,
        s.school_level,
        p.subject,
        p.test_window,
        a.assessment_id,
        a.score
    FROM settings p
    JOIN public.enrollment e
        ON e.school_year = p.school_year
    JOIN public.schools s
        ON e.school_id = s.school_id
    LEFT JOIN public.assessments a
        ON e.student_id = a.student_id
       AND e.school_year = a.school_year
       AND a.subject = p.subject
       AND a."window" = p.test_window
    WHERE e.grade_level IN (3, 4, 5, 6, 7, 8, 11)
)
SELECT
    school_year,
    subject,
    test_window,
    grade_level,
    school_level,
    COUNT(*) AS expected_tests,
    COUNT(score) AS valid_tests,
    COUNT(*) - COUNT(score) AS without_valid_score,
    COUNT(assessment_id) - COUNT(score) AS recorded_without_score,
    COUNT(*) - COUNT(assessment_id) AS missing_test_records,
    COUNT(*) FILTER (WHERE score >= 510) AS proficient_students,
    COUNT(*) FILTER (WHERE score < 510) AS tested_below_proficiency,
    ROUND(
        100.0 * COUNT(score) / NULLIF(COUNT(*), 0),
        2
    ) AS participation_percentage,
    ROUND(
        100.0 * COUNT(*) FILTER (WHERE score >= 510)
        / NULLIF(COUNT(score), 0),
        2
    ) AS proficiency_percentage
FROM expected_tests
GROUP BY school_year, subject, test_window, grade_level, school_level
ORDER BY grade_level, school_level;

-- Grade 3 had 1737 valid scores out of 1819 expected tests, giving 95.49% participation. Among tested students, 54.40% met proficiency. 
-- The 82 students without valid scores were reported separately and excluded from the proficiency denominator.



-- =====================================================================
-- QUERY 2: COMPARE SCHOOL LEVELS
-- Expected: three rows in this dataset.
-- Elementary includes tested grades 3-5; Middle includes 6-8; High includes 11.
-- These are assessment-eligible populations, not total school enrollment.
-- Compute ratios from pooled counts; do NOT average the grade percentages.
-- This level summary is descriptive, not adjusted for grade composition.
-- =====================================================================
WITH settings AS (
    SELECT
        '2025-26' AS school_year,
        'Math' AS subject,
        'Spring' AS test_window
),
expected_tests AS (
    -- Each eligible enrollment contributes one expected test for the selected
    -- subject and window. Starting with enrollment preserves missing records.
    SELECT
        e.student_id,
        e.school_year,
        e.grade_level,
        s.school_level,
        p.subject,
        p.test_window,
        a.assessment_id,
        a.score
    FROM settings p
    JOIN public.enrollment e
        ON e.school_year = p.school_year
    JOIN public.schools s
        ON e.school_id = s.school_id
    LEFT JOIN public.assessments a
        ON e.student_id = a.student_id
       AND e.school_year = a.school_year
       AND a.subject = p.subject
       AND a."window" = p.test_window
    WHERE e.grade_level IN (3, 4, 5, 6, 7, 8, 11)
)
SELECT
    school_year,
    subject,
    test_window,
    school_level,
    COUNT(*) AS expected_tests,
    COUNT(score) AS valid_tests,
    COUNT(*) - COUNT(score) AS without_valid_score,
    COUNT(assessment_id) - COUNT(score) AS recorded_without_score,
    COUNT(*) - COUNT(assessment_id) AS missing_test_records,
    COUNT(*) FILTER (WHERE score >= 510) AS proficient_students,
    COUNT(*) FILTER (WHERE score < 510) AS tested_below_proficiency,
    ROUND(
        100.0 * COUNT(score) / NULLIF(COUNT(*), 0),
        2
    ) AS participation_percentage,
    ROUND(
        100.0 * COUNT(*) FILTER (WHERE score >= 510)
        / NULLIF(COUNT(score), 0),
        2
    ) AS proficiency_percentage
FROM expected_tests
GROUP BY school_year, subject, test_window, school_level
ORDER BY CASE school_level
    WHEN 'Elementary' THEN 1
    WHEN 'Middle' THEN 2
    WHEN 'High' THEN 3
    ELSE 4
END;

-- RECONCILIATION CHECKS TO PERFORM ON EACH RESULT ROW
-- valid_tests + without_valid_score = expected_tests
-- proficient_students + tested_below_proficiency = valid_tests
-- recorded_without_score + missing_test_records = without_valid_score
-- Sum grade-level counts to the corresponding school level and compare with
-- query 2. Derive level percentages from the summed counts.
-- Missing test records should be zero for the validated synthetic dataset;
-- existing assessment rows with NULL scores are expected and remain visible.
-- Do not interpret differences as evidence that a school level causes outcomes.









