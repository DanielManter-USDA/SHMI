# Compute the Cover sub-index

Season-weighted proportion of days in the rotation with living plant
cover, scaled 0-100.

## Usage

``` r
compute_cover(
  crop,
  rot_bounds,
  w_winter = 0.1259,
  w_spring = 0.126,
  w_summer = 0.3755,
  w_fall = 0.3726,
  clip_to_rotation = TRUE
)
```

## Arguments

- crop:

  Species episodes with `MGT_combo`, `CD_name`, `crop_start`, and
  `crop_end`, as in `prepare_shmi_inputs()$crop`.

- rot_bounds:

  Rotation bounds with `MGT_combo`, `rot_start`, and `rot_end`.

- w_winter, w_spring, w_summer, w_fall:

  Season weights. Defaults are the official values.

- clip_to_rotation:

  Logical; see *Rotation window*. `FALSE` reproduces SHMI \<= 1.1.0.

## Value

A data frame with `MGT_combo` and `Cover` (0-100), one row per unit in
`rot_bounds`.

## Details

**Plant windows.** Every row of `crop` (one row per species episode) is
a window of living cover, except rows named `"fallow"`, `"none"`, or
`"bare"`. Overlapping windows (mixtures, relays, intercrops) are merged,
so each day counts once however many species are present.

**Seasons.** Each day is assigned to a season by calendar month: winter
(Dec-Feb), spring (Mar-May), summer (Jun-Aug), and fall (Sep-Nov). For
each season \\s\\, \\p_s\\ is the number of plant days divided by the
number of days of that season in the rotation; seasons with no days in
the rotation contribute 0.

**Score.** The season weights are rescaled to sum to 1, and \$\$Cover =
100 \sum_s w_s p_s\$\$

**Rotation window.** Days in the rotation run from `rot_start` to
`rot_end`. In
[`prepare_shmi_inputs()`](https://danielmanter-usda.github.io/SHMI/reference/prepare_shmi_inputs.md)
these span the first to the last recorded event, or the window set by
`start_date_override` and `end_date_override`, which is how a fixed
evaluation period is imposed.

Only plant days inside `rot_start`-`rot_end` count when
`clip_to_rotation = TRUE` (the default from 1.2.0). SHMI \<= 1.1.0
counted every day of an episode, including days outside the rotation,
against the rotation's season lengths, so a season's proportion could
exceed 1 when episodes extended past the evaluation window.

A unit in `rot_bounds` with no plant windows (for example a fallow
reference site) scores 0.

## See also

[`compute_cover_components()`](https://danielmanter-usda.github.io/SHMI/reference/compute_cover_components.md),
[`build_shmi()`](https://danielmanter-usda.github.io/SHMI/reference/build_shmi.md),
[`compute_diversity()`](https://danielmanter-usda.github.io/SHMI/reference/compute_diversity.md)

## Examples

``` r
crop <- data.frame(
  MGT_combo  = "field_1",
  CD_name    = c("Corn", "Rye"),
  crop_start = as.Date(c("2020-05-01", "2020-10-15")),
  crop_end   = as.Date(c("2020-09-30", "2020-12-31"))
)
rot_bounds <- data.frame(
  MGT_combo = "field_1",
  rot_start = as.Date("2020-01-01"),
  rot_end   = as.Date("2020-12-31")
)
compute_cover(crop, rot_bounds)
#> # A tibble: 1 × 2
#>   MGT_combo Cover
#>   <chr>     <dbl>
#> 1 field_1    77.6
```
