# Compute SHMI scores

Computes the Soil Health Management Index (SHMI) for each management
unit (`MGT_combo`) from prepared inputs and monthly climate normals:
\$\$SHMI = 0.400\\Cover + 0.317\\OrgInput + 0.153\\Diversity +
0.130\\InvDist\$\$

## Usage

``` r
build_shmi(
  shmi_inputs,
  climate,
  weights = NULL,
  dist_meth = c("EPA", "STIR", "auto"),
  implements = NULL
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

  Optional named vector of custom weights (`Cover`, `OrgInput`,
  `Diversity`, `InvDist`), rescaled to sum to 1. Scores with custom
  weights are not comparable to the official SHMI scale.

- dist_meth:

  Tillage scale: `"EPA"` (default; each pass's mixing efficiency and
  depth, or its implement's T-DISC values), `"STIR"` (STIR values), or
  `"auto"` (STIR for records holding only STIR values, otherwise EPA).
  Both are scored with T-DISC's crop intervals and windows.

- implements:

  Optional user implement table (`implement`, `mixing_efficiency`,
  `depth_cm`) overriding T-DISC's values for named implements; see
  [`compute_disturbance()`](https://danielmanter-usda.github.io/SHMI/reference/compute_disturbance.md).

## Value

A list with `indicator_df` (one row per unit: `MGT_combo`, any
management metadata, `SHMI`, `Cover`, `OrgInput`, `Diversity`,
`InvDist`, `Cover_growing`, `Cover_nongrowing`, `Richness`), `weights`,
`dist_meth` (the tillage scale used), `official` (`TRUE` unless custom
weights were used), `shmi_version` and `timestamp` (plus `expert_mode`
and `settings_used`, kept for code written against SHMI \< 1.0).

## Details

- **Cover**: share of days with living plants in the growing and
  non-growing seasons, set by each unit's climate
  ([`compute_cover()`](https://danielmanter-usda.github.io/SHMI/reference/compute_cover.md)).

- **OrgInput**: share of years with an organic amendment or grazing
  animals
  ([`compute_orginput()`](https://danielmanter-usda.github.io/SHMI/reference/compute_orginput.md)).

- **Diversity**: average annual plant species richness
  ([`compute_diversity()`](https://danielmanter-usda.github.io/SHMI/reference/compute_diversity.md)).

- **InvDist**: inverse tillage disturbance, computed as in USDA's T-DISC
  from implement mixing efficiencies and depths, or from STIR
  ([`compute_disturbance()`](https://danielmanter-usda.github.io/SHMI/reference/compute_disturbance.md)).

Every sub-index and SHMI run from 0 to 100. A missing record means the
practice did not happen.

## See also

[`prepare_shmi_inputs()`](https://danielmanter-usda.github.io/SHMI/reference/prepare_shmi_inputs.md),
[`get_shmi_climate()`](https://danielmanter-usda.github.io/SHMI/reference/get_shmi_climate.md),
[`shmi_components()`](https://danielmanter-usda.github.io/SHMI/reference/shmi_components.md),
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
