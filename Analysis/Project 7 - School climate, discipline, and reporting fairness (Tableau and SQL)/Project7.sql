-- Synthetic demonstration — not an actual district
-- Purpose: distinguish incident volume from the share of students affected.
-- Output: one row per school year.
-- Discipline includes all enrolled grades.

WITH incidents_by_student_year AS (
    SELECT
        student_id,
        school_year,
        COUNT(DISTINCT incident_id) AS incident_count
    FROM discipline_incidents
    GROUP BY student_id, school_year
),
student_year AS (
    SELECT
        e.student_id,
        e.school_year,
        COALESCE(i.incident_count, 0) AS incident_count
    FROM enrollment AS e
    LEFT JOIN incidents_by_student_year AS i
        ON e.student_id = i.student_id
       AND e.school_year = i.school_year
)
SELECT
    school_year,
    COUNT(DISTINCT student_id) AS enrolled_students,
    SUM(incident_count) AS total_incidents,

    COUNT(DISTINCT student_id)
        FILTER (WHERE incident_count > 0)
        AS students_with_any_incident,

    ROUND(
        100.0 * SUM(incident_count)
        / NULLIF(COUNT(DISTINCT student_id), 0),
        2
    ) AS incidents_per_100_enrolled_students,

    ROUND(
        100.0 * COUNT(DISTINCT student_id)
            FILTER (WHERE incident_count > 0)
        / NULLIF(COUNT(DISTINCT student_id), 0),
        2
    ) AS pct_students_with_any_incident

FROM student_year
GROUP BY school_year
ORDER BY school_year;

-- Interpretation: Repeated incidents increase incidents_per_100_enrolled_students. 
-- Each student contributes only once to students_with_any_incident within a year.
-- The incident rate can exceed 100; the student percentage cannot.

---------------------------------------------------------------

-- Part 2: Survey participation: whose voices are missing?
-- How it works: Start with eligible enrollment in grades 4–12. Keep students even when
-- no survey response exists. Count distinct respondents within each race subgroup and 
-- year, then compare their share of respondents with their share of eligible enrollment.

-- Your schema permits only one survey record per student-year. Here, participation means
-- having a survey record, even if all three items were skipped. Query 3 measures those 
-- skips separately.


-- Synthetic demonstration — not an actual district
-- Purpose: identify survey nonparticipation and underrepresentation.
-- Output: one row per school year and race/ethnicity subgroup.
-- Eligible population: enrolled students in grades 4–12.

WITH eligible_students AS (
    SELECT
        e.student_id,
        e.school_year,
        COALESCE(
            NULLIF(BTRIM(s.race_ethnicity), ''),
            'Unknown'
        ) AS race_ethnicity,
        r.response_id
    FROM enrollment AS e
    JOIN students AS s
        ON e.student_id = s.student_id
    LEFT JOIN survey_responses AS r
        ON e.student_id = r.student_id
       AND e.school_year = r.school_year
    WHERE e.grade_level BETWEEN 4 AND 12
),
subgroup_counts AS (
    SELECT
        school_year,
        race_ethnicity,
        COUNT(DISTINCT student_id) AS eligible_students,
        COUNT(DISTINCT student_id)
            FILTER (WHERE response_id IS NOT NULL)
            AS survey_respondents
    FROM eligible_students
    GROUP BY school_year, race_ethnicity
),
rates AS (
    SELECT
        school_year,
        race_ethnicity,
        eligible_students,
        survey_respondents,
        eligible_students - survey_respondents AS nonrespondents,

        100.0 * survey_respondents
            / NULLIF(eligible_students, 0)
            AS participation_pct,

        100.0 * eligible_students
            / NULLIF(
                SUM(eligible_students) OVER (
                    PARTITION BY school_year
                ),
                0
            ) AS eligible_population_share_pct,

        100.0 * survey_respondents
            / NULLIF(
                SUM(survey_respondents) OVER (
                    PARTITION BY school_year
                ),
                0
            ) AS respondent_share_pct
    FROM subgroup_counts
)
SELECT
    school_year,
    race_ethnicity,
    eligible_students,
    survey_respondents,
    nonrespondents,
    ROUND(participation_pct, 2) AS participation_pct,
    ROUND(
        eligible_population_share_pct, 2
    ) AS eligible_population_share_pct,
    ROUND(
        respondent_share_pct, 2
    ) AS respondent_share_pct,
    ROUND(
        respondent_share_pct - eligible_population_share_pct,
        2
    ) AS representation_gap_percentage_points
FROM rates
ORDER BY school_year, participation_pct, race_ethnicity;


