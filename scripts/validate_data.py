"""Validate checksums, all PK/FK/check constraints and cross-file business rules.
SQLite is used only as a portable validator; PostgreSQL remains the target engine.
"""
import csv, hashlib, json, sqlite3, re
from pathlib import Path
from generate_data import SCHEMAS
from build_sql import build
ROOT=Path(__file__).resolve().parents[1]
def validate():
    build()
    db=sqlite3.connect(':memory:'); db.execute('PRAGMA foreign_keys=ON')
    schema=(ROOT/'sql'/'01_schema.sql').read_text()
    schema=re.sub(r'CREATE INDEX ON ([a-z_]+) \(([^;]+)\);',lambda m:f'CREATE INDEX ix_{m[1]}_{m[2].replace(", ","_")} ON {m[1]} ({m[2]});',schema)
    db.executescript(schema)
    manifest=json.loads((ROOT/'data'/'manifest.json').read_text())
    counts={}
    for t,cols in SCHEMAS.items():
        path=ROOT/'data'/f'{t}.csv'
        assert hashlib.sha256(path.read_bytes()).hexdigest()==manifest['files'][path.name]['sha256'],f'{t}: checksum'
        with path.open(newline='',encoding='utf-8') as f:
            reader=csv.reader(f); assert next(reader)==[c for c,_ in cols]
            def rows():
                for row in reader:
                    assert len(row)==len(cols)
                    yield [None if v=='' else 1 if v=='true' else 0 if v=='false' else v for v in row]
            db.executemany(f'INSERT INTO {t} VALUES ({",".join("?" for _ in cols)})',rows())
        counts[t]=db.execute(f'SELECT COUNT(*) FROM {t}').fetchone()[0]
        assert counts[t]==manifest['files'][path.name]['rows']
    assert counts['students']==20000 and counts['enrollment']==60000
    assertions={
      'complete 180-day attendance': 'SELECT COUNT(*) FROM (SELECT student_id,school_year FROM attendance_monthly GROUP BY 1,2 HAVING COUNT(*)<>9 OR SUM(membership_days)<>180)',
      'month belongs to enrolled year': "SELECT COUNT(*) FROM attendance_monthly a JOIN school_years y USING(school_year) WHERE a.month_start<y.start_date OR a.month_start>y.end_date",
      'assessment grade eligibility': 'SELECT COUNT(*) FROM assessments a JOIN enrollment e USING(student_id,school_year) WHERE e.grade_level NOT IN (3,4,5,6,7,8,11)',
      'course grade eligibility': 'SELECT COUNT(*) FROM course_grades g JOIN enrollment e USING(student_id,school_year) WHERE e.grade_level<6 OR (e.grade_level<9 AND g.credits_attempted<>0) OR (e.grade_level>=9 AND g.credits_attempted<>0.5)',
      'school level consistency': "SELECT COUNT(*) FROM enrollment e JOIN schools s USING(school_id) WHERE s.school_level<>CASE WHEN grade_level<=5 THEN 'Elementary' WHEN grade_level<=8 THEN 'Middle' ELSE 'High' END",
      'survey grade eligibility': 'SELECT COUNT(*) FROM survey_responses r JOIN enrollment e USING(student_id,school_year) WHERE grade_level<4',
      'program dates within year': 'SELECT COUNT(*) FROM interventions i JOIN school_years y USING(school_year) WHERE i.start_date<y.start_date OR i.end_date>y.end_date',
      'incident dates within year': 'SELECT COUNT(*) FROM discipline_incidents i JOIN school_years y USING(school_year) WHERE i.incident_date<y.start_date OR i.incident_date>y.end_date',
      'assessment completeness': 'SELECT COUNT(*) FROM (SELECT student_id,school_year FROM assessments GROUP BY 1,2 HAVING COUNT(*)<>4)',
      'course completeness': 'SELECT COUNT(*) FROM (SELECT student_id,school_year FROM course_grades GROUP BY 1,2 HAVING COUNT(*)<>8)'
    }
    for name,q in assertions.items(): assert db.execute(q).fetchone()[0]==0,name
    report={'status':'PASS','checks':['SHA-256 and row counts','all primary keys, foreign keys, NOT NULL and CHECK constraints',*assertions],'rows':counts,'total_csv_rows':sum(counts.values()),'engine':'Python standard library + SQLite; PostgreSQL execution not performed'}
    (ROOT/'docs'/'VALIDATION_REPORT.json').write_text(json.dumps(report,indent=2)+'\n')
    print(json.dumps(report,indent=2))
if __name__=='__main__': validate()
