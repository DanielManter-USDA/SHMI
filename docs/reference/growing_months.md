# Growing-season months from monthly climate normals

A month is in the growing season when its mean temperature is at least
`grow_temp` and, unless the unit is irrigated, precipitation (mm) is at
least twice the mean temperature (C).

## Usage

``` r
growing_months(climate, grow_temp = 5)
```

## Arguments

- climate:

  Monthly climate normals, one row per `MGT_combo`, with `tavg_01` ...
  `tavg_12` (mean temperature, C), `prec_01` ... `prec_12`
  (precipitation, mm) and optionally `irrigated` (logical). See
  [`get_shmi_climate()`](https://danielmanter-usda.github.io/SHMI/reference/get_shmi_climate.md).

- grow_temp:

  Minimum monthly mean temperature (C) of a growing month.

## Value

A logical matrix, one row per `MGT_combo` (row names) and one column per
month; `TRUE` = growing season.