-- 3. Survey items: favorable responses and skipped items
-- How it works: Convert belonging, safety, and adult_support into separate item rows.
-- For each year, grade, school level, and item, count eligible students, survey 
-- participants, valid answers, favorable answers, and skipped items.

-- A favorable answer is a rating of 4 or 5. Favorable share uses valid answers as 
-- its denominator. Skipped-item rate uses survey participants, excluding students
-- who never participated.

-- Synthetic demonstration — not an actual district
-- Purpose: measure item responses without treating NULL ratings as zero.
-- Output: school year × grade × school level × survey item.

WITH eligible_student_items AS (
    SELECT
        e.student_id,
        e.school_year,
        e.grade_level,
        sc.school_level,
        r.response_id,
        item.item_name,
        item.rating
    FROM enrollment AS e
    JOIN schools AS sc
        ON e.school_id = sc.school_id
    LEFT JOIN survey_responses AS r
        ON e.student_id = r.student_id
       AND e.school_year = r.school_year
    CROSS JOIN LATERAL (
        VALUES
            ('belonging', r.belonging),
            ('safety', r.safety),
            ('adult_support', r.adult_support)
    ) AS item(item_name, rating)
    WHERE e.grade_level BETWEEN 4 AND 12
),
item_counts AS (
    SELECT
        school_year,
        grade_level,
        school_level,
        item_name,

        COUNT(DISTINCT student_id) AS eligible_students,

        COUNT(DISTINCT student_id)
            FILTER (WHERE response_id IS NOT NULL)
            AS survey_respondents,

        COUNT(DISTINCT student_id)
            FILTER (WHERE rating IS NOT NULL)
            AS valid_item_responses,

        COUNT(DISTINCT student_id)
            FILTER (WHERE rating >= 4)
            AS favorable_responses,

        COUNT(DISTINCT student_id)
            FILTER (
                WHERE response_id IS NOT NULL
                  AND rating IS NULL
            ) AS skipped_item_responses

    FROM eligible_student_items
    GROUP BY
        school_year,
        grade_level,
        school_level,
        item_name
)
SELECT
    school_year,
    grade_level,
    school_level,
    item_name,
    eligible_students,
    survey_respondents,
    eligible_students - survey_respondents AS nonrespondents,
    valid_item_responses,
    favorable_responses,
    skipped_item_responses,

    ROUND(
        100.0 * survey_respondents
        / NULLIF(eligible_students, 0),
        2
    ) AS survey_participation_pct,

    ROUND(
        100.0 * favorable_responses
        / NULLIF(valid_item_responses, 0),
        2
    ) AS favorable_response_pct,

    ROUND(
        100.0 * skipped_item_responses
        / NULLIF(survey_respondents, 0),
        2
    ) AS skipped_item_pct

FROM item_counts
ORDER BY school_year, school_level, grade_level, item_name;


-- Check: For each output row, valid_item_responses + skipped_item_responses should 
-- equal survey_respondents. If nobody answers an item, its favorable percentage is 
-- NULL rather than zero.

-- These are internal analysis results. Before publishing the Tableau dashboard, 
-- Project 7 still requires response distributions, subgroup comparisons, and 
-- suppression of cells below 10—with complementary suppression or filter
-- restrictions where totals could reveal hidden values. Ten is the project’s 
-- portfolio convention, not a guarantee of privacy.

-- Synthetic demonstration — not an actual district
-- Project 7, Part 2: survey participation and item responses.
--
-- Definitions:
-- Participation = students with a survey record / eligible students.
-- Favorable share = ratings of 4 or 5 / non-NULL item responses.
-- Skipped-item rate = participants with a NULL item / participants.

