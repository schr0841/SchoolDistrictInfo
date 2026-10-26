# Project 5: Student Support Program Metric Definitions

**Synthetic demonstration — not an actual district.**

**Board question:** How consistently are support programs delivered, and what should we study next?

## Scope and grain

These definitions cover Part 1: program participation, session delivery, and recorded cost. The source is `public.interventions`. Each summary row represents one intervention type (program) in one school year. No joins to attendance, grades, enrollment, or assessments are needed for these delivery measures.

The supplied schema permits one intervention record per student per school year. A record represents assignment to a program; it does not by itself establish attendance or benefit.

## Metric definitions

| Metric / SQL output | Definition | Interpretation |
|---|---|---|
| Intervention records (`intervention_records`) | Count of intervention records in the program/year. | Should equal participant count under the supplied one-record-per-student/year constraint. |
| Participants (`participants`) | Distinct students with an intervention record in the program/year. | Includes students who attended zero sessions. This is a recorded-participant count, not a count of all students eligible for support. |
| Participants attending at least one session (`participants_attending_at_least_one_session`) | Distinct recorded students whose `attended_sessions > 0`. | Separates actual attendance from program assignment. |
| Participants with zero attendance (`participants_with_zero_attendance`) | Distinct recorded students whose `attended_sessions = 0`. | Report explicitly rather than excluding these students. |
| Planned sessions (`planned_sessions`) | Sum of `planned_sessions` across intervention records. | Planned student-session opportunities; not necessarily unique group meetings. |
| Attended sessions (`attended_sessions`) | Sum of `attended_sessions` across intervention records. | Attended student-sessions; a group meeting attended by multiple students can contribute multiple student-sessions. |
| Unattended planned sessions (`unattended_planned_sessions`) | Sum of `planned_sessions - attended_sessions`. | The data do not explain whether a session was missed by a student, cancelled, or otherwise not delivered. |
| Session completion rate (`session_completion_rate`) | Total attended sessions divided by total planned sessions. | A delivery measure, not evidence of successful program completion or student improvement. |
| Total recorded cost (`total_recorded_cost`) | Sum of `cost` for every intervention record in the program/year. | Includes costs for zero-attendance records. The supplied costs are not established as a complete district program budget. |
| Cost per attended session (`cost_per_attended_session`) | Total recorded cost divided by total attended sessions. | Return NULL when the program/year has zero attended sessions. A lower cost does not establish greater effectiveness. |

## Calculation rules

Use ratios of totals, rather than averages of individual students' ratios:

```sql
-- Session completion: stored as a fraction, displayed as a percentage.
SUM(attended_sessions)::numeric / NULLIF(SUM(planned_sessions), 0)

-- Cost per attended session: stored and displayed as currency.
SUM(cost) / NULLIF(SUM(attended_sessions), 0)
```

`NULLIF(denominator, 0)` converts a zero denominator to NULL and prevents division by zero. A NULL cost per attended session means the ratio is undefined; it does not mean zero cost. Do not replace it with zero in SQL, Excel, or Tableau.

The summary SQL rounds session completion to four decimal places and monetary measures to two decimal places. For presentation, a completion value of `0.8235` is **82.35%**. Preserve unrounded values when further precision is needed.

## Illustrative example

For a hypothetical program/year with 200 planned student-sessions, 150 attended student-sessions, and $6,000 in recorded costs:

- Session completion rate: 150 / 200 = **75%**.
- Unattended planned sessions: 200 - 150 = **50**.
- Cost per attended session: $6,000 / 150 = **$40**.

If attended sessions were zero, cost per attended session would be **NULL**, even if recorded cost were positive. These are illustrative numbers, not findings from the dataset.

## Validation checks

- Participants with at least one attended session plus participants with zero attendance equals total participants.
- Attended sessions do not exceed planned sessions.
- Attended sessions plus unattended planned sessions equals planned sessions.
- Session completion is between 0 and 1 before percentage formatting.
- Intervention record count equals participant count within program/year under the supplied schema.
- Cost per attended session is NULL when total attended sessions is zero.

## Interpretation and limits

No intervention record means no recorded participation; it does not prove that the student was ineligible for support or received no other services. These measures do not calculate a participation rate among eligible students, because an eligibility denominator has not been defined.

Unique students across multiple school years must be counted distinctly across those years; summing annual participant counts produces student-years rather than a unique multi-year student count.

These metrics describe program reach and delivery. They do not establish causal effects on attendance, grades, or assessment scores. Differences in student needs, program selection, scheduling, and costs require further investigation.

## Suggested findings statement

> In [year], [program] had [N] recorded participants, including [N] who attended no sessions. Students attended [A] of [P] planned sessions, a session completion rate of [X%]. Total recorded cost was [$C], equivalent to [$D] per attended session. These figures describe program delivery; they do not establish program effectiveness.

Targeted selection:	Students may receive support because they have greater needs. Same grade and prior-absence category do not ensure equal prior academic achievement or referral reasons.

Regression to the mean:	Students selected after an unusually poor result may later show less extreme results even without an intervention. Improvement alone does not establish an effect.

Unobserved confounding:	Family support, health, motivation, referrals, staffing, scheduling, and other services may influence both participation and outcomes. These factors are not adequately captured here.