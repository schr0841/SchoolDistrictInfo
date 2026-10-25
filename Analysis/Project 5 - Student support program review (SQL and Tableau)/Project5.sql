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
















