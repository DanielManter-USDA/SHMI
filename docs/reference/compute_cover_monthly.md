# Plant days and window days by calendar month

Plant days and days in the evaluation window for each calendar month,
pooled across years, per management unit. Cover's growing and
non-growing seasons are sums over these months.

## Usage

``` r
compute_cover_monthly(crop, rot_bounds)
```

## Arguments

- crop:

  Species episodes with `MGT_combo`, `CD_name`, `crop_start` and
  `crop_end`, as in `prepare_shmi_inputs()$crop`.

- rot_bounds:

  Rotation bounds with `MGT_combo`, `rot_start` and `rot_end`.

## Value

A tibble with `MGT_combo`, `plant_01` ... `plant_12` (plant days) and
`days_01` ... `days_12` (days of each month inside the window).
