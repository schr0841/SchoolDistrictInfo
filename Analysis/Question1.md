# Question 1: Primary keys, foreign keys, and analytical grain

Project: **Build a trustworthy district analytical layer**

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
