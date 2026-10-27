# Folder where SHMI keeps the WorldClim climate normals

[`get_shmi_climate()`](https://danielmanter-usda.github.io/SHMI/reference/get_shmi_climate.md)
downloads the global WorldClim 2.1 layers (about 43 MB at 10
arc-minutes) the first time and reuses them afterwards. They are kept in
a persistent user cache, `tools::R_user_dir("SHMI", "cache")`, rather
than the session's temporary folder, so they survive between R sessions.
Set `options(shmi.climate_dir = "...")` or the environment variable
`SHMI_CLIMATE_DIR` to use another folder (for example a shared drive).

## Usage

``` r
shmi_climate_dir()
```

## Value

The folder path (character). It is created by
[`get_shmi_climate()`](https://danielmanter-usda.github.io/SHMI/reference/get_shmi_climate.md)
when first needed.

## Examples

``` r
shmi_climate_dir()
#> [1] "C:\\Users\\Daniel.Manter\\AppData\\Local/R/cache/R/SHMI/worldclim"
```
