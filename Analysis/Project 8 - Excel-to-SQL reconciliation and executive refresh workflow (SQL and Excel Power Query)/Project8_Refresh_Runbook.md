# Project 8: Simulated Refresh Runbook and Evidence Log

**Synthetic demonstration — not an actual district.**

## Purpose and current status

Demonstrate a repeatable reporting refresh: file arrival, validation, database load, model refresh, dashboard checks, publication review, and rollback. This document is a procedure/template, not evidence that a refresh has been executed. Fill in observed results and attach evidence. Use Not run for unperformed stages.

The supplied data is a closed three-year snapshot, not a live monthly feed. Re-delivering the same snapshot tests repeatability; it is not new student activity. A deliberately broken copy tests failure handling. Real monthly reporting would require a defined as-of period, arrival contract, append/update rules, and different completeness checks.

## Run identifiers and folders

Suggested run ID: RefreshDemo_20261030 (change if reused).

Under the existing Project 8 folder, create:

- RefreshDemo_20261030/Previous — last accepted workbook, reports, SQL control/exception exports, and source/version information.
- RefreshDemo_20261030/Incoming — untouched copies of the delivered data folder (all CSVs plus manifest.json), sql, scripts, and docs folders.
- RefreshDemo_20261030/Working — a copy of those Incoming folders for validation/loading; the source folder is Working/data.
- RefreshDemo_20261030/Candidate — workbook and reports being refreshed/reviewed.
- RefreshDemo_20261030/Evidence — validation reports, SQL results, refresh log, screenshots, and failure drill evidence.
- RefreshDemo_20261030/FailureTest — disposable copy of Working/data for a controlled Power Query failure test.

Keep original repository data and current database intact. Copy folders with File Explorer; do not regenerate data or use a destructive reload of the accepted database. Do not copy Git metadata or the entire Analysis folder recursively into these run folders.

## Stage 1: File arrival

1. Record run ID, received time, source release/manifest, file list, and intended reporting scope.
2. Copy the delivered snapshot into Incoming and preserve it unchanged.
3. Copy Incoming's data/sql/scripts/docs folders into Working.
4. Save the last accepted Excel workbook and reports under Previous, including the source folder and database they used.
5. Save a copy of the workbook under Candidate. Only the Candidate copy is edited during rehearsal.

Gate: every expected file is present; the run is identifiable and the previous accepted version is recoverable.

## Stage 2: Validate files

From a PowerShell terminal located in the Working folder, run:

```powershell
python scripts/validate_data.py
```

Use an available Python 3.10+ installation. The validator uses the standard library. Do not run generate_data.py: that would regenerate rather than validate the delivered snapshot.

The validator checks manifest hashes/counts, schema, keys, references, domain constraints, attendance completeness, and other cross-file rules. It also calls build_sql.py and writes generated SQL and docs/VALIDATION_REPORT.json, which is why Working is separate from Incoming and the original repository.

Save its output/report in Evidence. Confirm this RUN succeeded rather than treating a leftover report file as current evidence. The Python validator uses SQLite; it does not confirm PostgreSQL execution.

Separately review intentional missing scores and survey skips using the Part 3 exception definitions. They remain NULL and are not automatically treated as failed referential integrity.

Gate: no unexplained structural/key/type failures; expected missingness is documented. On failure, stop and retain the previous accepted report.

## Stage 3: Load an isolated PostgreSQL candidate database

Create a NEW empty database in pgAdmin, for example schooldistrictinfo_refresh_test_20261030. If the name already exists, choose a new run-specific name. Keep schooldistrictinfo unchanged.

Open PowerShell in Working (the folder containing data, sql, scripts, docs). Run these commands ONE AT A TIME, stopping if any command fails:

```powershell
psql -X -h localhost -U postgres -v ON_ERROR_STOP=1 -d schooldistrictinfo_refresh_test_20261030 -f sql/01_schema.sql
psql -X -h localhost -U postgres -v ON_ERROR_STOP=1 -d schooldistrictinfo_refresh_test_20261030 -f sql/02_load.sql
psql -X -h localhost -U postgres -v ON_ERROR_STOP=1 -d schooldistrictinfo_refresh_test_20261030 -f sql/03_analytics_views.sql
psql -X -h localhost -U postgres -v ON_ERROR_STOP=1 -d schooldistrictinfo_refresh_test_20261030 -f sql/05_validation.sql
```

Use your actual database account if different. Supply the password only in the password prompt, not in the run log. If psql is not on PATH, use its installed executable's full path, preceded by & in PowerShell.

02_load.sql contains client-side psql backslash commands (including backslash-copy). It must run with psql rather than pgAdmin Query Tool. Relative data paths resolve from Working. The load uses BEGIN/COMMIT and stops on errors. It loads a complete snapshot; do not append it to populated accepted tables.

Run your Part 2 control SQL in the test database. Create the Part 3 exception view there by running Section 1 of Project8_Missingness_Exceptions.sql, then run the detail, summary, and integrity checks. These project-specific views are not created by the original base view script. Export new SQL controls and exception CSVs for this run and record the test database name.

Gate: all PostgreSQL assertions pass, controls match this delivery, and orphan checks are zero. Preserve error output and stop if a stage fails. Existing fixed dataset counts are appropriate only for this unchanged synthetic-snapshot exercise.

## Stage 4: Refresh the Candidate model/workbook

1. Open the Candidate workbook, not the Previous/original workbook.
2. Edit pDataFolder to Working/data's absolute path.
3. Point SQL-control and exception import queries at THIS run's newly exported CSVs. pDataFolder alone changes attendance imports, not necessarily those separate export connections.
4. Data > Refresh All. Wait for every Power Query load to finish; inspect Queries & Connections for errors.
5. Refresh the annual and exception PivotTables AFTER query loads finish.
6. Reconcile Excel versus test-database controls for the same school years/snapshot. Missing inputs do not count as PASS.
7. Save the Candidate workbook and record actual refresh completion.

