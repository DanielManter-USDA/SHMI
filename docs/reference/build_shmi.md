# Compute SHMI and SHMI+ scores

Computes two scores for each management unit (`MGT_combo`) from prepared
inputs and monthly climate normals: \$\$SHMI = 0.687\\Cover +
0.150\\Diversity + 0.163\\InvDist\$\$ \$\$SHMI+ = SHMI +
0.60\\p\_{amend}\\(100 - SHMI)\$\$

## Usage

``` r
build_shmi(
  shmi_inputs,
  climate,
  weights = NULL,
  dist_meth = c("EPA", "STIR", "auto"),
  implements = NULL,
  growing_share = NULL,
  graze_gap = NULL,
  amend_gap = NULL
)
```

## Arguments

- shmi_inputs:

  A list returned by
  [`prepare_shmi_inputs()`](https://danielmanter-usda.github.io/SHMI/reference/prepare_shmi_inputs.md).

- climate:

  Monthly climate normals, one row per `MGT_combo`, with `tavg_01` ...
  `tavg_12` and `prec_01` ... `prec_12`. `get_shmi_climate(shmi_inputs)`
  builds it from the coordinates on Mgt_Unit. Irrigation comes from
  Mgt_Unit (`MGT_irr_cat`) unless the table has its own `irrigated`
  column.

- weights:

  Optional named vector of custom weights (`Cover`, `Diversity`,
  `InvDist`), rescaled to sum to 1.

- dist_meth:

  Tillage scale: `"EPA"` (default; each pass's mixing efficiency and
  depth, or its implement's T-DISC values), `"STIR"` (STIR values), or
  `"auto"` (STIR for records holding only STIR values, otherwise EPA).
  Both are scored with T-DISC's crop intervals and windows.

- implements:

  Optional user implement table (`implement`, `mixing_efficiency`,
  `depth_cm`) overriding T-DISC's values for named implements; see
  [`compute_disturbance()`](https://danielmanter-usda.github.io/SHMI/reference/compute_disturbance.md).

- growing_share, graze_gap, amend_gap:

  Optional custom values of the calibrated constants (see
  [`shmi_parameters()`](https://danielmanter-usda.github.io/SHMI/reference/shmi_parameters.md)),
  each between 0 and 1. Scores computed with any custom weight or
  constant are flagged `official = FALSE` and are not comparable to the
  official scale.

## Value

A list with `indicator_df` (one row per unit: `MGT_combo`, any
management metadata, `SHMI`, `SHMI_plus`, `Amend_bonus`, `Cover`,
`Diversity`, `InvDist`, then `Cover_growing`, `Cover_nongrowing`,
`Diversity_plants` (before the grazing credit), `Richness`, `p_amend`,
`p_animal`, `TI_tillage` and `tillage_designation`), `weights`,
`parameters` (all constants used), `dist_meth` (the tillage scale used),
`official` (`TRUE` unless a custom weight or constant was used),
`shmi_version` and `timestamp` (plus `expert_mode` and `settings_used`,
kept for code written against SHMI \< 1.0).

## Details

- **Cover**: share of days with living plants in the growing and
  non-growing seasons, set by each unit's climate
  ([`compute_cover()`](https://danielmanter-usda.github.io/SHMI/reference/compute_cover.md)).

- **Diversity**: plant species richness over 4-year spans
  ([`compute_diversity()`](https://danielmanter-usda.github.io/SHMI/reference/compute_diversity.md)),
  raised by grazing animals: grazing in a share \\p\_{animal}\\ of years
  closes \\0.25\\p\_{animal}\\ of the gap to 100.

- **InvDist**: inverse tillage disturbance, computed as in USDA's T-DISC
  from implement mixing efficiencies and depths, or from STIR
  ([`compute_disturbance()`](https://danielmanter-usda.github.io/SHMI/reference/compute_disturbance.md)).

- **SHMI+** adds the amendment bonus, `Amend_bonus`: organic amendments
  in a share \\p\_{amend}\\ of years close \\0.60\\p\_{amend}\\ of the
  gap between SHMI and 100. SHMI describes the field's own plant and
  tillage management; SHMI+ adds carbon brought in from outside. A unit
  without amendments has SHMI+ = SHMI.

Every sub-index and both scores run from 0 to 100. A missing record
means the practice did not happen.

## See also

[`prepare_shmi_inputs()`](https://danielmanter-usda.github.io/SHMI/reference/prepare_shmi_inputs.md),
[`get_shmi_climate()`](https://danielmanter-usda.github.io/SHMI/reference/get_shmi_climate.md),
[`shmi_components()`](https://danielmanter-usda.github.io/SHMI/reference/shmi_components.md),
[`shmi_parameters()`](https://danielmanter-usda.github.io/SHMI/reference/shmi_parameters.md),
[`plot_shmi_gauge()`](https://danielmanter-usda.github.io/SHMI/reference/plot_shmi_gauge.md),
[`plot_shmi_lollipop()`](https://danielmanter-usda.github.io/SHMI/reference/plot_shmi_lollipop.md)

## Examples

``` r
if (FALSE) { # \dontrun{
inputs  <- prepare_shmi_inputs("my_workbook.xlsx")
climate <- get_shmi_climate(inputs)
result  <- build_shmi(inputs, climate)
result$indicator_df
} # }
```
