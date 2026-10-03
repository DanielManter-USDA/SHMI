# Operation names translated to T-DISC implements

Operation names (from T-DISC's "Implement Mapping" tab, and implement
names used in the NAPESHM records) with the T-DISC implement(s) that
represent each. An operation listed with several implements counts as
several passes.

## Usage

``` r
tdisc_mapping()
```

## Source

USDA Office of the Chief Economist, T-DISC Excel tool, "Implement
Mapping" tab. <https://www.usda.gov/t-disc>

## Value

A tibble with `operation`, `implement` and `source` (`"T-DISC 1.1.1"` or
`"NAPESHM crosswalk"`).

## Examples

``` r
subset(tdisc_mapping(), grepl("moldboard", operation, ignore.case = TRUE))
#> # A tibble: 6 × 3
#>   operation                      implement       source      
#>   <chr>                          <chr>           <chr>       
#> 1 Plow, deep, large, moldboard   PLOW, MOLDBOARD T-DISC 1.1.1
#> 2 Plow, moldboard                PLOW, MOLDBOARD T-DISC 1.1.1
#> 3 Plow, moldboard 10 inch depth  PLOW, MOLDBOARD T-DISC 1.1.1
#> 4 Plow, moldboard 6-7 inch depth PLOW, MOLDBOARD T-DISC 1.1.1
#> 5 Plow, moldboard, conservation  PLOW, MOLDBOARD T-DISC 1.1.1
#> 6 Plow, moldboard, up hill       PLOW, MOLDBOARD T-DISC 1.1.1
```
