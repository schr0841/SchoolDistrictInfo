"""Rebuild the complete fictional district using Python's standard library."""
from pathlib import Path
import csv, random, json, hashlib, math
from datetime import date

ROOT = Path(__file__).resolve().parents[1]
SEED = 20261016
rng = random.Random(SEED)
SCHEMAS = {
 'schools': [('school_id','text'),('school_name','text'),('school_level','text'),('capacity','integer')],
 'students': [('student_id','text'),('student_alias','text'),('gender','text'),('race_ethnicity','text'),('home_language','text')],
 'school_years': [('school_year','text'),('start_date','date'),('end_date','date'),('instructional_days','integer')],
 'enrollment': [('student_id','text'),('school_year','text'),('school_id','text'),('grade_level','integer'),('economic_disadvantage','boolean'),('english_learner','boolean'),('iep','boolean'),('prior_year_transfer','boolean')],
 'attendance_monthly': [('student_id','text'),('school_year','text'),('month_start','date'),('membership_days','integer'),('present_days','integer'),('excused_absent_days','integer'),('unexcused_absent_days','integer'),('tardy_days','integer')],
 'assessments': [('assessment_id','text'),('student_id','text'),('school_year','text'),('subject','text'),('window','text'),('score','integer'),('performance_level','text')],
 'course_grades': [('student_id','text'),('school_year','text'),('subject','text'),('semester','integer'),('percent_grade','numeric'),('credits_attempted','numeric'),('credits_earned','numeric')],
 'interventions': [('intervention_id','text'),('student_id','text'),('school_year','text'),('intervention_type','text'),('start_date','date'),('end_date','date'),('planned_sessions','integer'),('attended_sessions','integer'),('cost','numeric')],
 'discipline_incidents': [('incident_id','text'),('student_id','text'),('school_year','text'),('incident_date','date'),('incident_category','text'),('response','text'),('suspension_days','integer')],
 'staffing': [('school_id','text'),('school_year','text'),('staff_role','text'),('fte','numeric'),('salary_benefits','numeric')],
 'finance': [('school_id','text'),('school_year','text'),('category','text'),('budget','numeric'),('actual','numeric')],
 'survey_responses': [('response_id','text'),('student_id','text'),('school_year','text'),('belonging','integer'),('safety','integer'),('adult_support','integer')]
}
NOTES = {
 'schools':'One row per school. Fictional Cedar Valley Unified; no geographic mapping to real places.',
 'students':'One row per student; exactly 20,000 unique fictional people. Aliases are identifiers, not names.',
 'school_years':'One row per year; fictional 180-day calendar, September through May, 20 membership days per month.',
 'enrollment':'One row per student per year, full-year enrollment. Grade 0 = kindergarten. Flags are annual snapshots.',
 'attendance_monthly':'One row per enrolled student per month. Present + both absence types = membership. Tardy is a subset of present days.',
 'assessments':'One row per student/year/subject/window for grades 3–8 and 11. Fall and Spring, Math and Reading. Missing score means not tested; performance level also blank. Fictional common 200–800 scale; not a state exam.',
 'course_grades':'One row per student/year/subject/semester for grades 6–12; four subjects, two semesters. Pass = 60%. Half credit per course in grades 9–12, zero credits in grades 6–8. Not a complete transcript or graduation audit.',
 'interventions':'Zero or one program per student/year. Selection depends on simulated need; no causal effect is imposed or identifiable.',
 'discipline_incidents':'One row per student incident; zero to two per student/year. Suspension days are response days, not attendance absences, and are not additive with absence days.',
 'staffing':'One row per school/year/role; FTE can be fractional. Salary plus benefits is included in finance Instruction and Student support, not additive to finance totals.',
 'finance':'One row per school/year/category; nominal dollars. School-level operating costs only; excludes capital, debt, and central office. Annual enrollments are denominators, not student-year sums.',
 'survey_responses':'One row per responding student/year, grades 4–12. Voluntary biased response (~72%); blanks within responses mean skipped items. Ratings 1–5; higher is favorable.'
}

