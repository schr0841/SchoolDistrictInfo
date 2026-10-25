# SchoolDistrictInfo Data Quality Scorecard

Project 1 | Synthetic demonstration | School years 2023–24 through 2025–26

Reviewer: Greg | Review date: October 18, 2026 | Data snapshot: October 18, 2026

I completed all eight validation areas below using PostgreSQL checks and an independent Excel Power Query reconciliation. All checks passed, and no exceptions were identified within the scope of this review.

**Overall assessment: Verified and ready for the stated analysis.**

## Validation results

| Check | Acceptance criterion | Observed result and status | Evidence reference |
|---|---|---|---|
| Record counts | Students 20,000; enrollment 60,000; attendance 540,000; annual student view 60,000 | All four counts matched; PASS | Appendix check 1 |
| Student year uniqueness | No duplicate student-year groups in enrollment or the annual student view | 0 duplicate groups; PASS | Appendix check 2 |
| Referential integrity | No attendance rows without matching student-year enrollment | 0 orphan attendance records; PASS | Appendix check 3 |
| Attendance coverage | Nine months and 180 membership days for every enrolled student-year; every enrollment represented in the view | 0 coverage exceptions and 0 enrollments missing from the view; PASS | Appendix check 4 |
| Attendance balance | Present days plus excused and unexcused absence days equal membership days | 0 balance exceptions; PASS | Appendix check 5 |
| Join accuracy | Annual aggregation preserves source attendance and credit totals | 0 source-to-view differences; corrected join preserved source totals; PASS | Appendix check 6 and completed row-multiplication exercise |
| Excel and SQL agreement | Five annual measures across three years match exactly | All 15 comparisons matched; 0 differences; PASS | Appendix check 7; Attendance_Reconciliation.xlsx; SQL_Attendance_Benchmark.csv |
| Expected missing values | Untested scores remain NULL; performance levels and grade-summary eligibility are consistent | Expected missing values reviewed; 0 consistency or eligibility exceptions; PASS | Appendix checks 8a through 8c |

**Status:** All eight validation areas passed. Expected missing assessment scores and inapplicable grade summaries were retained and were not treated as errors or converted to zero.

## Scope and limitations

The fictional dataset follows a closed cohort with 20,000 students each year and a simplified 180-day calendar. This review verified the checks documented below. Matching annual totals does not establish that every individual Excel and SQL record is identical, and these results do not constitute a validation of real district data.

## Exceptions and next action

No exceptions or unresolved discrepancies were found in the completed checks. No corrective action is required for the reviewed snapshot. Rerun the validation queries and refresh the Excel reconciliation whenever source data or analytical views change; regenerate the SQL benchmark before comparing refreshed results.

## Evidence and conclusion

The SQL checks are retained in this document's appendix. The Excel reconciliation and SQL benchmark are stored in `Analysis/Attendance_Reconciliation.xlsx` and `Analysis/SQL_Attendance_Benchmark.csv`.

The checks confirmed the expected record counts, unique student-year grain, valid attendance-to-enrollment relationships, complete and balanced attendance records, preservation of source totals after aggregation and joining, and agreement between Excel and PostgreSQL annual summaries. The analytical layer is ready for the portfolio analyses supported by these checks, subject to the scope and limitations above.

## Appendix SQL validation checks

The following queries document the completed checks in order. All checks passed with no exceptions. To repeat the review, run them in pgAdmin's **Query Tool**, connected to `schooldistrictinfo`. They are read-only and do not reload data or recreate tables or views.

The eight numbered checks below correspond to the scorecard rows. Some checks contain multiple queries. The scorecard summary can remain a one-page report when exported separately; this appendix provides its supporting SQL.

### 1. Record counts

Count the source records and rows in the annual student view.

```sql
SELECT 'students' AS source, COUNT(*) AS actual_rows
FROM students

UNION ALL

SELECT 'enrollment', COUNT(*)
FROM enrollment

UNION ALL

SELECT 'attendance_monthly', COUNT(*)
FROM attendance_monthly

UNION ALL

SELECT 'student_year_metrics', COUNT(*)
FROM student_year_metrics;
```

**Expected:** `students` = 20,000; `enrollment` = 60,000; `attendance_monthly` = 540,000; `student_year_metrics` = 60,000. Match results by source name; the query does not specify a display order.

