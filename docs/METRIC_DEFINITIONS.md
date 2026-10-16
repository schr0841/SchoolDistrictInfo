# Field interpretation and metric contract

These are portfolio conventions for fictional data, not assertions about any state's reporting requirements.

| Field or concept | Definition |
|---|---|
| student_id | Stable fictional key across all three years; contains no real identifier |
| student_alias | Display alias such as Learner 00001; not a real name |
| school_year | Academic year label; 2023-24 means September 2023–May 2024 |
| school_id | E, M, H prefix identifies Elementary, Middle, High |
| capacity | Hypothetical building student capacity, constant across years |
| grade_level | Integer 0–12; 0 is kindergarten |
| economic_disadvantage | Fictional support-eligibility flag, not inferred from income or a real policy |
| english_learner | Fictional English learner service status, not equivalent to home language |
| iep | Fictional individualized education program status; no diagnosis or disability detail |
| prior_year_transfer | School differs from prior year within the same school level; normal elementary-to-middle and middle-to-high transitions are excluded |
| gender, race_ethnicity, home_language | Fictional categorical attributes with explicit Not reported categories where present; no geography or causal outcome interpretation |
| membership_days | Days enrolled in the fictional instructional calendar |
| present_days | Membership days minus all absence days |
| tardy_days | Present days with tardiness; not extra absence days |
| attendance rate | Sum present days / sum membership days; report as percent |
| chronic absence | Annual (excused + unexcused absence) / annual membership >=0.10 |
| chronic absence rate | Chronically absent student-years / enrolled student-years in the selected year |
| assessment window | Fall or Spring within a school year; no precise test dates are modeled |
| score | Fictional 200–800 common scale; NULL means untested |
| performance_level | Beginning <450; Developing 450–509; Proficient 510–569; Advanced >=570; NULL for untested |
| proficiency share | Valid scores >=510 / all valid scores in the selected grade/subject/window |
| assessment participation | Valid scores / expected assessment rows in eligible grades/subject/window |
| growth_points | Spring minus Fall for the same student, year, subject; both scores required |
| percent_grade | Semester subject percentage; >=60 is passing |
| failed_course_semesters | Count of subject-semester rows below 60, not unique courses |
| credits_attempted | 0.5 per observed semester subject in high school; 0 in middle school |
| credits_earned | Attempted credits if passing; otherwise zero |
| planned_sessions, attended_sessions | Program delivery counts; attended <= planned |
| intervention cost | Simulated program cost; not a separate additive district finance category |
| incident_category, response | Fictional behavioral event classification and response; one student per record, not a shared multi-student event |
| suspension_days | Assigned response days; potential overlap with attendance, so do not add to absence totals |
| FTE | Full-time-equivalent role staffing, not headcount |
| salary_benefits | Estimated annual compensation cost for role FTE; finance already covers staffing |
| budget, actual | Annual school-category planned and actual nominal dollars |
| budget_variance | Actual minus budget; positive = over budget |
| spending_per_student | School-year actual operating spending / school-year enrollment |
| students_per_teacher_fte | School-year enrollment / teacher FTE; not classroom size |
| capacity_utilization | Enrollment / school capacity; >100% means hypothetical over-capacity |
| belonging, safety, adult_support | Voluntary survey item ratings 1–5; favorable =4 or 5; blank = skipped item |
| survey participation | Number of response rows / enrolled students in grades 4–12 |
| survey favorable share | Nonmissing item ratings >=4 / nonmissing ratings for that item |
| percentage-point change | 100 × (current proportion − previous proportion), distinct from relative percent change |

All school-year headcounts refer to full-year enrollment in this closed cohort. When combining years, label counts as student-years or use COUNT(DISTINCT student_id) for unique people. Weighted district ratios and a simple average of school ratios answer different questions.
