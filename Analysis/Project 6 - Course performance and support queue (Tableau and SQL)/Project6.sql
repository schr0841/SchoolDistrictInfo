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


-- Project 6, Part 2: Transparent hypothetical counselor check-in rules.
-- Synthetic demonstration — not an actual district.
-- Requires public.project6_student_year_courses (Part 1).
-- Run sections separately. Section 1 creates a new view; no source data changes.

-- SECTION 1: Each rule is TRUE, FALSE, or NULL (cannot determine).
CREATE OR REPLACE VIEW public.project6_support_rules AS
WITH thresholds AS (
    -- Fixed, documented portfolio assumptions; edit only here to change rules.
    SELECT 18::integer AS absence_threshold_days,
           2::integer AS failure_threshold,
           180::integer AS expected_membership_days
), flags AS (
    SELECT c.*, t.absence_threshold_days, t.failure_threshold,
           t.expected_membership_days,
           CASE
               -- This annual prototype requires the dataset's full 180 days.
               WHEN c.membership_days IS NULL
                 OR c.membership_days <> t.expected_membership_days
                 OR c.absent_days IS NULL
                 OR c.absent_days < 0 OR c.absent_days > c.membership_days
                   THEN NULL::boolean
               ELSE c.absent_days >= t.absence_threshold_days
           END AS absence_rule_met,
           CASE
               WHEN c.failed_course_semesters IS NULL THEN NULL::boolean
               -- Enough observed failures establish the threshold even if
               -- other course records are missing. Coverage still needs review.
               WHEN c.failed_course_semesters >= t.failure_threshold THEN TRUE
               WHEN c.course_semester_records = c.expected_course_semester_records
                   THEN FALSE
               -- Fewer than 2 observed failures in incomplete records is unknown.
               ELSE NULL::boolean
           END AS course_failure_rule_met
    FROM public.project6_student_year_courses c
    CROSS JOIN thresholds t
    WHERE c.course_eligible
)
SELECT f.*,
       CASE absence_rule_met
           WHEN TRUE THEN 'Meets absence rule'
           WHEN FALSE THEN 'Below absence threshold'
           ELSE 'Cannot evaluate: attendance coverage/values'
       END AS absence_rule_status,
       CASE course_failure_rule_met
           WHEN TRUE THEN 'Meets observed course-failure rule'
           WHEN FALSE THEN 'Below failure threshold: expected records observed'
           ELSE 'Cannot rule out: missing/incomplete course records'
       END AS course_failure_rule_status,
       (absence_rule_met OR course_failure_rule_met) AS any_rule_met,
       CASE
           WHEN absence_rule_met AND course_failure_rule_met
               THEN 'Both rules'
           WHEN absence_rule_met IS TRUE
               THEN 'Absence rule'
           WHEN course_failure_rule_met IS TRUE
               THEN 'Course-failure rule'
           WHEN absence_rule_met IS NULL OR course_failure_rule_met IS NULL
               THEN 'Insufficient data; no observed rule met'
           ELSE 'Neither rule met'
       END AS reason_category,
       (absence_rule_met IS NULL OR course_failure_rule_met IS NULL)
           AS needs_rule_data_review,
       CASE
           WHEN absence_rule_met IS TRUE OR course_failure_rule_met IS TRUE
               THEN 'Hypothetical counselor review candidate'
           WHEN absence_rule_met IS NULL OR course_failure_rule_met IS NULL
               THEN 'Data review needed; selection unresolved'
           ELSE 'Not selected by these rules'
       END AS review_status
FROM flags f;

-- SELECT * FROM public.project6_support_rules limit 10;
-- verify that the view public.project6_support_rules was created

-- SECTION 2: Population/grain checks. The three counts must match.
SELECT (SELECT COUNT(*) FROM public.project6_student_year_courses
        WHERE course_eligible) AS eligible_source_rows,
       COUNT(*) AS rule_rows,
       COUNT(DISTINCT (student_id, school_year)) AS distinct_student_years
FROM public.project6_support_rules;

-- Check: all 3 fields have 32724 records



-- SECTION 3: Inspect separate flags for one year/grade, including noncandidates.
SELECT student_alias, school_year, grade_level,
       absent_days, membership_days, absence_threshold_days,
       absence_rule_met, absence_rule_status,
       course_semester_records, course_record_status,
       failed_course_semesters, failure_threshold,
       course_failure_rule_met, course_failure_rule_status,
       any_rule_met, reason_category, needs_rule_data_review, review_status
FROM public.project6_support_rules
WHERE school_year = '2025-26' AND grade_level = 6
ORDER BY any_rule_met DESC NULLS LAST, absent_days DESC, student_alias
LIMIT 100;

-- SECTION 4: Workload by year/grade. Rule counts overlap: do not add them.
SELECT school_year, grade_level,
       MAX(absence_threshold_days) AS absence_threshold_days,
       MAX(failure_threshold) AS failure_threshold,
       COUNT(*) AS eligible_students,
       COUNT(*) FILTER (WHERE absence_rule_met IS TRUE) AS meets_absence_rule,
       COUNT(*) FILTER (WHERE course_failure_rule_met IS TRUE) AS meets_failure_rule,
       COUNT(*) FILTER (WHERE absence_rule_met IS TRUE AND course_failure_rule_met IS TRUE)
           AS meets_both_rules,
       COUNT(*) FILTER (WHERE any_rule_met IS TRUE) AS unique_review_candidates,
       COUNT(*) FILTER (WHERE any_rule_met IS FALSE) AS neither_rule_met,
       COUNT(*) FILTER (WHERE any_rule_met IS NULL) AS unresolved_selection,
       COUNT(*) FILTER (WHERE needs_rule_data_review) AS students_with_unknown_rule,
       COUNT(*) FILTER (WHERE course_record_status <> 'Eligible: expected 8 records observed')
           AS students_with_course_coverage_issue
FROM public.project6_support_rules
GROUP BY school_year, grade_level
ORDER BY school_year, grade_level;

-- SECTION 5: Candidate detail for internal SYNTHETIC portfolio use only.
-- This is a list for hypothetical human review, not automatic action.
SELECT student_alias, school_year, school_id, grade_level,
       absent_days, absence_threshold_days, absence_rule_met,
       failed_course_semesters, failure_threshold, course_failure_rule_met,
       course_record_status, needs_rule_data_review, reason_category
FROM public.project6_support_rules
WHERE school_year = '2025-26' AND any_rule_met IS TRUE
ORDER BY grade_level, student_alias;

-- Limits: retrospective annual totals, not a midyear alert; no causal or
-- predictive validation; not for eligibility, discipline, or placement.
-- Two failures = two subject-semester grades below 60, not two subjects.
-- Grade 6-8 failures count even though credits are zero by design.
-- Grade/course coverage remains visible even when another rule is met.


