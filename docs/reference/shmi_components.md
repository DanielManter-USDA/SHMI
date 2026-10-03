# The four SHMI sub-indices for each management unit

Computes Cover, Diversity, InvDist and OrgInput (all 0-100) from
prepared inputs.
[`build_shmi()`](https://danielmanter-usda.github.io/SHMI/reference/build_shmi.md)
combines them with the official weights; calling this function directly
is useful for calibration or for inspecting the parts of Cover.

## Usage

``` r
shmi_components(
  shmi_inputs,
  climate,
  dist_meth = c("EPA", "STIR", "auto"),
  implements = NULL
)
```

## Arguments

- shmi_inputs:

  A list returned by
  [`prepare_shmi_inputs()`](https://danielmanter-usda.github.io/SHMI/reference/prepare_shmi_inputs.md).

- climate:

  Monthly climate normals per `MGT_combo`; see
  [`compute_cover()`](https://danielmanter-usda.github.io/SHMI/reference/compute_cover.md)
  and
  [`get_shmi_climate()`](https://danielmanter-usda.github.io/SHMI/reference/get_shmi_climate.md).
  Its `irrigated` column, if present, overrides the irrigation recorded
  on Mgt_Unit (`MGT_irr_cat`).

- dist_meth:

  Tillage scale: `"EPA"` (default), `"STIR"`, or `"auto"` (EPA when
  passes name implements or give mixing efficiencies; STIR when only
  STIR values are recorded).

- implements:

  Optional user implement table (`implement`, `mixing_efficiency`,
  `depth_cm`) overriding T-DISC's values; see
  [`compute_disturbance()`](https://danielmanter-usda.github.io/SHMI/reference/compute_disturbance.md).

## Value

A tibble with `MGT_combo`, `Cover`, `Cover_growing`, `Cover_nongrowing`,
`Diversity`, `Richness`, `InvDist`, `TI_tillage`, `tillage_designation`
(T-DISC: NT, RT or CT) and `OrgInput`, one row per unit in
`shmi_inputs$mgt`. Missing records mean the practice did not happen: no
crops gives Cover and Diversity 0, no disturbance InvDist 100, no
organic inputs OrgInput 0.