WITH eligible_students AS (
    SELECT
        e.student_id,
        e.school_year,
        r.response_id,
        r.belonging,
        r.safety,
        r.adult_support
    FROM enrollment AS e
    LEFT JOIN survey_responses AS r
        ON e.student_id = r.student_id
       AND e.school_year = r.school_year
    WHERE e.grade_level BETWEEN 4 AND 12
),
student_items AS (
    SELECT
        e.student_id,
        e.school_year,
        e.response_id,
        item.item_name,
        item.rating
    FROM eligible_students AS e
    CROSS JOIN LATERAL (
        VALUES
            ('belonging', e.belonging),
            ('safety', e.safety),
            ('adult_support', e.adult_support)
    ) AS item(item_name, rating)
),
item_counts AS (
    SELECT
        school_year,
        item_name,

        COUNT(DISTINCT student_id) AS eligible_students,

        COUNT(DISTINCT student_id)
            FILTER (WHERE response_id IS NOT NULL)
            AS survey_participants,

        COUNT(DISTINCT student_id)
            FILTER (WHERE response_id IS NULL)
            AS survey_nonparticipants,

        COUNT(DISTINCT student_id)
            FILTER (WHERE rating IS NOT NULL)
            AS valid_item_responses,

        COUNT(DISTINCT student_id)
            FILTER (WHERE rating >= 4)
            AS favorable_responses,

        COUNT(DISTINCT student_id)
            FILTER (
                WHERE response_id IS NOT NULL
                  AND rating IS NULL
            ) AS skipped_item_responses

    FROM student_items
    GROUP BY school_year, item_name
)
SELECT
    school_year,
    item_name,
    eligible_students,
    survey_participants,
    survey_nonparticipants,

    ROUND(
        100.0 * survey_participants
        / NULLIF(eligible_students, 0),
        2
    ) AS survey_participation_pct,

    valid_item_responses,
    favorable_responses,

    ROUND(
        100.0 * favorable_responses
        / NULLIF(valid_item_responses, 0),
        2
    ) AS favorable_response_pct,

    skipped_item_responses,

    ROUND(
        100.0 * skipped_item_responses
        / NULLIF(survey_participants, 0),
        2
    ) AS skipped_item_pct,

    -- Both checks should return TRUE on every row.
    eligible_students =
        survey_participants + survey_nonparticipants
        AS participation_counts_reconcile,

    survey_participants =
        valid_item_responses + skipped_item_responses
        AS item_counts_reconcile

FROM item_counts
ORDER BY school_year, item_name;

-- Identify eligible students. BETWEEN 4 AND 12 includes grades 4 through 12. The 
-- LEFT JOIN retains students without a survey record. Matching both student ID and
-- school year prevents responses from another year from being counted.

-- Separate the three survey items. CROSS JOIN LATERAL ... VALUES turns the three rating
-- columns into item rows named belonging, safety, and adult_support. Each student 
-- appears once per item in each year.

-- Count students distinctly. PostgreSQL’s FILTER counts students meeting each condition.

-- A survey record establishes participation—even if the student skipped all three items.

-- Calculate percentages with the correct denominators.

-- “Survey participation was calculated among enrolled students in grades 4–12 for each 
-- school year. Favorable response share represents ratings of 4 or 5 among students
-- who answered each item. Skipped-item rates represent missing item responses among
-- survey participants; students without a survey record were counted separately as 
-- nonparticipants.”


-- Synthetic demonstration — not an actual district
-- Project 7 part 3: survey comparisons with group sizes.
-- These are internal analysis results before public suppression.

WITH eligible_students AS (
    SELECT
        e.student_id,
        e.school_year,
        e.grade_level,
        sc.school_level,
        COALESCE(
            NULLIF(BTRIM(s.race_ethnicity), ''),
            'Unknown'
        ) AS race_ethnicity,
        r.response_id,
        r.belonging,
        r.safety,
        r.adult_support
    FROM enrollment AS e
    JOIN students AS s
        ON e.student_id = s.student_id
    JOIN schools AS sc
        ON e.school_id = sc.school_id
    LEFT JOIN survey_responses AS r
        ON e.student_id = r.student_id
       AND e.school_year = r.school_year
    WHERE e.grade_level BETWEEN 4 AND 12
),
comparison_rows AS (
    SELECT
        e.*,
        comparison.comparison_type,
        comparison.comparison_group,
        item.item_name,
        item.rating
    FROM eligible_students AS e

    CROSS JOIN LATERAL (
        VALUES
            ('School level', 'All eligible students'),
            ('Grade', e.grade_level::text),
            ('Race/ethnicity', e.race_ethnicity)
    ) AS comparison(comparison_type, comparison_group)

    CROSS JOIN LATERAL (
        VALUES
            ('belonging', e.belonging),
            ('safety', e.safety),
            ('adult_support', e.adult_support)
    ) AS item(item_name, rating)
),
group_counts AS (
    SELECT
        school_year,
        school_level,
        comparison_type,
        comparison_group,
        item_name,

        COUNT(DISTINCT student_id) AS eligible_students,

        COUNT(DISTINCT student_id)
            FILTER (WHERE response_id IS NOT NULL)
            AS survey_participants,

        COUNT(DISTINCT student_id)
            FILTER (WHERE rating IS NOT NULL)
            AS valid_item_responses,

        COUNT(DISTINCT student_id)
            FILTER (WHERE rating >= 4)
            AS favorable_responses,

        COUNT(DISTINCT student_id)
            FILTER (
                WHERE response_id IS NOT NULL
                  AND rating IS NULL
            ) AS skipped_item_responses

    FROM comparison_rows
    GROUP BY
        school_year,
        school_level,
        comparison_type,
        comparison_group,
        item_name
)
SELECT
    school_year,
    school_level,
    comparison_type,
    comparison_group,
    item_name,
    eligible_students,
    survey_participants,
    eligible_students - survey_participants AS nonparticipants,
    valid_item_responses,
    favorable_responses,
    skipped_item_responses,

    ROUND(
        100.0 * survey_participants
        / NULLIF(eligible_students, 0),
        2
    ) AS participation_pct,

    ROUND(
        100.0 * favorable_responses
        / NULLIF(valid_item_responses, 0),
        2
    ) AS favorable_response_pct,

    ROUND(
        100.0 * skipped_item_responses
        / NULLIF(survey_participants, 0),
        2
    ) AS skipped_item_pct

