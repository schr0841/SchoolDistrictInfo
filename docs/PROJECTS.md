# School board analytics portfolio projects

Every deliverable must say **Synthetic demonstration — not an actual district**. Your audience needs a decision, its evidence, its limits, and the next action. You are demonstrating your analytical process, not claiming experience with an actual district.

## Recommended sequence

Complete projects 1, 2, and 3 first. Add 4 or 5 to show resource analysis, then package your strongest findings using project 9. Projects 6–8 show deeper judgment. A polished small portfolio is stronger than nine unfinished dashboards.

## 1. Build a trustworthy district analytical layer

**Board question:** Can we trust the numbers presented at meetings?

**Use:** All files; begin with students, enrollment, and attendance. SQL difficulty: introductory to intermediate.

- Load the CSVs with the supplied schema. Explain primary keys, foreign keys, and the difference between a student, student-year, and student-month.
- Write SQL checks for 20,000 students, 60,000 enrollment rows, 180 membership days per student-year, and no orphan records. Extend the supplied validator with an independently written reconciliation query.
- Deliberately demonstrate row multiplication by joining attendance and grades for a single student-year; then fix it by aggregating each table first.
- In Excel, use Power Query to group attendance by student/year and reconcile annual headcounts and total absences against SQL.

**Deliver:** A documented SQL model, an Excel reconciliation workbook, and a one-page data quality scorecard.

**Acceptance:** Counts reconcile exactly; student-year measures are not repeated; NULL scores remain distinguishable from zero; the cohort limitation is visible. Include one failure example and the corrective control.

## 2. Attendance and chronic absence dashboard

**Board question:** Where should attendance teams investigate first?

**Use:** `student_year_metrics`, schools; optionally attendance_monthly for seasonality. SQL difficulty: intermediate; Tableau: introductory.

- Define chronic absence as total annual absences divided by membership days >=10%. Excused and unexcused days both count in this exercise.
- Compute school-year rates and year-over-year **percentage-point** change with `LAG`. Keep numerators and denominators.
- Build a Tableau KPI strip, annual trend, school comparison within school level, and month heatmap. Show attendance and chronic absence as distinct measures.
- Add year, school level, and school filters. Tooltips should give the number of students, absence definition, and denominator.
- Use a parameter to compare the standard 10% definition to a hypothetical 15% threshold, labeling the latter as a scenario rather than a revised official rate.

**Deliver:** Dashboard plus a one-page memo proposing where staff should investigate, what additional evidence to collect, and how to measure progress.

**Acceptance:** District attendance is SUM(present)/SUM(membership), chronic absence uses one annual row per student, trend differences use percentage points, and seasonal counts account for membership. Do not interpret increased absence as proof of a specific family or school cause.

## 3. Academic growth and assessment participation

**Board question:** Are students progressing, and who is missing from our assessment picture?

**Use:** assessments, enrollment, schools, `assessment_growth`. SQL: conditional aggregation and matched joins; Tableau: intermediate.

- Calculate tested/expected counts, spring proficiency among valid tests, and fall-to-spring growth for matched student-subject pairs.
- Compare grades and school levels separately. Count missing tests explicitly; do not call missing scores nonproficient.
- Build a participation bar chart, proficiency trend, growth distribution, and paired sample-size tooltip. Show missingness alongside achievement rather than burying it.
- Compare paired growth with the difference between overall Fall and Spring means; explain why the results can differ.

**Deliver:** Two dashboard tabs and a metric-definition page.

**Acceptance:** Assessment eligibility is grades 3–8 and 11; subjects and windows are never pooled accidentally; paired N excludes missing scores at either window. State that the scale and thresholds are fictional and growth is not a validated student growth percentile.

## 4. Spending, staffing, and capacity planning

**Board question:** Which resource patterns merit a budget discussion?

**Use:** `school_year_metrics`, finance, staffing, schools. SQL: CTEs and ratios; Tableau: scatterplots and parameters.

- Reconcile total actual and budget amounts. Define favorable/unfavorable variance consistently: supplied variance = actual minus budget, so positive means over budget.
- Calculate school-year operating spending per enrolled student, students per teacher FTE, and capacity utilization. Compare schools within school levels.
- Build a budget variance chart, resource scatterplot sized by enrollment, and staffing table.
- Add a hypothetical teacher-FTE parameter: estimated additional salary/benefit cost = added FTE times an explicitly chosen assumption. Use the supplied staffing rates as a starting point, and state that funding capacity, fixed costs, and class scheduling require separate analysis.

**Deliver:** Budget discussion dashboard and assumptions sheet.

**Acceptance:** No duplication from joining budget categories to staff roles; staffing costs are not added to finance totals; district per-student costs use annual weighted denominators. Label simulated costs as nominal, partial operating expenses. Do not infer spending effectiveness from a scatterplot.

## 5. Student support program review

**Board question:** How consistently are support programs delivered, and what should we study next?

**Use:** interventions, attendance, course_grades, enrollment, assessments. SQL: intermediate to advanced; Tableau: cohort comparisons.

- Define participation, session completion, cost per attended session, and participant counts by program/year. Return NULL for cost per attended session when zero sessions were attended.
- Build a student-year table before linking outcomes. Compare attendance and matched assessment growth within similar grades and prior-year need categories.
- Use prior-year attendance when available as a baseline, distinguishing it from current-year program delivery and outcomes. Report that first-year participants lack observed prior-year data.
- Show program reach, delivery, costs, missing outcomes, and descriptive outcome differences. Discuss targeted selection, regression to the mean, and unobserved confounding.

