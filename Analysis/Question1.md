# Question 1: Primary keys, foreign keys, and analytical grain

## Project 1: **Build a trustworthy district analytical layer**

**Board question:** Can we trust the numbers presented at meetings?

**Use:** All files; begin with students, enrollment, and attendance. SQL difficulty: introductory to intermediate.

- Load the CSVs with the supplied schema. Explain primary keys, foreign keys, and the difference between a student, student-year, and student-month.
- Write SQL checks for 20,000 students, 60,000 enrollment rows, 180 membership days per student-year, and no orphan records. Extend the supplied validator with an independently written reconciliation query.
- Deliberately demonstrate row multiplication by joining attendance and grades for a single student-year; then fix it by aggregating each table first.
- In Excel, use Power Query to group attendance by student/year and reconcile annual headcounts and total absences against SQL.

**Deliver:** A documented SQL model, an Excel reconciliation workbook, and a one-page data quality scorecard.

**Acceptance:** Counts reconcile exactly; student-year measures are not repeated; NULL scores remain distinguishable from zero; the cohort limitation is visible. Include one failure example and the corrective control.

Dataset: SchoolDistrictInfo — entirely synthetic student and district records.

## What one row represents

The **grain** of a table describes what one row represents. Establishing the grain helps determine the correct key, join conditions, and interpretation of counts.

| Grain | Meaning | Example table | Primary key |
|---|---|---|---|
| Student | One individual across the dataset | `students` | `student_id` |
| Student-year | One student's enrollment for a particular school year | `enrollment` | `student_id, school_year` |
| Student-month | One student's attendance for a particular month within a school year | `attendance_monthly` | `student_id, school_year, month_start` |

These grains describe the level of detail; they do not necessarily measure progress. Enrollment describes annual enrollment status, while attendance describes days present and absent. Progress requires comparing appropriate measures across time.

In this dataset, each student has one student record, three annual enrollment records, and 27 monthly attendance records: nine months per year for three years. Grade level 0 represents kindergarten.

## Primary keys: uniquely identifying records

A **primary key** uniquely identifies each row and cannot contain NULL values. A key consisting of multiple columns is a **composite primary key**.

- In `students`, `student_id` identifies an individual across all school years.
- In `schools`, `school_id` identifies a school.
- In `school_years`, `school_year` identifies an academic year.
- In `enrollment`, the combination of `student_id` and `school_year` identifies an annual enrollment. The same student may appear in different years, but cannot have two enrollment rows for the same year.
- In `attendance_monthly`, `student_id`, `school_year`, and `month_start` identify a monthly attendance record. Multiple months can belong to the same student-year, but the same month cannot appear twice for that student-year.

For example, `S000001` alone is not a unique enrollment key because that student appears in three years. The pair `S000001` and `2023-24` identifies one enrollment record.

## Foreign keys: enforcing valid relationships

A **foreign key** requires a value, or combination of values, to match an existing referenced key. This enforces referential integrity and prevents orphan records.

| Referencing table | Foreign-key column(s) | Referenced table and key | What it establishes |
|---|---|---|---|
| `enrollment` | `student_id` | `students(student_id)` | The enrolled student exists |
| `enrollment` | `school_id` | `schools(school_id)` | The assigned school exists |
| `enrollment` | `school_year` | `school_years(school_year)` | The academic year exists |
| `attendance_monthly` | `student_id, school_year` | `enrollment(student_id, school_year)` | The attendance belongs to an enrolled student in that year |
| `course_grades` | `student_id, school_year` | `enrollment(student_id, school_year)` | The course record belongs to an enrolled student in that year |
| `assessments` | `student_id, school_year` | `enrollment(student_id, school_year)` | The test record belongs to an enrolled student in that year |

Interventions, discipline incidents, and survey responses also reference enrollment through the student-year combination.

A foreign key on `student_id` alone would establish that the student exists, but would not establish that the student has enrollment for the specified year. The composite relationship is therefore important for annual facts.

Foreign keys alone do not prove that every expected record exists or that every value is reasonable. For example, they cannot establish that each enrollment has nine months of attendance or 180 membership days. Those requirements need additional validation queries and business rules.

## Correct joins require the full relationship

Joining enrollment to attendance on `student_id` alone would match each annual enrollment to that student's attendance from all three years. The join must include the school year:

