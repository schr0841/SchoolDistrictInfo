-- Project 5, Part 1. Synthetic demonstration — not an actual district.
-- One row per program/year. Participants include zero-attendance records.
-- Completion measures attended sessions / planned sessions.
-- Cost is the supplied record cost, not a complete district program budget.
SELECT
    school_year,
    intervention_type AS program,
    COUNT(*) AS intervention_records,
    COUNT(DISTINCT student_id) AS participants,
    COUNT(DISTINCT student_id) FILTER (WHERE attended_sessions > 0)
        AS participants_attending_at_least_one_session,
    COUNT(DISTINCT student_id) FILTER (WHERE attended_sessions = 0)
        AS participants_with_zero_attendance,
    SUM(planned_sessions) AS planned_sessions,
    SUM(attended_sessions) AS attended_sessions,
    SUM(planned_sessions - attended_sessions) AS unattended_planned_sessions,
    ROUND(SUM(attended_sessions)::numeric
        / NULLIF(SUM(planned_sessions), 0), 4) AS session_completion_rate,
    ROUND(SUM(cost), 2) AS total_recorded_cost,
    ROUND(SUM(cost) / NULLIF(SUM(attended_sessions), 0), 2)
        AS cost_per_attended_session
FROM public.interventions
GROUP BY school_year, intervention_type
ORDER BY school_year, intervention_type;

-- Optional check: run separately. Expected result: NULL, not zero.
SELECT ROUND(100::numeric / NULLIF(0, 0), 2)
    AS zero_attendance_cost_example;


-- Summary: In 2023-2024, Attendance mentoring had 1942 recorded participants, including 
-- 0 who attended no sessions. Students attended 40061 of 54227 planned sessions, 
-- a session completion rate of 73.88%. Total recorded cost was $1430114.71, equivalent 
-- to $35.70 per attended session. These figures describe program delivery; they do 
-- not establish program effectiveness.


-- Project 5, Part 2. Synthetic demonstration — not an actual district.
-- Run sections separately in order. Creates one new view, not a physical table.
-- Prior need here is a hypothetical PRIOR-YEAR absence category, not eligibility.

-- SECTION 1: One row per enrolled student-year.
CREATE OR REPLACE VIEW public.project5_student_year AS
WITH annual_attendance AS (
    SELECT student_id, school_year,
           SUM(membership_days) AS membership_days,
           SUM(present_days) AS present_days,
           SUM(excused_absent_days + unexcused_absent_days) AS absent_days
    FROM public.attendance_monthly
    GROUP BY student_id, school_year
), growth_wide AS (
    -- Keep Math and Reading separate while preserving student-year grain.
    SELECT student_id, school_year,
           MAX(growth_points) FILTER (WHERE subject = 'Math') AS math_growth_points,
           MAX(growth_points) FILTER (WHERE subject = 'Reading') AS reading_growth_points
    FROM public.assessment_growth
    GROUP BY student_id, school_year
)
SELECT e.student_id, e.school_year, e.school_id, e.grade_level,
       a.membership_days, a.present_days, a.absent_days,
       a.present_days::numeric / NULLIF(a.membership_days, 0) AS attendance_rate,
       p.school_year AS prior_school_year,
       p.membership_days AS prior_membership_days,
       p.absent_days AS prior_absent_days,
       p.absent_days::numeric / NULLIF(p.membership_days, 0) AS prior_absence_rate,
       CASE
           WHEN p.student_id IS NULL OR p.membership_days IS NULL
                OR p.membership_days <= 0 OR p.absent_days IS NULL
               THEN 'No usable prior-year attendance'
           WHEN p.absent_days::numeric / p.membership_days >= 0.10
               THEN 'Prior absence: 10% or more'
           WHEN p.absent_days::numeric / p.membership_days >= 0.05
               THEN 'Prior absence: 5% to under 10%'
           ELSE 'Prior absence: under 5%'
       END AS prior_need_category,
       (i.intervention_id IS NOT NULL) AS recorded_participant,
       i.intervention_type AS program,
       i.planned_sessions, i.attended_sessions, i.cost AS intervention_cost,
       g.math_growth_points, g.reading_growth_points,
       (e.grade_level BETWEEN 3 AND 8 OR e.grade_level = 11)
           AS assessment_eligible
FROM public.enrollment e
LEFT JOIN annual_attendance a
  ON a.student_id = e.student_id AND a.school_year = e.school_year