FROM group_counts
ORDER BY
    school_year,
    school_level,
    comparison_type,
    CASE
        WHEN comparison_type = 'Grade'
        THEN comparison_group::integer
    END,
    comparison_group,
    item_name;

-- How it works: The first CTE creates one row per eligible student-year. 
-- The two LATERAL expressions organize each student into comparison categories 
-- and survey items. The final aggregation counts students separately within each
-- category and item.

-- Do not add together different comparison types or items. They contain overlapping 
-- students. For example, the same student contributes to a school-level total, a grade
-- group, and a race subgroup.

-- For school-level comparisons, remember that the elementary survey population includes 
-- only eligible grades 4–12—not every elementary student.


-- 3.2. Compare discipline using the same grouping approach
-- Discipline uses all enrolled grades, including students too young for the survey.

-- Synthetic demonstration — not an actual district
-- Project 7: discipline comparisons with group sizes.
-- These are internal analysis results before public suppression.

WITH incident_counts AS (
    SELECT
        student_id,
        school_year,
        COUNT(DISTINCT incident_id) AS incident_count
    FROM discipline_incidents
    GROUP BY student_id, school_year
),
student_year AS (
    SELECT
        e.student_id,
        e.school_year,
        e.grade_level,
        sc.school_level,
        COALESCE(
            NULLIF(BTRIM(s.race_ethnicity), ''),
            'Unknown'
        ) AS race_ethnicity,
        COALESCE(i.incident_count, 0) AS incident_count
    FROM enrollment AS e
    JOIN students AS s
        ON e.student_id = s.student_id
    JOIN schools AS sc
        ON e.school_id = sc.school_id
    LEFT JOIN incident_counts AS i
        ON e.student_id = i.student_id
       AND e.school_year = i.school_year
),
comparison_rows AS (
    SELECT
        sy.*,
        comparison.comparison_type,
        comparison.comparison_group
    FROM student_year AS sy
    CROSS JOIN LATERAL (
        VALUES
            ('School level', 'All enrolled students'),
            ('Grade', sy.grade_level::text),
            ('Race/ethnicity', sy.race_ethnicity)
    ) AS comparison(comparison_type, comparison_group)
)
SELECT
    school_year,
    school_level,
    comparison_type,
    comparison_group,

    COUNT(DISTINCT student_id) AS enrolled_students,

    SUM(incident_count) AS total_incidents,

    COUNT(DISTINCT student_id)
        FILTER (WHERE incident_count > 0)
        AS students_with_any_incident,

    ROUND(
        100.0 * SUM(incident_count)
        / NULLIF(COUNT(DISTINCT student_id), 0),
        2
    ) AS incidents_per_100_enrolled_students,

    ROUND(
        100.0 * COUNT(DISTINCT student_id)
            FILTER (WHERE incident_count > 0)
        / NULLIF(COUNT(DISTINCT student_id), 0),
        2
    ) AS pct_students_with_any_incident

FROM comparison_rows
GROUP BY
    school_year,
    school_level,
    comparison_type,
    comparison_group
ORDER BY
    school_year,
    school_level,
    comparison_type,
    CASE
        WHEN comparison_type = 'Grade'
        THEN comparison_group::integer
    END,
    comparison_group;


-- How it works: Incidents are aggregated to one row per student-year before 
-- joining enrollment. This prevents repeated incidents from inflating the enrollment 
-- count. Students with no incident remain in the denominator.

-- Keep survey and discipline outputs as separate Tableau data sources for these 
-- comparisons; their populations and row structures differ.






