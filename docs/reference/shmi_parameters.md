# Official SHMI parameters

Every calibrated constant used by
[`build_shmi()`](https://danielmanter-usda.github.io/SHMI/reference/build_shmi.md):

## Usage

``` r
shmi_parameters()
```

## Value

A list with `weights`, `growing_share`, `graze_gap` and `amend_gap`.

## Details

- `weights`: the sub-index weights
  ([`shmi_weights()`](https://danielmanter-usda.github.io/SHMI/reference/shmi_weights.md)).

- `growing_share`: weight of the growing season within Cover (0.760).

- `graze_gap`: share of the gap to 100 in Diversity closed by grazing
  animals in every year (0.25). Grazing in a share \\p\_{animal}\\ of
  years gives \\Diversity = D\_{plants} + 0.25\\p\_{animal}(100 -
  D\_{plants})\\.

- `amend_gap`: share of the gap to 100 in SHMI closed by an organic
  amendment in every year (0.60). Amendments in a share \\p\_{amend}\\
  of years give \\SHMI+ = SHMI + 0.60\\p\_{amend}(100 - SHMI)\\.

Both gap terms close part of the distance to 100, so no score exceeds
100, and a low score gains more than a high one.

## See also

[`shmi_weights()`](https://danielmanter-usda.github.io/SHMI/reference/shmi_weights.md),
[`build_shmi()`](https://danielmanter-usda.github.io/SHMI/reference/build_shmi.md)

## Examples

``` r
shmi_parameters()
#> $weights
#>     Cover Diversity   InvDist 
#>     0.687     0.150     0.163 
#> 
#> $growing_share
#> [1] 0.76
#> 
#> $graze_gap
#> [1] 0.25
#> 
#> $amend_gap
#> [1] 0.6
#> 
```
