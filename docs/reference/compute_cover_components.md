# Seasonal components of the Cover sub-index

Returns \\p_s\\, the proportion of days of season \\s\\ in the rotation
that carry living plant cover.
[`compute_cover()`](https://danielmanter-usda.github.io/SHMI/reference/compute_cover.md)
is \\100 \sum_s w_s p_s\\ with the weights rescaled to sum to 1, so any
set of season weights can be evaluated or estimated from this table.

## Usage

``` r
compute_cover_components(crop, rot_bounds, clip_to_rotation = TRUE)
```

## Arguments

- crop:

  Species episodes with `MGT_combo`, `CD_name`, `crop_start`,
  `crop_end`.

- rot_bounds:

  Rotation bounds with `MGT_combo`, `rot_start`, `rot_end`.

- clip_to_rotation:

  Logical. If `TRUE` (recommended), only plant days inside
  `rot_start`-`rot_end` count, so \\0 \le p_s \le 1\\. `FALSE`
  reproduces SHMI \<= 1.1.0, which counted every plant day of an
  episode, including days outside the rotation, against the rotation's
  season lengths (so \\p_s\\ could exceed 1).

## Value

A tibble with `MGT_combo`, `p_winter`, `p_spring`, `p_summer`, `p_fall`,
`days_winter` ... `days_fall` (days of each season in the rotation) and
`outside_days` (plant days outside the rotation window), one row per
unit in `rot_bounds`.

## Details

Plant windows are all episodes except those named "fallow", "none" or
"bare" (case- and whitespace-insensitive); overlapping windows are
merged so each day counts once; seasons follow calendar months (winter
Dec-Feb, spring Mar-May, summer Jun-Aug, fall Sep-Nov).