```sql
SELECT
    e.student_id,
    e.school_year,
    e.school_id,
    a.month_start,
    a.present_days
FROM enrollment e
JOIN attendance_monthly a
    ON e.student_id = a.student_id
   AND e.school_year = a.school_year;
```

The result is still at **student-month grain**: each annual enrollment matches nine monthly attendance records. Counting rows here counts monthly records, not annual enrollments or unique individuals.

Correct keys prevent incorrect matches; they do not automatically prevent repeated annual measures.

## Aggregate before combining multiple fact tables

Attendance and course grades both contain multiple rows per student-year. Joining them directly creates every matching attendance-month/course-semester combination. That repeats attendance once for every course-grade record and repeats course grades once for every month.

In this dataset, a student-year with nine attendance rows and eight course-grade rows would produce **72 joined rows**, even with the correct student-year join conditions.

The analytical layer avoids this by:

1. Summarizing attendance to one row per student-year.
2. Summarizing grades to one row per student-year.
3. Summarizing discipline to one row per student-year.
4. Joining those summaries to enrollment and student demographics.

This is the approach used by `student_year_metrics` in `sql/03_analytics_views.sql`. Its intended grain is **one student, one school year, one row**.

A regular view is a saved query, not a separate stored table with its own primary-key constraint. The view's intended uniqueness follows from the source constraints and query design and should be verified through reconciliation checks.

## Suggested validation evidence

The following queries are checks to run and document; their results are not recorded here as completed findings.

### Confirm expected record counts

```sql
SELECT
    (SELECT COUNT(*) FROM students) AS student_rows,
    (SELECT COUNT(*) FROM enrollment) AS student_year_rows,
    (SELECT COUNT(*) FROM attendance_monthly) AS student_month_rows,
    (SELECT COUNT(*) FROM student_year_metrics) AS analytical_student_year_rows;
```

Expected counts: **20,000**, **60,000**, **540,000**, and **60,000**, respectively.

### Confirm that the analytical view has no duplicate student-years

```sql
SELECT
    student_id,
    school_year,
    COUNT(*) AS row_count
FROM student_year_metrics
GROUP BY student_id, school_year
HAVING COUNT(*) > 1;
```

Expected result: **zero rows**. Any returned row would violate the view's intended grain.

### Confirm that every enrollment appears in the analytical view

```sql
SELECT
    e.student_id,
    e.school_year
FROM enrollment e
LEFT JOIN student_year_metrics m
    ON e.student_id = m.student_id
   AND e.school_year = m.school_year
WHERE m.student_id IS NULL;
```

Expected result: **zero rows**. This is important because the view uses an inner join to its annual attendance summary; a missing attendance summary would exclude the enrollment from the view.

## Project explanation

The district analytical layer uses primary keys to establish record identity and foreign keys to enforce valid relationships. Composite student-year keys preserve the correct relationship across school years. Each fact table is summarized to the intended reporting grain before it is combined with other facts, preventing row multiplication and inflated totals. Counts, uniqueness checks, coverage checks, and reconciled measures provide evidence that the analytical layer is trustworthy.


## Demonstrate incorrect joins

A good demonstration is to compare the original totals, the incorrect joined totals, and the corrected totals for the same student-year.

 ## Step 1: Choose a student-year with course grades
This finds a high school student-year:

```sql
SELECT student_id, school_year, grade_level
FROM enrollment
WHERE grade_level >= 9
ORDER BY student_id, school_year
LIMIT 1;
```

Use the returned student ID and year in the queries below, replacing 'YOUR_STUDENT_ID' and 'YOUR_SCHOOL_YEAR'.

Values: S000008 and 2025-26

## Step 2: Establish the correct totals separately
First, examine attendance:

```sql
SELECT
    COUNT(*) AS attendance_rows,
    SUM(membership_days) AS membership_days,
    SUM(present_days) AS present_days
FROM attendance_monthly
WHERE student_id = 'S000008'
  AND school_year = '2025-26';
  ```
We find  9 attendance rows and 180 membership days.

Then examine grades:
```sql
SELECT
    COUNT(*) AS course_grade_rows,
    SUM(credits_attempted) AS credits_attempted,
    SUM(credits_earned) AS credits_earned
FROM course_grades
WHERE student_id = 'S000008'
  AND school_year = '2025-26';
```

We find 8 course-grade rows and 4.0 attempted credits. Earned credits depend on passing grades.

Deliberately create the incorrect join:

