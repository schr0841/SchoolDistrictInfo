-- Non-destructive: run in a new empty database. Fails on existing tables.
BEGIN;
CREATE TABLE schools (
  "school_id" text NOT NULL,
  "school_name" text NOT NULL,
  "school_level" text NOT NULL,
  "capacity" integer NOT NULL,
  PRIMARY KEY (school_id),
  CHECK (capacity > 0)
);
CREATE TABLE students (
  "student_id" text NOT NULL,
  "student_alias" text NOT NULL,
  "gender" text NOT NULL,
  "race_ethnicity" text NOT NULL,
  "home_language" text NOT NULL,
  PRIMARY KEY (student_id)
);
CREATE TABLE school_years (
  "school_year" text NOT NULL,
  "start_date" date NOT NULL,
  "end_date" date NOT NULL,
  "instructional_days" integer NOT NULL,
  PRIMARY KEY (school_year),
  CHECK (end_date > start_date),
  CHECK (instructional_days = 180)
);
CREATE TABLE enrollment (
  "student_id" text NOT NULL,
  "school_year" text NOT NULL,
  "school_id" text NOT NULL,
  "grade_level" integer NOT NULL,
  "economic_disadvantage" boolean NOT NULL,
  "english_learner" boolean NOT NULL,
  "iep" boolean NOT NULL,
  "prior_year_transfer" boolean NOT NULL,
  PRIMARY KEY (student_id, school_year),
  FOREIGN KEY (student_id) REFERENCES students(student_id),
  FOREIGN KEY (school_year) REFERENCES school_years(school_year),
  FOREIGN KEY (school_id) REFERENCES schools(school_id),
  CHECK (grade_level BETWEEN 0 AND 12)
);
CREATE TABLE attendance_monthly (
  "student_id" text NOT NULL,
  "school_year" text NOT NULL,
  "month_start" date NOT NULL,
  "membership_days" integer NOT NULL,
  "present_days" integer NOT NULL,
  "excused_absent_days" integer NOT NULL,
  "unexcused_absent_days" integer NOT NULL,
  "tardy_days" integer NOT NULL,
  PRIMARY KEY (student_id, school_year, month_start),
  FOREIGN KEY (student_id, school_year) REFERENCES enrollment(student_id, school_year),
  CHECK (membership_days > 0),
  CHECK (present_days >= 0),
  CHECK (excused_absent_days >= 0),
  CHECK (unexcused_absent_days >= 0),
  CHECK (present_days + excused_absent_days + unexcused_absent_days = membership_days),
  CHECK (tardy_days BETWEEN 0 AND present_days)
);
CREATE TABLE assessments (
  "assessment_id" text NOT NULL,
  "student_id" text NOT NULL,
  "school_year" text NOT NULL,
  "subject" text NOT NULL,
  "window" text NOT NULL,
  "score" integer,
  "performance_level" text,
  PRIMARY KEY (assessment_id),
  FOREIGN KEY (student_id, school_year) REFERENCES enrollment(student_id, school_year),
  UNIQUE (student_id, school_year, subject, "window"),
  CHECK (subject IN ('Math','Reading')),
  CHECK ("window" IN ('Fall','Spring')),
  CHECK (score BETWEEN 200 AND 800),
  CHECK ((score IS NULL AND performance_level IS NULL) OR (score IS NOT NULL AND performance_level IS NOT NULL AND performance_level = CASE WHEN score >= 570 THEN 'Advanced' WHEN score >= 510 THEN 'Proficient' WHEN score >= 450 THEN 'Developing' ELSE 'Beginning' END))
);
CREATE TABLE course_grades (
  "student_id" text NOT NULL,
  "school_year" text NOT NULL,
  "subject" text NOT NULL,
  "semester" integer NOT NULL,
  "percent_grade" numeric NOT NULL,
  "credits_attempted" numeric NOT NULL,
  "credits_earned" numeric NOT NULL,
  PRIMARY KEY (student_id, school_year, subject, semester),
  FOREIGN KEY (student_id, school_year) REFERENCES enrollment(student_id, school_year),
  CHECK (semester IN (1,2)),
  CHECK (percent_grade BETWEEN 0 AND 100),
  CHECK (credits_attempted IN (0,0.5)),
  CHECK (credits_earned = CASE WHEN percent_grade >= 60 THEN credits_attempted ELSE 0 END)
);
CREATE TABLE interventions (
  "intervention_id" text NOT NULL,
  "student_id" text NOT NULL,
  "school_year" text NOT NULL,
  "intervention_type" text NOT NULL,
  "start_date" date NOT NULL,
  "end_date" date NOT NULL,
  "planned_sessions" integer NOT NULL,
  "attended_sessions" integer NOT NULL,
  "cost" numeric NOT NULL,
  PRIMARY KEY (intervention_id),
  FOREIGN KEY (student_id, school_year) REFERENCES enrollment(student_id, school_year),
  UNIQUE (student_id, school_year),
  CHECK (end_date >= start_date),
  CHECK (planned_sessions > 0),
  CHECK (attended_sessions BETWEEN 0 AND planned_sessions),
  CHECK (cost >= 0)
);
CREATE TABLE discipline_incidents (
  "incident_id" text NOT NULL,
  "student_id" text NOT NULL,
  "school_year" text NOT NULL,
  "incident_date" date NOT NULL,
  "incident_category" text NOT NULL,
  "response" text NOT NULL,
  "suspension_days" integer NOT NULL,
  PRIMARY KEY (incident_id),
  FOREIGN KEY (student_id, school_year) REFERENCES enrollment(student_id, school_year),
  CHECK (suspension_days BETWEEN 0 AND 3)
);
CREATE TABLE staffing (
  "school_id" text NOT NULL,
  "school_year" text NOT NULL,
  "staff_role" text NOT NULL,
  "fte" numeric NOT NULL,
  "salary_benefits" numeric NOT NULL,
  PRIMARY KEY (school_id, school_year, staff_role),
  FOREIGN KEY (school_id) REFERENCES schools(school_id),
  FOREIGN KEY (school_year) REFERENCES school_years(school_year),
  CHECK (fte > 0),
  CHECK (salary_benefits >= 0)
);
CREATE TABLE finance (
  "school_id" text NOT NULL,
  "school_year" text NOT NULL,
  "category" text NOT NULL,
  "budget" numeric NOT NULL,
  "actual" numeric NOT NULL,
  PRIMARY KEY (school_id, school_year, category),
  FOREIGN KEY (school_id) REFERENCES schools(school_id),
  FOREIGN KEY (school_year) REFERENCES school_years(school_year),
  CHECK (budget >= 0),
  CHECK (actual >= 0)
);
CREATE TABLE survey_responses (
  "response_id" text NOT NULL,
  "student_id" text NOT NULL,
  "school_year" text NOT NULL,
  "belonging" integer,
  "safety" integer,
  "adult_support" integer,
  PRIMARY KEY (response_id),
  FOREIGN KEY (student_id, school_year) REFERENCES enrollment(student_id, school_year),
  UNIQUE (student_id, school_year),
  CHECK (belonging BETWEEN 1 AND 5),
  CHECK (safety BETWEEN 1 AND 5),
  CHECK (adult_support BETWEEN 1 AND 5)
);
CREATE INDEX ON enrollment (school_id, school_year);
CREATE INDEX ON attendance_monthly (student_id, school_year);
CREATE INDEX ON assessments (student_id, school_year);
CREATE INDEX ON course_grades (student_id, school_year);
CREATE INDEX ON interventions (student_id, school_year);
CREATE INDEX ON discipline_incidents (student_id, school_year);
CREATE INDEX ON survey_responses (student_id, school_year);
COMMIT;