**Deliver:** An operations dashboard and a design for a future evaluation, specifying comparison selection, timing, baseline measures, and additional data needed.

**Acceptance:** Describe associations only. Do not claim a program worked or failed from participant/nonparticipant averages. There is no imposed treatment effect in this simulation. The data support program operations review, not a causal impact estimate.

## 6. Course performance and an explainable support queue

**Board question:** Which students might benefit from a counselor check-in?

**Use:** course_grades and student_year_metrics, grades 6–12. SQL: aggregation, CASE, windows; Tableau: drill-through.

- Calculate failed course-semesters and observed credits earned. Distinguish no eligible course records from zero failures.
- Design transparent, hypothetical rules using absence and course failure, such as >=18 annual absence days or >=2 failed course-semesters. Show each rule separately and document thresholds.
- Create an internal synthetic-only detail page with aliases and reason flags plus an aggregate board view.
- Examine how many students each threshold selects and how counts vary by grade. Discuss workload, timing, and the need for human review.

**Deliver:** A transparent support workflow prototype and a threshold sensitivity worksheet.

**Acceptance:** Do not call the output a validated prediction or use it for eligibility, discipline, or placement. Annual totals are retrospective; a midyear alert would need date-limited features. Four subjects are an incomplete transcript, so observed credits cannot establish graduation readiness.

## 7. School climate, discipline, and reporting fairness

**Board question:** What do behavior and student voice tell us, and whose voices are missing?

**Use:** survey_responses, discipline_incidents, enrollment, students. SQL: distinct counts and NULL handling; Tableau: distributions and subgroup views.

- Separate incidents per 100 enrolled students from the percentage of students with any incident. Count unique students for the latter.
- Calculate survey participation among eligible grades 4–12, favorable response share (rating >=4) per item, and skipped-item rates.
- Compare patterns by grade and school level, then explore subgroup differences while displaying group sizes.
- Practice suppressing cells below 10 and explain how complementary suppression and filter restrictions may be needed to stop reconstruction from totals. Ten is a portfolio convention, not a claim about legal sufficiency.

**Deliver:** An aggregate climate dashboard with an interpretation and privacy note.

**Acceptance:** No student detail in a public dashboard; no averaged survey rating without response counts; no added suspension and absence days; discuss biased survey response and school reporting practices as alternative explanations.

## 8. Excel-to-SQL reconciliation and executive refresh workflow

**Board question:** Can this reporting be repeated each month without manual patchwork?

**Use:** CSVs, Power Query, PostgreSQL views. SQL: introductory; Excel: intermediate.

- Parameterize the local folder path in Power Query and document data types. Build a refreshable annual attendance PivotTable.
- Add control totals for row counts, unique student-year keys, total membership, and total absences. Reconcile against independent SQL queries.
- Create an exception table for missing tests and skipped survey items. Explain why those are expected missingness rather than referential-integrity failures.
- Document a simulated refresh: file arrival, validation, database load, model refresh, dashboard checks, publication review, and rollback to the previous version.

**Deliver:** Workbook, reconciliation log, and a runbook another analyst can follow.

**Acceptance:** Refresh works from a changed folder path; no manual edits to raw CSVs; filters and types survive refresh; checks detect a deliberately altered copy of a file. Keep the original validated dataset intact.

## 9. Capstone: five-minute school board briefing

**Board question:** What decisions would an analytics specialist help us make this quarter?

Combine projects 2–4 into a coherent narrative. Build your findings from your own queries rather than inventing results.

1. **Purpose:** Describe the fictional district, cohort limits, and the decisions being explored.
2. **Evidence:** Present three findings with baseline, current value, change, denominator, and chart. Add one sentence on data quality or missingness for each.
3. **Action:** Propose two practical investigations or pilot actions with an owner role, a timeline, a metric, and an explicitly hypothetical success threshold.
4. **Limits:** State what the data cannot establish, especially causality and complete district coverage.
5. **Follow-through:** Explain the reporting cadence, validation controls, and extra data you would request in a real district.

**Deliver:** A Tableau story or dashboard, a one-page board memo, and 4–6 presentation slides. Keep details in an appendix.

**Acceptance:** A board member can explain the decision in one sentence; each number traces to SQL; charts use readable labels and accessible colors; all pages identify the data as synthetic; no claim implies real district employment or outcomes.

## Portfolio review rubric

| Dimension | Strong evidence |
|---|---|
| Accuracy | Clear grain, correct joins, weighted rates, reconciled counts |
| Analytical judgment | Missingness, cohort changes, confounding, uncertainty addressed |
| Board relevance | A concrete decision and feasible follow-up accompany each finding |
| Communication | Plain-language titles, clear units, readable charts, definitions |
| Reproducibility | SQL, generator, validation, documented refresh procedure |
| Professional care | Synthetic disclosure, aggregate public reporting, no unsupported claims |

Suggested README wording for your completed portfolio: “I built a reproducible analytics workflow on a fictional 20,000-student cohort, reconciled source data, modeled PostgreSQL reporting views, and designed dashboards to support board-level discussions.” Add links to your actual work and replace general claims with verified examples.
