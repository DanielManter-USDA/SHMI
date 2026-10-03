# Compute the Cover sub-index

Share of days with living plants in the growing and non-growing seasons,
weighted and scaled 0-100.

## Usage

``` r
compute_cover(crop, rot_bounds, climate, grow_temp = 5, growing_share = 0.86)
```

## Arguments

- crop:

  Species episodes with `MGT_combo`, `CD_name`, `crop_start` and
  `crop_end`, as in `prepare_shmi_inputs()$crop`.

- rot_bounds:

  Rotation bounds with `MGT_combo`, `rot_start` and `rot_end`.

- climate:

  Monthly climate normals, one row per `MGT_combo`, with `tavg_01` ...
  `tavg_12` (mean temperature, C), `prec_01` ... `prec_12`
  (precipitation, mm) and optionally `irrigated` (logical). See
  [`get_shmi_climate()`](https://danielmanter-usda.github.io/SHMI/reference/get_shmi_climate.md).

- grow_temp:

  Minimum monthly mean temperature (C) of a growing month.

- growing_share:

  Weight of the growing season within Cover.

## Value

A tibble with `MGT_combo`, `Cover`, `Cover_growing` and
`Cover_nongrowing` (all 0-100), one row per unit in `rot_bounds`.

## Details

**Plant days.** Every crop episode is a window of living cover, except
rows named `"fallow"`, `"none"` or `"bare"`. Overlapping windows
(mixtures, relays, cover crops) are merged, so each day counts once.

**Seasons.** A calendar month is in the growing season at a unit when
its long-term mean temperature is at least `grow_temp` (5 C) and, unless
the unit is irrigated, it is not dry: precipitation (mm) at least twice
the mean temperature (C), the Bagnouls-Gaussen dry-month rule. Other
months form the non-growing season. If a unit has no months in one
season, that season takes the other's value.

**Score.** With \\G\\ and \\N\\ the percentage of growing- and
non-growing-season days with living plants, \$\$Cover = s G + (1 - s)
N\$\$ where \\s\\ is `growing_share` (0.860, from the SHMI calibration).

## See also

[`get_shmi_climate()`](https://danielmanter-usda.github.io/SHMI/reference/get_shmi_climate.md),
[`build_shmi()`](https://danielmanter-usda.github.io/SHMI/reference/build_shmi.md)

## Examples

``` r
crop <- data.frame(MGT_combo = "field_1", CD_name = c("Corn", "Rye"),
                   crop_start = as.Date(c("2020-05-01", "2020-10-15")),
                   crop_end   = as.Date(c("2020-09-30", "2020-12-31")))
rot_bounds <- data.frame(MGT_combo = "field_1",
                         rot_start = as.Date("2020-01-01"),
                         rot_end   = as.Date("2020-12-31"))
climate <- data.frame(MGT_combo = "field_1")
climate[sprintf("tavg_%02d", 1:12)] <- as.list(c(-5, -3, 3, 10, 16, 21, 24, 23, 18, 11, 4, -2))
climate[sprintf("prec_%02d", 1:12)] <- as.list(c(30, 30, 50, 80, 100, 110, 100, 90, 80, 60, 50, 35))
compute_cover(crop, rot_bounds, climate)
#> # A tibble: 1 × 4
#>   MGT_combo Cover Cover_growing Cover_nongrowing
#>   <chr>     <dbl>         <dbl>            <dbl>
#> 1 field_1    73.9          79.4             40.1
```