Views recalculate when queried; they are not materialized views requiring REFRESH. Excel does not reload PostgreSQL merely by refreshing its CSV query. Export-based reports require regeneration of the SQL export before Excel refresh.

Gate: query refresh succeeded, annual row/distinct-key controls agree, membership/absence differences are zero, and exception summary counts match SQL.

## Stage 5: Dashboard/report checks

For Project 8, the Annual_Attendance report, reconciliation sheet, and exception summary are sufficient. You do not have to refresh every earlier Tableau project to complete this run.

Check school-year coverage, filter selections, totals/rates, denominator definitions, number formats, readable labels, and synthetic disclosure. Verify annual attendance = SUM(present)/SUM(membership); do not average student rates. Confirm 60000 student-years is not described as 60000 distinct people. Confirm NULL scores/items are not changed to zero.

If including a Tableau workbook, refresh its actual source/extract or replace its CSV with the reviewed run-specific export. Updating Excel alone does not update Tableau. Check filter scope, tooltips, missingness, and counts against the same SQL snapshot.

Gate: report is accurate and readable, scope/timing visible, default filters appropriate, and no unexplained differences.

## Stage 6: Publication review and simulated release

Record Reviewer, Review time, Evidence reviewed, Decision (Approved/Rejected/Pending), and limitations. For a solo portfolio, self-review is acceptable if labeled honestly; do not invent independent approval.

Review data checks, expected missingness, report version/snapshot, synthetic wording, and appropriate aggregate content. Do not include internal individual-detail pages in the board PDF. Review exported pages for clipping and wrong filters.

For this local/free-edition workflow, publication can mean saving the approved versioned workbook and PDF to an accepted deliverables location and updating a release log. No cloud publication or email is required. Do not label a pending Candidate as accepted. Until approved, the previous accepted report remains current.

Gate: all checks pass and review decision is recorded. Save accepted version without overwriting the only copy of the previous version.

## Stage 7: Rollback rehearsal

Rollback can be triggered by failed validation/load, mismatched totals, refresh failure, bad filters/labels, or rejected review. For a rejected pre-release candidate, retain the previous accepted report; after a release, revert the released artifact/source selection.

1. Mark the candidate Rejected/Withdrawn and record the reason/time. Keep evidence; do not silently delete it.
2. Open the Previous accepted workbook/report, or restore it to the accepted reporting location.
3. Confirm its source paths and database/source snapshot are the accepted previous versions. Reopening an old workbook connected to new data is NOT a full rollback.
4. If Tableau was included, restore its previous extract/export/connection as well.
5. Verify Previous control totals and version label. Record rollback verification.

The accepted database is unchanged in this rehearsal, so there is no destructive database restore to perform. Candidate test-database creation/loading and a switch between versioned workbook/report copies demonstrate the release pattern. If an actual accepted database is ever overwritten, a separately tested backup/restore procedure is needed.

## Controlled failure drill

1. Copy Working/data into FailureTest; keep originals and Working intact.
2. In FailureTest/attendance_monthly.csv ONLY, change header membership_days to membership_days_BROKEN using a text editor. Save the copy as CSV without Excel reformatting it.
3. In a disposable Candidate workbook copy, point pDataFolder to FailureTest.
4. Refresh. The explicit type/grouping steps reference membership_days and should fail with a missing-column error.
5. Capture the error in Evidence and mark refresh FAIL. Excel can retain previously loaded values after a query error; unchanged-looking totals do not prove a successful refresh. Do not publish this candidate or load this broken file into PostgreSQL.
6. Restore the candidate parameter to Working/data and refresh successfully. Verify controls and PivotTables again. Open Previous and verify its accepted results as the rollback/source-restoration rehearsal.
7. Record observed failure/recovery separately. Do not mark a step Performed if only discussed. This drill tests Excel validation/recovery; it does not demonstrate a PostgreSQL transaction rollback.

For the separate file-validation gate, the existing manifest would also detect a modified file. Do not edit hashes merely to make the deliberate bad copy pass.

## Refresh log template

Run ID: [fill in]
Reporting scope/as-of interpretation: [fill in]
Incoming snapshot/manifest: [fill in]
Previous accepted artifact/source: [fill in]
Candidate database: [fill in]
Candidate workbook: [fill in]

| Stage | Start/end | Result (PASS/FAIL/Not run) | Evidence | Notes/action |
|---|---|---|---|---|
| File arrival | | | | |
| File validation | | | | |
| Candidate database load | | | | |
| PostgreSQL validation/controls | | | | |
| SQL exports regenerated | | | | |
| Excel query/PivotTable refresh | | | | |
| Excel/SQL reconciliation | | | | |
| Dashboard/report checks | | | | |
| Publication review | | | | |
| Simulated release | | | | |
| Controlled bad-copy drill | | | | |
| Recovery / rollback verification | | | | |

Reviewer: [name; identify self-review if applicable]
Decision and time: [Approved/Rejected/Pending]
Limitations: [fill in]

## Final narrative template

> I rehearsed a full-snapshot refresh using a copied synthetic delivery and an isolated PostgreSQL database. I recorded file validation, database load, regenerated SQL controls/exceptions, Excel query and PivotTable refresh, reconciliation, and report review. [Actual results.] A deliberately altered COPY produced [observed error]. I rejected that candidate and verified recovery using [actual source/version restored]. [State any stages not performed.] The exercise demonstrates a refresh-control process for this fixed synthetic dataset, not a deployed monthly district reporting system.
