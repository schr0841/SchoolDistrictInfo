# Project 3 Metric Definitions

**Academic growth and assessment participation**  
SchoolDistrictInfo | Synthetic demonstration — not an actual district

These definitions apply to the selected school year, subject, grade, and school population. Assessment eligibility is **grades 3–8 and 11**, for **Math and Reading**, in **Fall and Spring**. Keep subjects and test windows separate when reporting participation or proficiency.

## Participation and missingness

| Metric | Definition and denominator |
|---|---|
| **Expected tests** | One test per eligible enrolled student for the selected subject and window. Derive this count from enrollment so entirely missing assessment records remain detectable. |
| **Valid tests or tested students** | Assessment records with a nonmissing score. For one subject, window, and year, each valid record represents one tested student. |
| **Participation rate** | Valid tests ÷ expected tests × 100. |
| **Without a valid score** | Expected tests − valid tests. Includes assessment records with NULL scores and expected tests with no assessment record. |
| **Recorded without score** | An assessment record exists, but its score is NULL. |
| **Missing test records** | Expected tests with no matching assessment record. |
| **Missing score rate** | Expected tests without a valid score ÷ expected tests × 100. This includes both forms of missingness above. |

**Reconciliation:** valid tests + without a valid score = expected tests. Recorded without score + missing test records = without a valid score.

## Spring proficiency

| Metric | Definition and denominator |
|---|---|
| **Proficient students** | Students with valid Spring scores of **510 or higher**, including both Proficient and Advanced performance levels. |
| **Tested below proficiency** | Students with valid Spring scores below 510. Students without valid scores are excluded from this category. |
| **Spring proficiency rate** | Proficient students ÷ valid Spring tests × 100. The denominator is tested students, not all expected students. |

**Missingness rule:** NULL scores represent untested students, not zero scores or nonproficient results. If there are no valid tests, proficiency is undefined and should remain NULL. Display participation or missingness alongside proficiency.

## Growth and paired sample size

| Metric | Definition and interpretation |
|---|---|
| **Matched student-subject pair** | The same student has valid Fall and Spring scores in the same school year and subject. |
| **Individual growth** | Spring score − Fall score for one matched pair. Positive means an increase; negative means a decrease. Unit: score points. |
| **Average paired growth** | Average of individual growth across matched pairs. Both windows use the same students. SQL output: `paired_growth_points`. |
| **Paired sample size** | Number of matched pairs included after filters. Within one subject and year, this equals the number of matched students. |
| **Pairs in a histogram bin** | Number of matched pairs whose growth falls within the hovered score-point interval. The total paired sample size covers all displayed bins. |
| **Difference between overall means** | Mean of all valid Spring scores − mean of all valid Fall scores. Each window can contain different students. SQL output: `overall_mean_change_points`. |
| **Difference between methods** | Difference between overall means − average paired growth. SQL output: `overall_change_minus_paired_growth`. A positive value means the overall-mean method reports a larger change. |

**Interpretation:** results can differ because students tested in only one window affect overall means but are excluded from paired growth. Identical tested student sets produce equal results before rounding; equal sample sizes alone do not establish identical membership. Paired growth describes matched students, not necessarily every eligible student.

## Reporting conventions and limitations

- Calculate school-level or district rates from summed numerators and denominators, rather than averaging subgroup percentages. Calculate pooled average growth from individual pairs or weight subgroup means by paired sample size.
- SQL percentage outputs multiply proportions by 100. Tableau percentage formatting displays proportions as percentages; do not multiply by 100 again when using that formatting.
- Retain unrounded values for calculations and round only the displayed results. Growth and differences between growth methods are score points, not percentages.
- The **200–800 score scale and proficiency cutoff are fictional**. Raw growth is not a validated student growth percentile, and these comparisons do not establish that a school or program caused an outcome.