**Verified result:** All four observed record counts matched the expected values; PASS.

### 2. Student year uniqueness

Find duplicate student-year combinations in enrollment or the analytical view.

```sql
SELECT
    'enrollment' AS source,
    student_id,
    school_year,
    COUNT(*) AS row_count
FROM enrollment
GROUP BY student_id, school_year
HAVING COUNT(*) > 1

UNION ALL

SELECT
    'student_year_metrics',
    student_id,
    school_year,
    COUNT(*)
FROM student_year_metrics
GROUP BY student_id, school_year
HAVING COUNT(*) > 1;
```

**Expected:** Zero rows. `HAVING` retains only groups containing duplicates.

**Verified result:** 0 duplicate student-year groups in enrollment or the analytical view; PASS.

### 3. Referential integrity

Find attendance records without matching enrollment for the same student and school year.

```sql
SELECT
    a.student_id,
    a.school_year,
    a.month_start
FROM attendance_monthly a
LEFT JOIN enrollment e
    ON a.student_id = e.student_id
   AND a.school_year = e.school_year
WHERE e.student_id IS NULL;
```

**Expected:** Zero rows. A NULL enrollment ID indicates an unmatched attendance record.

**Verified result:** 0 orphan attendance records; PASS.

### 4. Attendance coverage

Check that every enrolled student-year has nine monthly attendance records and 180 membership days. Starting from enrollment also detects students with no attendance records.

```sql
SELECT
    e.student_id,
    e.school_year,
    COUNT(a.month_start) AS months_recorded,
    COALESCE(SUM(a.membership_days), 0) AS membership_days
FROM enrollment e
LEFT JOIN attendance_monthly a
    ON e.student_id = a.student_id
   AND e.school_year = a.school_year
GROUP BY e.student_id, e.school_year
HAVING COUNT(a.month_start) <> 9
    OR COALESCE(SUM(a.membership_days), 0) <> 180;
```

**Expected:** Zero rows.

Also confirm that every enrollment appears in the analytical view:

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

**Expected:** Zero rows. The view uses an inner join to attendance, so this check helps detect enrollment records excluded by missing annual attendance summaries.

**Verified result:** 0 student-year attendance coverage exceptions and 0 enrollments missing from the analytical view; PASS.

### 5. Attendance balance

Check that present days plus both absence categories equal membership days in every monthly record.

```sql
SELECT
    student_id,
    school_year,
    month_start,
    membership_days,
    present_days,
    excused_absent_days,
    unexcused_absent_days
FROM attendance_monthly
WHERE present_days
    + excused_absent_days
    + unexcused_absent_days <> membership_days;
```

**Expected:** Zero rows. The source schema requires these columns to be non-NULL.

**Verified result:** 0 attendance balance exceptions; PASS.

### 6. Join accuracy

Independently aggregate attendance and grades, then compare their measures against the analytical view for every enrolled student-year.

```sql
WITH attendance_source AS (
    SELECT
        student_id,
        school_year,
        SUM(membership_days) AS membership_days,
        SUM(present_days) AS present_days,
        SUM(
            excused_absent_days + unexcused_absent_days
        ) AS absent_days
    FROM attendance_monthly
    GROUP BY student_id, school_year
),
grades_source AS (
    SELECT
        student_id,
        school_year,
        SUM(credits_attempted) AS credits_attempted,
        SUM(credits_earned) AS credits_earned
    FROM course_grades
    GROUP BY student_id, school_year
)
SELECT
    e.student_id,
    e.school_year,
    a.membership_days AS source_membership_days,
    m.membership_days AS view_membership_days,
    a.present_days AS source_present_days,
    m.present_days AS view_present_days,
    a.absent_days AS source_absent_days,
    m.absent_days AS view_absent_days,
    g.credits_earned AS source_credits_earned,
    m.credits_earned AS view_credits_earned
FROM enrollment e
LEFT JOIN attendance_source a
    ON e.student_id = a.student_id
   AND e.school_year = a.school_year
LEFT JOIN grades_source g
    ON e.student_id = g.student_id
   AND e.school_year = g.school_year
LEFT JOIN student_year_metrics m
    ON e.student_id = m.student_id
   AND e.school_year = m.school_year
WHERE m.student_id IS NULL
   OR a.membership_days IS DISTINCT FROM m.membership_days
   OR a.present_days IS DISTINCT FROM m.present_days
   OR a.absent_days IS DISTINCT FROM m.absent_days
   OR g.credits_earned IS DISTINCT FROM m.credits_earned;
```

