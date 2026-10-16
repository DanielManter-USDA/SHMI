# The SHMI sub-indices for each management unit

Computes Cover, Diversity and InvDist (all 0-100), and the shares of
years with organic amendments and with grazing animals, from prepared
inputs.
[`build_shmi()`](https://danielmanter-usda.github.io/SHMI/reference/build_shmi.md)
combines them into SHMI_base and SHMI; calling this function directly is
useful for calibration or for inspecting the parts of Cover and
Diversity.

## Usage

``` r
shmi_components(
  shmi_inputs,
  climate,
  dist_meth = c("EPA", "STIR", "auto"),
  implements = NULL,
  growing_share = shmi_parameters()$growing_share,
  graze_gap = shmi_parameters()$graze_gap
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

- growing_share:

  Weight of the growing season within Cover (official: 0.760; see
  [`compute_cover()`](https://danielmanter-usda.github.io/SHMI/reference/compute_cover.md)).

- graze_gap:

  Share of the gap to 100 in Diversity closed by grazing in every year
  (official: 0.25). 0 gives plant-only Diversity.

## Value

A tibble with `MGT_combo`, `Cover`, `Cover_growing`, `Cover_nongrowing`,
`Diversity` (with the grazing credit), `Diversity_plants` (plants only,
as
[`compute_diversity()`](https://danielmanter-usda.github.io/SHMI/reference/compute_diversity.md)),
`Richness`, `InvDist`, `TI_tillage`, `tillage_designation` (T-DISC: NT,
RT or CT), `p_amend` and `p_animal` (shares of years with an organic
amendment and with animals; see
[`compute_orginput_components()`](https://danielmanter-usda.github.io/SHMI/reference/compute_orginput_components.md)),
one row per unit in `shmi_inputs$mgt`. Missing records mean the practice
did not happen: no crops gives Cover and Diversity 0, no disturbance
InvDist 100, no amendments or animals shares of 0.
