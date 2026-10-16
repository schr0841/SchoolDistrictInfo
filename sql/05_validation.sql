-- Server-side assertions, also executed by GitHub Actions.
DO $$
BEGIN
 IF (SELECT COUNT(*) FROM students) <> 20000 THEN
   RAISE EXCEPTION 'Expected 20000 students';
 END IF;
 IF (SELECT COUNT(*) FROM student_year_metrics) <> 60000 THEN
   RAISE EXCEPTION 'Student-year view has incorrect grain';
 END IF;
 IF EXISTS (SELECT 1 FROM student_year_metrics WHERE membership_days<>180) THEN
   RAISE EXCEPTION 'Annual membership mismatch';
 END IF;
 IF (SELECT COUNT(*) FROM school_year_metrics) <> 90 THEN
   RAISE EXCEPTION 'School-year scaffold mismatch';
 END IF;
 IF EXISTS (SELECT school_year FROM school_year_metrics GROUP BY school_year HAVING SUM(enrollment)<>20000) THEN
   RAISE EXCEPTION 'School-year enrollments do not reconcile';
 END IF;
 IF (SELECT SUM(actual) FROM school_year_metrics) <> (SELECT SUM(actual) FROM finance) THEN
   RAISE EXCEPTION 'Finance totals do not reconcile';
 END IF;
 IF (SELECT SUM(teacher_fte) FROM school_year_metrics) <> (SELECT SUM(fte) FROM staffing WHERE staff_role='Teacher') THEN
   RAISE EXCEPTION 'Teacher FTE does not reconcile';
 END IF;
 IF EXISTS (SELECT student_id,school_year,subject FROM assessment_growth GROUP BY 1,2,3 HAVING COUNT(*)>1) THEN
   RAISE EXCEPTION 'Assessment growth grain mismatch';
 END IF;
END $$;