**Expected:** Zero rows. `IS DISTINCT FROM` detects mismatches even when one value is NULL and the other is not.

The view does not expose attempted credits, so the selected `credits_attempted` source aggregate is not compared here. Retain the separate row-multiplication demonstration to verify that the corrected join also preserves attempted credits: the high school example should return 4.0 attempted credits.

**Verified result:** 0 source-to-view attendance or earned-credit differences. The completed single-student row-multiplication exercise also confirmed that the corrected join preserved source totals; PASS.

### 7. Excel and SQL agreement

Calculate annual benchmarks directly from enrollment and monthly attendance.

```sql
WITH enrollment_totals AS (
    SELECT
        school_year,
        COUNT(*) AS enrolled_students
    FROM enrollment
    GROUP BY school_year
),
attendance_totals AS (
    SELECT
        school_year,
        COUNT(DISTINCT student_id) AS attendance_headcount,
        SUM(membership_days) AS membership_days,
        SUM(present_days) AS present_days,
        SUM(
            excused_absent_days + unexcused_absent_days
        ) AS absent_days
    FROM attendance_monthly
    GROUP BY school_year
)
SELECT
    COALESCE(e.school_year, a.school_year) AS school_year,
    e.enrolled_students,
    a.attendance_headcount,
    a.membership_days,
    a.present_days,
    a.absent_days
FROM enrollment_totals e
FULL OUTER JOIN attendance_totals a
    ON e.school_year = a.school_year
ORDER BY school_year;
```

Compare each of the five numeric measures against the corresponding Excel Power Query summary for the same year. Calculate **Excel value - SQL value** for each comparison.

**Expected:** Three school years and 15 comparisons, with every difference equal to zero. Annual enrollment and attendance headcounts should each be 20,000; annual membership days should be 3,600,000.

**Verified result:** All 15 Excel-versus-SQL comparisons matched with 0 differences; PASS. Supporting files: `Attendance_Reconciliation.xlsx` and `SQL_Attendance_Benchmark.csv`. The SQL query produces the benchmark; the comparison was completed in Excel.

### 8. Expected missing values

#### 8a. Describe missing assessment scores

```sql
SELECT
    school_year,
    COUNT(*) AS expected_assessment_records,
    COUNT(score) AS valid_scores,
    COUNT(*) - COUNT(score) AS missing_scores
FROM assessments
GROUP BY school_year
ORDER BY school_year;
```

`COUNT(score)` ignores NULL values. Missing scores are expected for untested students; their count does not need to be zero. This summary covers the expected assessment records in the source file, rather than independently establishing that every eligible student has every expected test record.

**Verified result:** Missing assessment scores were reviewed as expected missingness and retained as NULL. They were not classified as data-quality failures.

#### 8b. Check score and performance level consistency

```sql
SELECT
    assessment_id,
    student_id,
    school_year,
    score,
    performance_level
FROM assessments
WHERE (score IS NULL AND performance_level IS NOT NULL)
   OR (score IS NOT NULL AND performance_level IS NULL);
```

**Expected:** Zero rows. An untested assessment should have no performance level, while a tested assessment should have one.

#### 8c. Check grade summary eligibility

```sql
SELECT
    student_id,
    school_year,
    grade_level,
    mean_course_grade,
    credits_earned,
    failed_course_semesters
FROM student_year_metrics
WHERE
    (
        grade_level < 6
        AND (
            mean_course_grade IS NOT NULL
            OR credits_earned IS NOT NULL
            OR failed_course_semesters IS NOT NULL
        )
    )
    OR
    (
        grade_level >= 6
        AND (
            mean_course_grade IS NULL
            OR credits_earned IS NULL
            OR failed_course_semesters IS NULL
        )
    );
```

**Expected:** Zero rows.

- Grades K-5 have no course-grade records, so the view's grade summaries should be NULL.
- Grades 6-8 have course grades and zero credits.
- Grades 9-12 have course grades and credits based on passing.

**Verified result:** 0 score/performance-level consistency exceptions and 0 grade-summary eligibility exceptions; PASS.
