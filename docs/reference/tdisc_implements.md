# T-DISC implement values

The implements of USDA's Tillage Disturbance Index for Soil Carbon
(T-DISC, version 1.1.1, 9/4/2026) with their mixing efficiency and
tillage depth, used by
[`compute_disturbance()`](https://danielmanter-usda.github.io/SHMI/reference/compute_disturbance.md)
when a pass gives an implement name rather than its own values.

## Usage

``` r
tdisc_implements()
```

## Source

USDA Office of the Chief Economist, T-DISC Excel tool, "Implement List"
tab. <https://www.usda.gov/t-disc>

## Value

A tibble with `implement`, `mixing_efficiency` (0-1) and `depth_cm`.

## Examples

``` r
head(tdisc_implements())
#> # A tibble: 6 × 3
#>   implement                                           mixing_efficiency depth_cm
#>   <chr>                                                           <dbl>    <dbl>
#> 1 AERATOR                                                          0.05       20
#> 2 AERATOR, TANDEM DRUM, ANGLE>5                                    0.1        20
#> 3 BED SHAPING, BED-SHAPER PLANTER                                  0.25        6
#> 4 BED SHAPING, BEDDER DISK                                         0.8        15
#> 5 BED SHAPING, BEDDER DISK-ROW                                     0.72       10
#> 6 BED SHAPING, BEDDER DISK/DISK-HIPPER, DEPTH GT4.5IN              0.72       15
```
