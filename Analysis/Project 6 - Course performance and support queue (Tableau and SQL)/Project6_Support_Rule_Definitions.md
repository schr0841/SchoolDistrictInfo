# Project 6: Hypothetical Counselor Check-in Rules

**Synthetic demonstration — not an actual district.**

## Purpose and scope

Identify student-years for a hypothetical counselor check-in using simple, explainable retrospective rules. This is not a validated prediction, diagnosis, measure of student character, or automatic action. Do not use the prototype for eligibility, discipline, or placement.

Population: students in current grades 6-12. Grain: one student/year. Source: `public.project6_student_year_courses`. Implementation: `Project6_Support_Rules.sql`, creating `public.project6_support_rules`.

## Thresholds

| Rule | Threshold | Rationale and definition |
|---|---|---|
| Annual absence | At least 18 absent days | Portfolio convention. Excused and unexcused absences both count. The supplied dataset has 180 membership days, so 18 days equals 10%. This fixed-day rule is not generally equivalent to a 10% rule for other membership lengths. |
| Observed course failure | At least 2 failed course-semesters | Portfolio convention for academic review. Each observed subject-semester grade below 60 counts once. Failing the same subject in both semesters counts twice. |
| Combined selection | Either rule is met | OR, not AND. Show each rule separately and count a student only once in the combined annual candidate count. |

The thresholds are examples for this portfolio, not district-approved rules or thresholds validated to predict need. SQL stores them in the single-row `thresholds` CTE: absence_threshold_days = 18; failure_threshold = 2; expected_membership_days = 180.

## Missingness and coverage

Every rule is TRUE (met), FALSE (evaluated and below threshold), or NULL (cannot determine).

- Absence: evaluate only when membership is 180 days and absence is observed and between 0 and membership days. Other cases require review. This completeness convention is specific to this synthetic annual dataset.
- Course failure: at least 2 observed failures meets the rule even with partial course records; the record-coverage issue remains visible.
- Fewer than 2 failures with the expected 8 course-semester records means the rule is not met.
- Missing or incomplete course records with fewer than 2 observed failures means the rule is unknown. Do not treat missing records as zero failures.
- A positive rule selects a hypothetical candidate even if the other rule is unknown. Retain the data-review flag.
- If neither rule is positive and at least one is unknown, selection is unresolved.
- If both rules are FALSE, the student is not selected by these rules. This does not establish absence of support needs.

Grades 6-8 have zero credits by design but still have percentage grades and can meet the course-failure rule. Credits are not used as a trigger. Four subjects are an incomplete transcript and do not establish graduation readiness.

## Boundary examples

Assume 180 valid membership days and all 8 course records unless stated otherwise.

| Annual absent days | Observed failed course-semesters | Absence rule | Failure rule | Result |
|---:|---:|---|---|---|
| 17 | 1 | FALSE | FALSE | Neither rule met |
| 18 | 1 | TRUE | FALSE | Candidate: absence |
| 17 | 2 | FALSE | TRUE | Candidate: failures |
| 18 | 2 | TRUE | TRUE | Candidate: both |
| 17 | NULL; no course records | FALSE | NULL | Unresolved; review data |
| 18 | NULL; no course records | TRUE | NULL | Candidate: absence; also review course data |
| 17 | 1; partial course records | FALSE | NULL | Unresolved; review coverage |
| 17 | 2; partial course records | FALSE | TRUE | Candidate: observed failures; review coverage |

## Workload and interpretation

For a single year, unique candidates = absence-rule count + failure-rule count - both-rule count. Do not add the two rule counts without subtracting overlap. Eligible students = unique candidates + neither-rule-met students + unresolved-selection students. Counts across multiple years represent student-years, not distinct students over time.

`students_with_unknown_rule` can overlap with the candidate count: one rule may be positive while another is unknown. Course coverage issues can also occur even when observed failures already meet the rule.

A counselor should check data quality, timing, existing supports, and student context before deciding whether a check-in would help. Do not label candidates as high risk or assume the rules establish a cause.

## Timing

Annual totals are retrospective and cannot be presented as a midyear alert. A real midyear version needs an explicit as-of date, only attendance and grades available by that date, coverage checks, appropriately reviewed thresholds, and a workable human-review process.

## Suggested reporting language

> Using hypothetical thresholds of at least 18 annual absent days or at least 2 failed course-semesters, [N] grade [G] students in [year] met at least one rule. [A] met the absence rule, [F] met the failure rule, and [B] met both. [U] additional students had unresolved selection because neither observed rule was met and at least one rule could not be evaluated. The results describe retrospective candidates for human review, not a validated prediction or an automatic decision.