LEFT JOIN annual_attendance p
  ON p.student_id = e.student_id
 AND split_part(p.school_year, '-', 1)::integer
     = split_part(e.school_year, '-', 1)::integer - 1
LEFT JOIN public.interventions i
  ON i.student_id = e.student_id AND i.school_year = e.school_year
LEFT JOIN growth_wide g
  ON g.student_id = e.student_id AND g.school_year = e.school_year;


-- Inspect results
SELECT *
FROM public.project5_student_year
ORDER BY student_id, school_year
LIMIT 30;


-- SECTION 2: Grain check. Expect 60000, 60000, 60000.
SELECT (SELECT COUNT(*) FROM public.enrollment) AS enrollment_rows,
       COUNT(*) AS student_year_rows,
       COUNT(DISTINCT (student_id, school_year)) AS distinct_student_years
FROM public.project5_student_year;

-- Verified count of 60000 for each field


-- SECTION 3: Prior-year coverage. The first year has no observed prior year.
SELECT school_year, prior_need_category, COUNT(*) AS students
FROM public.project5_student_year
GROUP BY school_year, prior_need_category
ORDER BY school_year, prior_need_category;




-- SECTION 4: Example comparison: 2025-26, current grade 5, Math tutoring.
-- Change the four settings together when studying another program/subject.
-- Attendance mentoring can be examined separately for Math and Reading.
-- Other intervention programs are excluded, not relabeled as nonparticipants.
-- Results remain descriptive: no random assignment or causal inference.
WITH settings AS (
    SELECT '2025-26'::text AS target_year,
           5::integer AS target_grade,
           'Math tutoring'::text AS target_program,
           'Math'::text AS target_subject
), comparison_students AS (
    SELECT v.*, s.target_program, s.target_subject,
           CASE WHEN v.recorded_participant
                THEN 'Recorded participant'
                ELSE 'No recorded intervention' END AS comparison_group,
           CASE s.target_subject
               WHEN 'Math' THEN v.math_growth_points
               WHEN 'Reading' THEN v.reading_growth_points
           END AS selected_subject_growth
    FROM public.project5_student_year v
    CROSS JOIN settings s
    WHERE v.school_year = s.target_year
      AND v.grade_level = s.target_grade
      AND (v.program = s.target_program OR NOT v.recorded_participant)
      AND v.prior_need_category <> 'No usable prior-year attendance'
)
SELECT school_year, grade_level, target_program, target_subject,
       prior_need_category, comparison_group,
       COUNT(*) AS students,
       COUNT(*) FILTER (WHERE membership_days > 0 AND present_days IS NOT NULL)
           AS students_with_valid_attendance,
       SUM(present_days) FILTER (WHERE membership_days > 0 AND present_days IS NOT NULL)
           AS present_days,
       SUM(membership_days) FILTER (WHERE membership_days > 0 AND present_days IS NOT NULL)
           AS membership_days,
       ROUND(
           (SUM(present_days) FILTER (WHERE membership_days > 0 AND present_days IS NOT NULL))::numeric
           / NULLIF(SUM(membership_days) FILTER (WHERE membership_days > 0 AND present_days IS NOT NULL), 0),
           4
       ) AS attendance_rate,
       COUNT(*) FILTER (WHERE assessment_eligible) AS assessment_eligible_students,
       COUNT(selected_subject_growth) FILTER (WHERE assessment_eligible) AS paired_students,
       COUNT(*) FILTER (WHERE assessment_eligible AND selected_subject_growth IS NULL)
           AS eligible_students_without_pair,
       ROUND(AVG(selected_subject_growth) FILTER (WHERE assessment_eligible), 2)
           AS mean_paired_growth_points
FROM comparison_students
GROUP BY school_year, grade_level, target_program, target_subject,
         prior_need_category, comparison_group
ORDER BY prior_need_category, comparison_group;


-- Among 2025–26 fifth graders with prior-year absence of 10% or more, Math tutoring 
-- participants had an attendance rate of 92%, compared with 87.9% among students 
-- with no recorded intervention. Average matched Math growth was 10.50 points among 
-- 12 participants and 19.61 points among 242 comparison students. (1, 25) eligible 
-- students in each group lacked matched scores.

-- These are descriptive comparisons. Students were not randomly assigned, and matching 
-- grade and prior attendance does not make the groups equivalent in academic need or
-- other characteristics.

-- In particular, higher or lower growth does not establish that tutoring caused the 
-- difference. Prior achievement, program selection, participation timing, and 
-- missing tests remain questions for further study.


