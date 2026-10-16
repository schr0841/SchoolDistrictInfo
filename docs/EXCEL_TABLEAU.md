# Excel and Tableau working guide

## Excel / Power Query

1. Import via **Data > Get Data > From Text/CSV** or the equivalent in your Excel version. Use UTF-8 and comma separators. Transform before loading.
2. Set student_id, school_id, incident/program/assessment/response IDs, and school_year to Text. Set date columns to Date, counts to Whole Number, amounts and percentages to Decimal Number, and enrollment flags to True/False. Empty numeric fields must stay null.
3. For large facts, load as connection-only or into the Data Model. Each supplied file fits a worksheet; avoid expanding many-to-many joins into sheets.
4. Group attendance by student_id and school_year, summing membership and present/absence days. Add an annual key with `[student_id] & "|" & [school_year]` to both enrollment and grouped attendance. This supports Excel models that need single-column relationships.
5. Make a student-year PivotTable and compare it with SQL. Use SUM(present)/SUM(membership) for attendance. For chronic absence, first flag each student-year with annual absences/membership >=0.10, then sum flags / count student-years in the filtered year. Do not flag months and call it annual chronic absence.
6. Keep raw queries separate from transformation queries. Use a named folder parameter so a reviewer can refresh from their own clone.

## Tableau: easiest reliable path

Connect Tableau to PostgreSQL and use `school_year_metrics` for the executive dashboard, `student_year_metrics` for student-year analysis, and `assessment_growth` for paired growth. Keep distinct analyses in separate data sources until you deliberately define relationships. Tableau Public users can export the views to CSV locally with psql, then connect the CSVs.

Example exports from the repository root after loading SQL:

```shell
psql -X -d schooldistrictinfo -c "\copy (SELECT * FROM school_year_metrics) TO 'school_year_metrics.csv' WITH (FORMAT csv, HEADER true)"
psql -X -d schooldistrictinfo -c "\copy (SELECT * FROM student_year_metrics) TO 'student_year_metrics.csv' WITH (FORMAT csv, HEADER true)"
psql -X -d schooldistrictinfo -c "\copy (SELECT * FROM assessment_growth) TO 'assessment_growth.csv' WITH (FORMAT csv, HEADER true)"
```

Those exports are generated analysis outputs, not additional source files. Use only school-level aggregates for a public overview and label the dashboard synthetic.

## Tableau: raw CSV modeling exercise

Use enrollment as the central logical table. Relate students on student_id and schools on school_id. Relate attendance, assessments, grades, discipline, interventions, and survey responses on **student_id AND school_year**. Relate school_years on school_year. Use a separate school-year scaffold (all schools × all years) for finance and staffing to avoid repeating school costs for each student. Logical relationships preserve grains more safely than a single wide physical join, but every visualization still requires denominator checks. Do not declare all relationships one-to-one: most raw facts are one-to-many.

## Calculated fields

On the **school_year_metrics** source:

```text
// Weighted attendance; format as percentage
SUM([present_days]) / SUM([membership_days])

// Chronic absence rate; filter school_year to one year for annual headcount
SUM([chronically_absent_students]) / SUM([enrollment])

// Annual operating spending per student
SUM([actual]) / SUM([enrollment])

// Students per teacher FTE (not class size)
SUM([enrollment]) / SUM([teacher_fte])
```

On the **student_year_metrics** source:

```text
// Chronic absence count
SUM(IF [chronically_absent] THEN 1 ELSE 0 END)

// Annual chronic absence share, one row per student-year
SUM(IF [chronically_absent] THEN 1 ELSE 0 END) / COUNT([student_id])
```

On the **assessment_growth** source, use `AVG([growth_points])` with subject and grade filters and show `COUNT([student_id])` as paired N. A student appears in two subjects, so filter to a subject when interpreting the count as students. Missing pairs are absent from this view; use assessments separately to report test participation.

If building directly on monthly attendance, annual totals can use FIXED student_id, school_year expressions, but be explicit about Tableau's order of operations and context filters. A preaggregated annual view is easier to audit. Do not average annual FIXED values repeated across monthly rows without verifying weighting.

## Dashboard specification

- **Overview:** single-year selector, headcount, weighted attendance, chronic absence, spending per student, and annual trends.
- **Attendance:** within-level school comparison, monthly pattern, denominator tooltips, and threshold scenario.
- **Learning:** participation, spring proficiency, paired growth, and sample sizes.
- **Resources:** budget variance, teacher FTE ratio, capacity utilization, and assumptions.

Use direct labels, descriptive titles, a consistent percentage scale, and color plus text rather than red/green alone. Include a visible data/source note, fictional years, cohort limits, metric definitions, and synthetic-data banner. Do not combine monthly and annual filters in ways that silently redefine denominators.

## Reconciliation before sharing

- Each single-year enrollment total is 20,000; all-years student-year total is 60,000 while unique students remain 20,000.
- Each student's annual membership is 180; district annual membership is 3,600,000.
- Total budget and actual match finance without duplication; teacher FTE matches staffing after filtering Teacher.
- Proficiency denominator is valid scores in the selected subject/window/eligible grade, not total enrollment.
- Tableau totals match independently executed SQL at the exact same filters.
- Empty values display as missing; NULL is never silently converted to failure or zero.

The repository includes starting material, not a finished Excel workbook or Tableau workbook. Create these as your portfolio projects and commit the results when ready.
