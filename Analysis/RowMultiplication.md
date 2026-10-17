# Demonstrating and fixing row multiplication

Project: **Build a trustworthy district analytical layer**

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
WHERE a.student_id = 'YOUR_STUDENT_ID'
  AND a.school_year = 'YOUR_SCHOOL_YEAR';
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
WHERE a.student_id = 'YOUR_STUDENT_ID'
  AND a.school_year = 'YOUR_SCHOOL_YEAR'
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
    WHERE student_id = 'YOUR_STUDENT_ID'
      AND school_year = 'YOUR_SCHOOL_YEAR'
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
    WHERE student_id = 'YOUR_STUDENT_ID'
      AND school_year = 'YOUR_SCHOOL_YEAR'
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
