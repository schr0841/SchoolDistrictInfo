-- Project 6, Part 1: Course performance, one row per student-year.
-- Synthetic demonstration — not an actual district.
-- Run sections separately in order. Section 1 creates a new reporting view.
-- No raw monthly attendance / course joins. student_year_metrics is annual.

-- SECTION 1: Preserve the enrolled population and distinguish missing records.
CREATE OR REPLACE VIEW public.project6_student_year_courses AS
WITH courses AS (
    SELECT student_id, school_year,
           COUNT(*) AS course_semester_records,
           COUNT(*) FILTER (WHERE percent_grade < 60) AS failed_course_semesters,
           SUM(credits_attempted) AS observed_credits_attempted,
           SUM(credits_earned) AS observed_credits_earned
    FROM public.course_grades
    GROUP BY student_id, school_year
)
SELECT s.student_id, s.student_alias, s.school_year, s.school_id, s.grade_level,
       s.absent_days, s.membership_days, s.attendance_rate,
       (s.grade_level BETWEEN 6 AND 12) AS course_eligible,
       COALESCE(c.course_semester_records, 0) AS course_semester_records,
       CASE WHEN s.grade_level BETWEEN 6 AND 12 THEN 8 ELSE 0 END
           AS expected_course_semester_records,
       CASE
           WHEN s.grade_level NOT BETWEEN 6 AND 12
                AND c.course_semester_records IS NOT NULL
               THEN 'Unexpected records outside eligible grades'
           WHEN s.grade_level NOT BETWEEN 6 AND 12
               THEN 'Not eligible: outside grades 6-12'
           WHEN c.course_semester_records IS NULL
               THEN 'Eligible: no course records'
           WHEN c.course_semester_records < 8
               THEN 'Eligible: partial records'
           WHEN c.course_semester_records > 8
               THEN 'Eligible: more records than expected'
           ELSE 'Eligible: expected 8 records observed'
       END AS course_record_status,
       CASE WHEN s.grade_level BETWEEN 6 AND 12
            THEN c.failed_course_semesters END AS failed_course_semesters,
       CASE WHEN s.grade_level BETWEEN 6 AND 12
            THEN c.observed_credits_attempted END AS observed_credits_attempted,
       CASE WHEN s.grade_level BETWEEN 6 AND 12
            THEN c.observed_credits_earned END AS observed_credits_earned
FROM public.student_year_metrics s
LEFT JOIN courses c
  ON c.student_id = s.student_id AND c.school_year = s.school_year;

-- SECTION 2: Grain and population check. Expect all three counts = 60000.
SELECT (SELECT COUNT(*) FROM public.student_year_metrics) AS source_student_years,
       COUNT(*) AS output_student_years,
       COUNT(DISTINCT (student_id, school_year)) AS distinct_student_years
FROM public.project6_student_year_courses;

-- SECTION 3: Coverage by current grade/year. Look here BEFORE outcomes.
SELECT school_year, grade_level, course_record_status,
       COUNT(*) AS students,
       SUM(course_semester_records) AS course_semester_records
FROM public.project6_student_year_courses
GROUP BY school_year, grade_level, course_record_status
ORDER BY school_year, grade_level, course_record_status;

-- SECTION 4: Eligible student detail; change grade/year as needed.
-- Initially grade 6: zero credits are expected even when courses are passed.
-- Change grade_level to 9 to inspect credit-bearing courses.
SELECT student_id, student_alias, school_year, grade_level,
       course_semester_records, expected_course_semester_records,
       course_record_status, failed_course_semesters,
       observed_credits_attempted, observed_credits_earned
FROM public.project6_student_year_courses
WHERE school_year = '2025-26' AND grade_level = 9
ORDER BY failed_course_semesters DESC NULLS LAST, student_id
LIMIT 50;

-- SECTION 5: Eligible grade/year summary; preserve coverage denominators.
-- Outcome totals describe observed records, including any partial records.
-- NULL remains distinct from zero. These are student-year counts.
SELECT school_year, grade_level,
       COUNT(*) AS eligible_students,
       COUNT(*) FILTER (WHERE course_semester_records = 0)
           AS students_without_course_records,
       COUNT(*) FILTER (WHERE course_semester_records BETWEEN 1 AND 7)
           AS students_with_partial_records,
       COUNT(*) FILTER (WHERE course_semester_records = 8)
           AS students_with_expected_records,
       COUNT(*) FILTER (WHERE failed_course_semesters = 0)
           AS students_with_observed_zero_failures,
       COUNT(*) FILTER (WHERE failed_course_semesters > 0)
           AS students_with_observed_failures,
       SUM(failed_course_semesters) AS total_observed_failed_course_semesters,
       SUM(observed_credits_attempted) AS total_observed_credits_attempted,
       SUM(observed_credits_earned) AS total_observed_credits_earned
FROM public.project6_student_year_courses
WHERE course_eligible
GROUP BY school_year, grade_level
ORDER BY school_year, grade_level;

-- Interpretation:
-- Four observed subjects x two semesters = 8 expected rows for grades 6-12.
-- Failure = percent_grade < 60; same subject failed twice counts twice.
-- Grades 6-8: zero credits attempted/earned by design, not evidence of failure.
-- Grades 9-12: 0.5 attempted per course-semester, earned when grade >=60.
-- Missing course records produce NULL outcomes, not zero failures/credits.
-- A partial record set with zero failures means zero OBSERVED failures only.
-- Four subjects are not a full transcript or a graduation-readiness measure.
-- Annual metrics are retrospective; this is not a validated prediction model.

-- Course performance is summarized at the student-year level for grades 6–12.
-- A failed course-semester is an observed subject-semester grade below 60%. 
-- Repeated failures in the same subject across semesters count separately. 
-- Record coverage is reported alongside outcomes: eligible students without
-- course records retain NULL failure and credit measures rather than being 
-- classified as having zero failures. Grades 6–8 carry zero credits by design. 
-- Observed credits cover four subjects only and do not establish graduation 
-- readiness.






