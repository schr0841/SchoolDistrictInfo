# Project 8, Part 1: Refreshable Annual Attendance Workbook

**Synthetic demonstration — not an actual district.**

## Purpose

Read the attendance CSV from a configurable folder, set explicit types, aggregate to one student/year, and build an annual PivotTable. The workbook reads source files; it does not update PostgreSQL. SQL reconciliation and exception handling are later controls.

## Workbook and query structure

Save as `Project8_Attendance_Refresh.xlsx` in your repository's Project 8 folder. Use these sheets: Annual_Attendance (PivotTable), StudentYear (query output), and Data_Types (documentation).

Queries: `pDataFolder` (Text parameter); `Attendance_Monthly` (connection only); `Attendance_StudentYear` (worksheet table).

## Parameter

Excel > Data > Get Data > From Other Sources > Blank Query opens Power Query Editor. Home > Manage Parameters > New Parameter:

- Name: `pDataFolder`
- Type: Text
- Required: checked
- Suggested Values: Any value
- Current Value: `C:\Users\schre\GitHub\SchoolDistrictInfo\data`

Enter a folder path, not a file name, and do not add quotation marks in the parameter dialog. The M query tolerates a trailing slash.

## Monthly source query

Create/select a blank query. Home > Advanced Editor. Replace its contents with the text in `Project8_Attendance_Monthly.pq`; Done. Set the query name to `Attendance_Monthly` in Query Settings.

The `.pq` files are plain-text code snippets, not files you need to connect to as data. Open them in a text editor and paste their contents into Advanced Editor.

The Source reads pDataFolder plus the attendance CSV filename. The Types step specifies every raw column's type. Keep this query unfiltered so all school years remain available.

Home > Close & Load > Close & Load To > Only Create Connection. If unavailable: Close & Load, then in Excel Data > Queries & Connections, right-click Attendance_Monthly > Load To > Only Create Connection.

## Student-year query

In Excel Data > Queries & Connections, right-click Attendance_Monthly > Edit. In Power Query's left query list, right-click Attendance_Monthly > Reference. Rename the new query Attendance_StudentYear.

Home > Advanced Editor. Replace its contents with `Project8_Attendance_StudentYear.pq`; Done.

The annual query sums membership, present, excused absence, unexcused absence, total absence, and tardy days by student_id plus school_year. source_month_rows counts input rows for each student/year; it is not a distinct-month validation.

Close & Load To > Table > New Worksheet. Name the worksheet StudentYear. Click inside the loaded Excel table > Table Design > Table Name: `tblAttendanceStudentYear`.

Expected on the unmodified supplied dataset: 60,000 annual rows; 20,000 students each school year; 9 input month rows and 180 membership days per student/year. These are expectations to verify, not a record of an executed validation. Coverage and missing-value checks follow in Part 2. List.Sum ignores NULL values, so totals alone cannot prove completeness.

## Data types to document on Data_Types

| Query | Field | Power Query type | Reason |
|---|---|---|---|
| Parameter | pDataFolder | Text | Reusable source folder |
| Monthly and annual | student_id | Text | Identifier; preserve prefix/format |
| Monthly and annual | school_year | Text | Academic-year label, not a date or subtraction |
| Monthly only | month_start | Date | Month's ISO calendar date |
| Monthly and annual | membership_days | Whole Number | Enrolled instructional-day count |
| Monthly and annual | present_days | Whole Number | Present-day count |
| Monthly and annual | excused_absent_days | Whole Number | Excused absence-day count |
| Monthly and annual | unexcused_absent_days | Whole Number | Unexcused absence-day count |
| Monthly and annual | tardy_days | Whole Number | Tardy-day count; not additional absences |
| Annual only | absent_days | Whole Number | Excused plus unexcused absence days |
| Annual only | source_month_rows | Whole Number | Number of raw monthly rows contributing |
| PivotTable calculation | Attendance Rate | Numeric ratio, percentage display | Total present / total membership |

Power Query's Whole Number type is Int64.Type in M. Source decoding is UTF-8; type conversions use en-US. Preserve conversion errors for investigation rather than removing error rows or converting missing observations to zero.

## PivotTable

1. Click a cell in tblAttendanceStudentYear.
2. Insert > PivotTable > From Table/Range; use New Worksheet. Leave Add this data to the Data Model unchecked for this standard-PivotTable workflow.
3. Rename the worksheet Annual_Attendance.
4. Rows: school_year.
5. Values: student_id (Count), membership_days (Sum), present_days (Sum), absent_days (Sum). Optional: excused_absent_days and unexcused_absent_days as Sum.
6. Value Field Settings lets you choose Count or Sum and rename the student count to Students. Confirm numeric measures are SUM, not COUNT. Format day totals as whole numbers with separators.
7. Click inside the PivotTable > PivotTable Analyze > Fields, Items & Sets > Calculated Field. Name: Attendance Rate. Formula: `=present_days/membership_days`. Use Insert Field if needed. Add it to Values if it does not appear automatically.
8. Attendance Rate > Value Field Settings > Number Format > Percentage, two decimal places. The standard PivotTable calculated field uses sums of the two source fields. Do not average student attendance rates or sum percentages.
9. Explain that the PivotTable Grand Total student count represents 60,000 student-years, not 60,000 distinct individuals. There are 20,000 unique students across this closed three-year cohort. Turn off row grand totals if they could confuse the audience: Design > Grand Totals > Off for Rows and Columns.

The year-level count is valid because the annual query has one row per student/year. It is not a general distinct count of monthly records.

## Refresh and changing the path

Data > Refresh All. Wait until the Power Query load is complete in Queries & Connections. Then right-click the PivotTable > Refresh so it definitely reads the newly loaded table. A PivotTable refresh by itself does not necessarily reload the CSV. Do not claim a completed refresh while queries are still running.

To change the folder: edit a query to open Power Query Editor > Home > Manage Parameters > Edit Parameters > change pDataFolder > Close & Load. Refresh the query and then the PivotTable. The new folder must contain attendance_monthly.csv with the same schema.

No source-file changes are needed to finish this setup. A refresh with unchanged input should reproduce unchanged results; a controlled alternate-folder/changed-copy demonstration belongs in the later workflow exercise. Keep originals intact.

## Completion evidence

- Saved workbook with named source/annual queries and a folder parameter.
- Data_Types worksheet documenting explicit types and key definitions.
- Annual_Attendance PivotTable, sourced from the named Excel table.
- Successful query refresh followed by PivotTable refresh.
- Visible synthetic-data disclosure and cohort/grand-total explanation.

## Microsoft references

- https://support.microsoft.com/en-us/excel/create-a-parameter-query-power-query
- https://support.microsoft.com/en-us/excel/refresh-an-external-data-connection-in-excel