This document contains steps 3 and 4 of the row-multiplication exercise. Run the SQL in pgAdmin's **Query Tool** against `schooldistrictinfo`.

Before running the queries, replace every occurrence of `'YOUR_STUDENT_ID'` and `'YOUR_SCHOOL_YEAR'` with the same student-year from enrollment. Choose a student in grades 9–12 so the credit measures are populated. Keep the quotation marks around both values.

This dataset is entirely synthetic. The expected results below describe the exercise; record your own query results as evidence.

## Step 3: Deliberately create the incorrect join

The following query joins monthly attendance directly to subject-semester grades for a single student-year:

```sql
SELECT
    COUNT(*) AS joined_rows,
    SUM(a.membership_days) AS membership_days,
    SUM(a.present_days) AS present_days,
    SUM(g.credits_attempted) AS credits_attempted,
    SUM(g.credits_earned) AS credits_earned
FROM attendance_monthly a
JOIN course_grades g
    ON a.student_id = g.student_id
   AND a.school_year = g.school_year
WHERE a.student_id = 'S000008'
  AND a.school_year = '2025-26';
```

### Why the totals are incorrect

Although the join uses the correct student and school year, both tables contain multiple rows at that grain. Every attendance month matches every course-grade record for that student-year.

```text
9 attendance rows × 8 course-grade rows = 72 joined rows
```

Each attendance value repeats eight times, while each course-grade value repeats nine times.

| Measure | Correct source total | Incorrect joined total |
|---|---:|---:|
| Membership days | 180 | 1,440 |
| Credits attempted | 4.0 | 36.0 |

Present days are also inflated eightfold. Earned credits are inflated ninefold; if the original earned total is zero, it remains zero, which can hide the multiplication.

### Inspect the repeated combinations

Run this query to see the individual joined rows:

```sql
SELECT
    a.month_start,
    a.membership_days,
    g.subject,
    g.semester,
    g.credits_attempted
FROM attendance_monthly a
JOIN course_grades g
    ON a.student_id = g.student_id
   AND a.school_year = g.school_year
WHERE a.student_id = 'S000008'
  AND a.school_year = '2025-26'
ORDER BY a.month_start, g.subject, g.semester;
```

Each month should appear eight times: once for each of four subjects in each of two semesters.

## Step 4: Aggregate each table before joining

Use two common table expressions (CTEs) to summarize attendance and grades separately. Each CTE produces one row per student-year. Joining those summaries then matches one row to one row.

```sql
WITH annual_attendance AS (
    SELECT
        student_id,
        school_year,
        SUM(membership_days) AS membership_days,
        SUM(present_days) AS present_days
    FROM attendance_monthly
    WHERE student_id = 'S000008'
      AND school_year = '2025-26'
    GROUP BY student_id, school_year
),
annual_grades AS (
    SELECT
        student_id,
        school_year,
        COUNT(*) AS course_grade_rows,
        SUM(credits_attempted) AS credits_attempted,
        SUM(credits_earned) AS credits_earned
    FROM course_grades
    WHERE student_id = 'S000008'
      AND school_year = '2025-26'
    GROUP BY student_id, school_year
)
SELECT
    a.student_id,
    a.school_year,
    a.membership_days,
    a.present_days,
    g.course_grade_rows,
    g.credits_attempted,
    g.credits_earned
FROM annual_attendance a
JOIN annual_grades g
    ON a.student_id = g.student_id
   AND a.school_year = g.school_year;
```

### Expected result

The query returns one row for the selected student-year, with:

- **180 membership days**.
- **8 course-grade records**, counted inside the grade summary before joining.
- **4.0 attempted credits**.
- Present days and earned credits matching their original, separately calculated source totals.

This example uses an inner join because the selected student-year has both attendance and grades. A district-wide model should consider a left join from enrollment or attendance when students without course-grade records must remain in the output.

### Suggested explanation for your analysis

> Joining two tables with multiple records per student-year multiplied the matching rows and inflated summed measures. Aggregating each table to student-year grain before joining preserved the original totals. I checked the joined results against independently calculated attendance and grade totals for the same student-year.

Use the final sentence only after completing those reconciliation checks.

An attendance percentage can still look correct in the incorrect join because present days and membership days are inflated by the same factor. Therefore, validate row counts and additive totals as well as percentages. Using `SUM(DISTINCT membership_days)` is not a valid fix: it would collapse repeated legitimate values, such as nine months that each have 20 membership days.
