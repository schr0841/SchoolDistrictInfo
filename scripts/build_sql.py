"""Build SQL schema and psql client-side import commands from the data contract."""
from pathlib import Path
from generate_data import SCHEMAS
ROOT=Path(__file__).resolve().parents[1]
KEYS={
 'schools':'school_id','students':'student_id','school_years':'school_year',
 'enrollment':'student_id, school_year',
 'attendance_monthly':'student_id, school_year, month_start',
 'assessments':'assessment_id','course_grades':'student_id, school_year, subject, semester',
 'interventions':'intervention_id','discipline_incidents':'incident_id',
 'staffing':'school_id, school_year, staff_role','finance':'school_id, school_year, category',
 'survey_responses':'response_id'}
CHECKS={
 'schools':['capacity > 0'],
 'school_years':['end_date > start_date','instructional_days = 180'],
 'enrollment':['grade_level BETWEEN 0 AND 12'],
 'attendance_monthly':['membership_days > 0','present_days >= 0','excused_absent_days >= 0','unexcused_absent_days >= 0','present_days + excused_absent_days + unexcused_absent_days = membership_days','tardy_days BETWEEN 0 AND present_days'],
 'assessments':["subject IN ('Math','Reading')",'"window" IN (\'Fall\',\'Spring\')','score BETWEEN 200 AND 800',"(score IS NULL AND performance_level IS NULL) OR (score IS NOT NULL AND performance_level IS NOT NULL AND performance_level = CASE WHEN score >= 570 THEN 'Advanced' WHEN score >= 510 THEN 'Proficient' WHEN score >= 450 THEN 'Developing' ELSE 'Beginning' END)"],
 'course_grades':['semester IN (1,2)','percent_grade BETWEEN 0 AND 100','credits_attempted IN (0,0.5)','credits_earned = CASE WHEN percent_grade >= 60 THEN credits_attempted ELSE 0 END'],
 'interventions':['end_date >= start_date','planned_sessions > 0','attended_sessions BETWEEN 0 AND planned_sessions','cost >= 0'],
 'discipline_incidents':['suspension_days BETWEEN 0 AND 3'],
 'staffing':['fte > 0','salary_benefits >= 0'],
 'finance':['budget >= 0','actual >= 0'],
 'survey_responses':['belonging BETWEEN 1 AND 5','safety BETWEEN 1 AND 5','adult_support BETWEEN 1 AND 5']}
def build():
    sql=['-- Non-destructive: run in a new empty database. Fails on existing tables.','BEGIN;']
    for t,cols in SCHEMAS.items():
        lines=[]
        for c,typ in cols:
            null=(t=='assessments' and c in ['score','performance_level']) or (t=='survey_responses' and c in ['belonging','safety','adult_support'])
            lines.append(f'  "{c}" {typ}'+('' if null else ' NOT NULL'))
        lines.append(f'  PRIMARY KEY ({KEYS[t]})')
        if t=='enrollment':
            lines+=['  FOREIGN KEY (student_id) REFERENCES students(student_id)','  FOREIGN KEY (school_year) REFERENCES school_years(school_year)','  FOREIGN KEY (school_id) REFERENCES schools(school_id)']
        elif 'student_id' in dict(cols) and t!='students':
            lines+=['  FOREIGN KEY (student_id, school_year) REFERENCES enrollment(student_id, school_year)']
        if t in ['staffing','finance']:
            lines+=['  FOREIGN KEY (school_id) REFERENCES schools(school_id)','  FOREIGN KEY (school_year) REFERENCES school_years(school_year)']
        if t=='assessments': lines+=['  UNIQUE (student_id, school_year, subject, "window")']
        if t in ['survey_responses','interventions']: lines+=['  UNIQUE (student_id, school_year)']
        lines += [f'  CHECK ({x})' for x in CHECKS.get(t,[])]
        sql += [f'CREATE TABLE {t} (',',\n'.join(lines),');']
    sql+=['CREATE INDEX ON enrollment (school_id, school_year);']
    for t in ['attendance_monthly','assessments','course_grades','interventions','discipline_incidents','survey_responses']:
        sql += [f'CREATE INDEX ON {t} (student_id, school_year);']
    sql+=['COMMIT;']
    (ROOT/'sql'/'01_schema.sql').write_text('\n'.join(sql)+'\n')
    load=['-- Run psql from repository root so paths resolve.','\\set ON_ERROR_STOP on','BEGIN;']
    for t in SCHEMAS: load += [f"\\copy {t} FROM 'data/{t}.csv' WITH (FORMAT csv, HEADER true, NULL '')"]
    load+=['COMMIT;','ANALYZE;']
    (ROOT/'sql'/'02_load.sql').write_text('\n'.join(load)+'\n')
if __name__=='__main__': build()
