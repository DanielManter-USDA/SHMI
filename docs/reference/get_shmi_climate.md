# Monthly climate normals for SHMI's Cover seasons

Extracts long-term monthly mean temperature and precipitation (WorldClim
2.1, 1970-2000) at each location, in the form
[`compute_cover()`](https://danielmanter-usda.github.io/SHMI/reference/compute_cover.md)
and
[`build_shmi()`](https://danielmanter-usda.github.io/SHMI/reference/build_shmi.md)
expect. Requires the `geodata` and `terra` packages; the global
WorldClim layers are downloaded once to `path`.

## Usage

``` r
get_shmi_climate(locations, res = 10, path = file.path(tempdir(), "worldclim"))
```

## Arguments

- locations:

  Either the list returned by
  [`prepare_shmi_inputs()`](https://danielmanter-usda.github.io/SHMI/reference/prepare_shmi_inputs.md),
  whose management units supply coordinates (`MGT_lat`, `MGT_lon`) and
  irrigation (`MGT_irr_cat`), or a data frame with `MGT_combo`, `lon`
  and `lat` (decimal degrees) and optionally `irrigated` (logical).
  Irrigated units ignore the dry-month rule.

- res:

  WorldClim resolution in arc-minutes: 10, 5 or 2.5 (finer means a
  larger download).

- path:

  Folder for the downloaded WorldClim files.

## Value

A tibble with `MGT_combo`, `tavg_01` ... `tavg_12` (C), `prec_01` ...
`prec_12` (mm) and `irrigated`.

## Examples

``` r
if (FALSE) { # \dontrun{
inputs  <- prepare_shmi_inputs(get_shmi_example())
climate <- get_shmi_climate(inputs)      # coordinates and irrigation from Mgt_Unit

# or from a table of coordinates
locs <- data.frame(MGT_combo = c("farm1_trt1", "farm1_trt2"),
                   lon = -105.08, lat = 40.59, irrigated = c(FALSE, TRUE))
climate <- get_shmi_climate(locs)
} # }
```
