# All linear components needed to calibrate SHMI weights

For fixed nonlinear settings (`hill`, `max_div`, `dist_meth`,
`max_stir`, `ti_rep`), SHMI is linear in `C_winter`, `C_spring`,
`C_summer`, `C_fall`, `Diversity`, `InvDist`, `O_amend`, `O_animal` (all
0-100): \$\$SHMI = w\_{cov} \sum_s w_s C_s + w\_{div} Diversity +
w\_{inv} InvDist + w\_{org} (w_a O\_{amend} + w_n O\_{animal})\$\$

## Usage

``` r
compute_shmi_components(
  shmi_inputs,
  settings = NULL,
  clip_to_rotation = NULL,
  animal_presence = NULL,
  check = TRUE
)
```

## Arguments

- shmi_inputs:

  A list returned by
  [`prepare_shmi_inputs()`](https://danielmanter-usda.github.io/SHMI/reference/prepare_shmi_inputs.md).

- settings:

  Optional named list of nonlinear settings (expert mode).

- clip_to_rotation, animal_presence:

  Leave `NULL` to use the values
  [`build_shmi()`](https://danielmanter-usda.github.io/SHMI/reference/build_shmi.md)
  applied (from `settings_used`), which keeps the components consistent
  with the package scores.

- check:

  Logical. Verify that the components reproduce
  [`build_shmi()`](https://danielmanter-usda.github.io/SHMI/reference/build_shmi.md)'s
  Cover and OrgInput under the official weights.
