# SHMI and SHMI+

A Weighted Sum of Three Management Sub-indices, plus an Organic
Amendment Bonus

## **Overview**

The Soil Health Management Index reports two 0–100 scores. **SHMI**
combines **Cover**, **Diversity** and **Inverse Disturbance**, with
weights calibrated against measured soil health. **SHMI+** adds a bonus
for organic amendments.

------------------------------------------------------------------------

## **1. The formulas**

For management unit $`i`$:

``` math

\text{SHMI}_i = 0.687\,\text{Cover}_i + 0.150\,\text{Diversity}_i + 0.163\,\text{InvDist}_i
```

``` math

\text{SHMI+}_i = \text{SHMI}_i + 0.60\,p_{amend,i}\,(100 - \text{SHMI}_i)
```

where $`p_{amend,i}`$ is the share of years with an organic amendment.

| Constant | Value | 95% range across 1,000 calibration fits |
|----|----|----|
| Cover weight | 0.687 | 0.65 – 0.73 |
| Diversity weight | 0.150 | fixed |
| Inverse Disturbance weight | 0.163 | 0.12 – 0.20 |
| Growing-season share in Cover | 0.760 | 0.70 – 0.83 |
| Grazing share (Diversity) | 0.25 | chosen; fit flat 0.25 – 0.5 |
| Amendment share (SHMI+) | 0.60 | chosen; fit flat 0.5 – 0.8 |

The weights sum to 1 and both gap terms close part of the distance to
100, so $`0 \le \text{SHMI}_i \le \text{SHMI+}_i \le 100`$.
[`shmi_weights()`](https://danielmanter-usda.github.io/SHMI/reference/shmi_weights.md)
returns the weights and
[`shmi_parameters()`](https://danielmanter-usda.github.io/SHMI/reference/shmi_parameters.md)
every constant.

------------------------------------------------------------------------

## **2. How `build_shmi()` computes them**

1.  **Validation.** The inputs from
    [`prepare_shmi_inputs()`](https://danielmanter-usda.github.io/SHMI/reference/prepare_shmi_inputs.md)
    are checked: required tables and columns, valid dates, unique
    `MGT_combo`, and tillage values that suit the tillage scale.
2.  **Tillage.** Computed as in USDA’s T-DISC tool, from implement
    mixing efficiencies and depths (from the pass, a user table, or
    T-DISC); STIR records with `dist_meth = "STIR"`.
3.  **Sub-indices.**
    [`shmi_components()`](https://danielmanter-usda.github.io/SHMI/reference/shmi_components.md)
    computes the sub-indices over each unit’s evaluation window, using
    the monthly climate for Cover, and the shares of years with
    amendments and with animals; grazing raises Diversity. Missing
    records mean the practice did not happen.
4.  **Combination.** SHMI is the weighted sum; SHMI+ adds the amendment
    bonus.

------------------------------------------------------------------------

## **3. Official and custom scores**

Scores are **official** when the official weights and constants are
used, with either tillage scale. Custom weights (rescaled to sum to 1),
`growing_share`, `graze_gap` or `amend_gap` (for research or scenario
analysis) flag the result `official = FALSE`.

------------------------------------------------------------------------

## **4. Output**

[`build_shmi()`](https://danielmanter-usda.github.io/SHMI/reference/build_shmi.md)
returns a list. Its `indicator_df` has one row per management unit:

| Column | Range | Meaning |
|----|----|----|
| SHMI | 0–100 | weighted sum of the three sub-indices |
| SHMI_plus | 0–100 | SHMI plus the amendment bonus |
| Amend_bonus | 0–60 | SHMI_plus − SHMI |
| Cover, Diversity, InvDist | 0–100 | the sub-indices (Diversity with the grazing credit) |
| Cover_growing, Cover_nongrowing | 0–100 | the two parts of Cover |
| Diversity_plants | 0–100 | Diversity before the grazing credit |
| Richness | species | average species per 4-year span |
| p_amend, p_animal | 0–1 | shares of years with an organic amendment and with animals |
| TI_tillage, tillage_designation |  | T-DISC tillage intensity and NT / RT / CT |

plus the unit’s study, farm, field and treatment. The list also records
`weights`, `parameters`, `dist_meth`, `official`, `shmi_version` and
`timestamp`.

------------------------------------------------------------------------

## **Interpretation**

- **Higher scores** mean management more supportive of soil health: more
  of the year under living cover, more plant species and grazing, less
  tillage and, for SHMI+, more frequent organic amendments.
- **Two scores.** SHMI describes the field’s own management; SHMI+ adds
  carbon brought in from outside. They are equal for a unit without
  amendments.
- **Precision.** For US sites not used in calibration, SHMI+ explained
  about a quarter of the differences in measured soil health (R² = 0.26)
  and ranked practices in the right order at 82% of sites (SHMI: 0.23
  and 76%); a single prediction is typically within about 13 soil-health
  points. Both are most informative for comparing practices at the same
  site.
- **Scope.** Calibrated on US systems; recalibrate before use in other
  regions.