def generate():
    (ROOT/'data').mkdir(exist_ok=True)
    streams, writers, counts = {}, {}, {}
    def put(table, *values):
        writers[table].writerow(values); counts[table] += 1
    for t, fields in SCHEMAS.items():
        streams[t] = (ROOT/'data'/f'{t}.csv').open('w',newline='',encoding='utf-8')
        writers[t] = csv.writer(streams[t]); writers[t].writerow([f[0] for f in fields]); counts[t]=0
    schools = {}
    for level, n, cap in [('Elementary',15,700),('Middle',6,900),('High',9,1100)]:
        schools[level]=[]
        for i in range(1,n+1):
            sid=f'{level[0]}{i:02d}'; schools[level].append(sid)
            put('schools',sid,f'Cedar Valley {level} {i:02d}',level,cap)
    school_effect={s:rng.gauss(0,8) for ids in schools.values() for s in ids}
    years=['2023-24','2024-25','2025-26']
    sizes={(s,y):0 for ids in schools.values() for s in ids for y in years}
    for yi,y in enumerate(years): put('school_years',y,f'{2023+yi}-09-01',f'{2024+yi}-05-31',180)
    aid=iid=did=rid=0
    for i in range(1,20001):
        st=f'S{i:06d}'; initial=(i-1)%11
        language=rng.choices(['English','Spanish','Arabic','Somali','Vietnamese','Other'],[70,20,3,3,2,2])[0]
        econ=rng.random()<.43; el=language!='English' and rng.random()<.63; iep=rng.random()<.14
        ability=rng.gauss(0,38); absence_prop=rng.betavariate(1.7,25)
        put('students',st,f'Learner {i:05d}',rng.choices(['Female','Male','Nonbinary','Not reported'],[49,49,1,1])[0],rng.choices(['Asian','Black','Hispanic or Latino','White','Two or more races','American Indian or Alaska Native','Native Hawaiian or Pacific Islander','Not reported'],[7,19,28,36,6,1,1,2])[0],language)
        previous=None
        for yi,y in enumerate(years):
            grade=initial+yi; level='Elementary' if grade<=5 else 'Middle' if grade<=8 else 'High'
            transfer=previous is not None and rng.random()<.045
            if previous in schools[level] and not transfer: school=previous
            else: school=rng.choice(schools[level])
            # Flag changes between schools within the same level, excluding normal level transitions.
            transfer=previous in schools[level] and previous!=school
            previous=school; sizes[school,y]+=1
            put('enrollment',st,y,school,grade,str(econ).lower(),str(el).lower(),str(iep).lower(),str(transfer).lower())
            absences=0
            for m in [9,10,11,12,1,2,3,4,5]:
                yr=2023+yi+(m<9); p=min(.45,absence_prop+(0.015 if m in [1,2] else 0)+(0.018 if transfer else 0))
                absent=sum(rng.random()<p for _ in range(20)); excused=sum(rng.random()<.63 for _ in range(absent)); present=20-absent
                tardy=sum(rng.random()<.055 for _ in range(present)); absences+=absent
                put('attendance_monthly',st,y,f'{yr}-{m:02d}-01',20,present,excused,absent-excused,tardy)
            latent=495+ability+school_effect[school]+yi*7-absences*1.0
            if grade in [3,4,5,6,7,8,11]:
                for subject in ['Math','Reading']:
                    for window in ['Fall','Spring']:
                        missing=rng.random()<(.035+absences*.001)
                        score='' if missing else max(200,min(800,round(latent+(18 if window=='Spring' else 0)+rng.gauss(0,23)+(4 if subject=='Reading' else 0))))
                        perf='' if missing else 'Advanced' if score>=570 else 'Proficient' if score>=510 else 'Developing' if score>=450 else 'Beginning'
                        aid+=1; put('assessments',f'A{aid:07d}',st,y,subject,window,score,perf)
            if grade>=6:
                for subject in ['Math','English','Science','Social studies']:
                    for sem in [1,2]:
                        pct=round(max(30,min(100,77+ability*.23-absences*.35+rng.gauss(0,8))),1)
                        credits=.5 if grade>=9 else 0
                        put('course_grades',st,y,subject,sem,pct,credits,credits if pct>=60 else 0)
            if rng.random()<(.43 if latent<475 or absences>=18 else .07):
                typ='Attendance mentoring' if absences>=18 else rng.choice(['Math tutoring','Reading support'])
                planned=rng.randint(16,40); attended=sum(rng.random()<max(.35,1-absence_prop*2) for _ in range(planned))
                iid+=1; put('interventions',f'I{iid:06d}',st,y,typ,f'{2024+yi}-01-15',f'{2024+yi}-05-15',planned,attended,round(planned*rng.uniform(18,35),2))
            if rng.random()<(.045 if grade<6 else .12):
                for _ in range(1+(rng.random()<.18)):
                    response=rng.choices(['Restorative conference','In-school suspension','Out-of-school suspension'],[70,20,10])[0]
                    days=0 if response=='Restorative conference' else rng.randint(1,3)
                    did+=1; put('discipline_incidents',f'D{did:06d}',st,y,f'{2024+yi}-{rng.randint(1,5):02d}-{rng.randint(1,28):02d}',rng.choice(['Disruption','Peer conflict','Classroom conduct']),response,days)
            if grade>=4 and rng.random()<max(.3,.76-absence_prop):
                rid+=1
                vals=['' if rng.random()<.035 else max(1,min(5,round(rng.gauss(3.6-absence_prop*3,1)))) for _ in range(3)]
                put('survey_responses',f'R{rid:06d}',st,y,*vals)
    for (s,y),n in sizes.items():
        yi=years.index(y); salary_total=support_total=0
        for role,ratio,salary in [('Teacher',19,95000),('Counselor',350,105000),('Support',55,65000),('Administrator',420,135000)]:
            fte=round(max(.5,n/ratio)*rng.uniform(.94,1.06),1); cost=round(fte*salary*(1.035**yi),2)
            put('staffing',s,y,role,fte,cost)
            if role=='Teacher': salary_total+=cost
            else: support_total+=cost
        for cat,base in [('Instruction',salary_total+n*1400),('Student support',support_total+n*500),('Transportation',n*850),('Facilities',n*1300),('Technology',n*450)]:
            budget=round(base*(1.025**yi),2); actual=round(budget*rng.uniform(.92,1.09),2)
            put('finance',s,y,cat,budget,actual)
    for f in streams.values(): f.close()
    manifest={'seed':SEED,'students':20000,'years':years,'files':{}}
    for t in SCHEMAS:
        p=ROOT/'data'/f'{t}.csv'; manifest['files'][p.name]={'rows':counts[t],'sha256':hashlib.sha256(p.read_bytes()).hexdigest()}
    (ROOT/'data'/'manifest.json').write_text(json.dumps(manifest,indent=2)+'\n')
    dictionary=['# Data dictionary','', 'All data are fictional. CSV: UTF-8, header row, comma delimiter, ISO dates, decimal point, no thousands separators. Empty fields are NULL. IDs and school_year are text. All columns are required except assessment score/performance_level and the three survey item ratings.','']
    for t,fields in SCHEMAS.items():
        dictionary += [f'## {t}.csv', '',NOTES[t], '', '| Column | PostgreSQL type |','|---|---|']+[f'| {n} | {dt} |' for n,dt in fields]+['']
    (ROOT/'docs'/'DATA_DICTIONARY.md').write_text('\n'.join(dictionary),encoding='utf-8')
    print(json.dumps({t:counts[t] for t in SCHEMAS},indent=2))

if __name__=='__main__': generate()
