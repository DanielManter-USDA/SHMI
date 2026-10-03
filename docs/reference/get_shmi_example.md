# Path to the example SHMI workbook

Returns the path of the completed example workbook installed with the
package, so the full workflow can be run without downloading or copying
anything.

## Usage

``` r
get_shmi_example()
```

## Value

The path to `SHMI_example.xlsx` in the installed package.

## Details

The workbook holds eight management units from one long-term experiment
(2020-2024): continuous corn and a crop rotation under several nitrogen
and manure treatments, with crop, disturbance (EPA mixing efficiencies
and tillage depths), and amendment records. It runs under the official
settings. To get a copy you can open in Excel, use
[`download_shmi_example()`](https://danielmanter-usda.github.io/SHMI/reference/download_shmi_example.md).

## See also

[`download_shmi_example()`](https://danielmanter-usda.github.io/SHMI/reference/download_shmi_example.md),
[`prepare_shmi_inputs()`](https://danielmanter-usda.github.io/SHMI/reference/prepare_shmi_inputs.md),
[`build_shmi()`](https://danielmanter-usda.github.io/SHMI/reference/build_shmi.md)

Other SHMI helper functions:
[`download_shmi_example()`](https://danielmanter-usda.github.io/SHMI/reference/download_shmi_example.md),
[`download_shmi_template()`](https://danielmanter-usda.github.io/SHMI/reference/download_shmi_template.md)

## Examples

``` r
inputs <- prepare_shmi_inputs(get_shmi_example(), verbose = FALSE)
#> ℹ Validating inputs...
#> ✔ Validating inputs... [578ms]
#> 
#> ℹ Reading Excel file...
#> ✔ Reading Excel file... [352ms]
#> 
#> ℹ Calculating rotation lengths...
#> ✔ Calculating rotation lengths... [39ms]
#> 
#> ℹ Calculating crop start/end dates...
#> ✔ Calculating crop start/end dates... [307ms]
#> 
#> ℹ Applying overrides...
#> ✔ Applying overrides... [18ms]
#> 
#> ℹ Re-calculating rotation lengths...
#> ✔ Re-calculating rotation lengths... [68ms]
#> 

# Monthly climate normals for each unit; get_shmi_climate() downloads these
# from WorldClim given coordinates. Typical temperate values, entered by hand:
climate <- data.frame(MGT_combo = inputs$mgt$MGT_combo)
climate[sprintf("tavg_%02d", 1:12)] <- as.list(c(-5, -3, 3, 10, 16, 21, 24, 23, 18, 11, 4, -2))
climate[sprintf("prec_%02d", 1:12)] <- as.list(c(20, 25, 50, 70, 110, 115, 95, 85, 70, 50, 35, 25))

result <- build_shmi(inputs, climate)
#> ℹ Validating inputs...
#> ✔ Validating inputs... [9ms]
#> 
#> ℹ Computing sub-indices...
#> ✔ Computing sub-indices... [233ms]
#> 
#> ℹ Combining...
#> ✔ Combining... [22ms]
#> 
result$indicator_df
#> # A tibble: 8 × 16
#>   MGT_combo  MGT_study MGT_farm MGT_field MGT_trt irrigated  SHMI Cover OrgInput
#>   <chr>      <chr>     <chr>    <chr>     <chr>   <lgl>     <dbl> <dbl>    <dbl>
#> 1 MLSH_ARDE… MLSH      ARDEC    200A      DMP-Ma… TRUE       67.1  70.0      100
#> 2 MLSH_ARDE… MLSH      ARDEC    200A      DMP-Ma… TRUE       67.1  70.0      100
#> 3 MLSH_ARDE… MLSH      ARDEC    200A      DMP-N0  TRUE       35.4  70.0        0
#> 4 MLSH_ARDE… MLSH      ARDEC    200A      DMP-N1… TRUE       35.4  70.0        0
#> 5 MLSH_ARDE… MLSH      ARDEC    200A      Rot1-N0 TRUE       41.0  70.0        0
#> 6 MLSH_ARDE… MLSH      ARDEC    200A      Rot1-N… TRUE       41.0  70.0        0
#> 7 MLSH_ARDE… MLSH      ARDEC    200A      Rot1-N… TRUE       41.0  70.0        0
#> 8 MLSH_ARDE… MLSH      ARDEC    200A      Rot1-N… TRUE       41.0  70.0        0
#> # ℹ 7 more variables: Diversity <dbl>, InvDist <dbl>, Cover_growing <dbl>,
#> #   Cover_nongrowing <dbl>, Richness <dbl>, TI_tillage <dbl>,
#> #   tillage_designation <chr>
```
