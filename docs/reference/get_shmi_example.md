# Path to the example SHMI workbook

Returns the path of the completed example workbook installed with the
package, so the full workflow can be run without downloading or copying
anything.

## Usage

``` r
get_shmi_example()
```

## Value

The path to `SHMI_example_1.xlsx` in the installed package.

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
#> ✔ Validating inputs... [323ms]
#> 
#> ℹ Reading Excel file...
#> ✔ Reading Excel file... [324ms]
#> 
#> ℹ Calculating rotation lengths...
#> ✔ Calculating rotation lengths... [29ms]
#> 
#> ℹ Calculating crop start/end dates...
#> ✔ Calculating crop start/end dates... [149ms]
#> 
#> ℹ Applying overrides...
#> ✔ Applying overrides... [15ms]
#> 
#> ℹ Re-calculating rotation lengths...
#> ✔ Re-calculating rotation lengths... [33ms]
#> 
result <- build_shmi(inputs)
#> ℹ Validating inputs...
#> ✔ Validating inputs... [12ms]
#> 
#> ℹ Computing cover...
#> ✔ Computing cover... [85ms]
#> 
#> ℹ Computing diversity...
#> ✔ Computing diversity... [38ms]
#> 
#> ℹ Computing disturbance...
#> ✔ Computing disturbance... [38ms]
#> 
#> ℹ Computing organic inputs...
#> ✔ Computing organic inputs... [18ms]
#> 
#> ℹ Combining indices...
#> ✔ Combining indices... [30ms]
#> 
#> 
#> 
#> SHMI computed using official national settings.
result$indicator_df
#> # A tibble: 8 × 10
#>   MGT_combo   MGT_study MGT_farm MGT_field MGT_trt  SHMI Cover Diversity InvDist
#>   <chr>       <chr>     <chr>    <chr>     <chr>   <dbl> <dbl>     <dbl>   <dbl>
#> 1 MLSH_ARDEC… MLSH      ARDEC    200A      DMP-Ma…  56.9  62.3         0    55.1
#> 2 MLSH_ARDEC… MLSH      ARDEC    200A      DMP-Ma…  56.9  62.3         0    55.1
#> 3 MLSH_ARDEC… MLSH      ARDEC    200A      DMP-N0   35.8  62.3         0    55.1
#> 4 MLSH_ARDEC… MLSH      ARDEC    200A      DMP-N1…  35.8  62.3         0    55.1
#> 5 MLSH_ARDEC… MLSH      ARDEC    200A      Rot1-N0  42.2  62.3         0   100  
#> 6 MLSH_ARDEC… MLSH      ARDEC    200A      Rot1-N…  42.2  62.3         0   100  
#> 7 MLSH_ARDEC… MLSH      ARDEC    200A      Rot1-N…  42.2  62.3         0   100  
#> 8 MLSH_ARDEC… MLSH      ARDEC    200A      Rot1-N…  42.2  62.3         0   100  
#> # ℹ 1 more variable: OrgInput <dbl>
```
