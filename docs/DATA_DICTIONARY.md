# Data dictionary

All data are fictional. CSV: UTF-8, header row, comma delimiter, ISO dates, decimal point, no thousands separators. Empty fields are NULL. IDs and school_year are text. All columns are required except assessment score/performance_level and the three survey item ratings.

## schools.csv

One row per school. Fictional Cedar Valley Unified; no geographic mapping to real places.

| Column | PostgreSQL type |
|---|---|
| school_id | text |
| school_name | text |
| school_level | text |
| capacity | integer |

## students.csv

One row per student; exactly 20,000 unique fictional people. Aliases are identifiers, not names.

| Column | PostgreSQL type |
|---|---|
| student_id | text |
| student_alias | text |
| gender | text |
| race_ethnicity | text |
| home_language | text |

## school_years.csv

One row per year; fictional 180-day calendar, September through May, 20 membership days per month.

| Column | PostgreSQL type |
|---|---|
| school_year | text |
| start_date | date |
| end_date | date |
| instructional_days | integer |

## enrollment.csv

One row per student per year, full-year enrollment. Grade 0 = kindergarten. Flags are annual snapshots.

| Column | PostgreSQL type |
|---|---|
| student_id | text |
| school_year | text |
| school_id | text |
| grade_level | integer |
| economic_disadvantage | boolean |
| english_learner | boolean |
| iep | boolean |
| prior_year_transfer | boolean |

## attendance_monthly.csv

One row per enrolled student per month. Present + both absence types = membership. Tardy is a subset of present days.

| Column | PostgreSQL type |
|---|---|
| student_id | text |
| school_year | text |
| month_start | date |
| membership_days | integer |
| present_days | integer |
| excused_absent_days | integer |
| unexcused_absent_days | integer |
| tardy_days | integer |

## assessments.csv

One row per student/year/subject/window for grades 3–8 and 11. Fall and Spring, Math and Reading. Missing score means not tested; performance level also blank. Fictional common 200–800 scale; not a state exam.

| Column | PostgreSQL type |
|---|---|
| assessment_id | text |
| student_id | text |
| school_year | text |
| subject | text |
| window | text |
| score | integer |
| performance_level | text |

## course_grades.csv

One row per student/year/subject/semester for grades 6–12; four subjects, two semesters. Pass = 60%. Half credit per course in grades 9–12, zero credits in grades 6–8. Not a complete transcript or graduation audit.

| Column | PostgreSQL type |
|---|---|
| student_id | text |
| school_year | text |
| subject | text |
| semester | integer |
| percent_grade | numeric |
| credits_attempted | numeric |
| credits_earned | numeric |

## interventions.csv

Zero or one program per student/year. Selection depends on simulated need; no causal effect is imposed or identifiable.

| Column | PostgreSQL type |
|---|---|
| intervention_id | text |
| student_id | text |
| school_year | text |
| intervention_type | text |
| start_date | date |
| end_date | date |
| planned_sessions | integer |
| attended_sessions | integer |
| cost | numeric |

## discipline_incidents.csv

One row per student incident; zero to two per student/year. Suspension days are response days, not attendance absences, and are not additive with absence days.

| Column | PostgreSQL type |
|---|---|
| incident_id | text |
| student_id | text |
| school_year | text |
| incident_date | date |
| incident_category | text |
| response | text |
| suspension_days | integer |

## staffing.csv

One row per school/year/role; FTE can be fractional. Salary plus benefits is included in finance Instruction and Student support, not additive to finance totals.

| Column | PostgreSQL type |
|---|---|
| school_id | text |
| school_year | text |
| staff_role | text |
| fte | numeric |
| salary_benefits | numeric |

## finance.csv

One row per school/year/category; nominal dollars. School-level operating costs only; excludes capital, debt, and central office. Annual enrollments are denominators, not student-year sums.

| Column | PostgreSQL type |
|---|---|
| school_id | text |
| school_year | text |
| category | text |
| budget | numeric |
| actual | numeric |

## survey_responses.csv

One row per responding student/year, grades 4–12. Voluntary biased response (~72%); blanks within responses mean skipped items. Ratings 1–5; higher is favorable.

| Column | PostgreSQL type |
|---|---|
| response_id | text |
| student_id | text |
| school_year | text |
| belonging | integer |
| safety | integer |
| adult_support | integer |
