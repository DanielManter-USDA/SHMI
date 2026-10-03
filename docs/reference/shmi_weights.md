# Official SHMI weights

The weights of the four sub-indices in SHMI 1.0, the medians of 1,000
cross-validated calibration fits against measured soil health on 354 US
plots at 74 sites (NAPESHM). Within Cover, the growing season counts for
0.860 and the non-growing season for 0.140 (see
[`compute_cover()`](https://danielmanter-usda.github.io/SHMI/reference/compute_cover.md)).

## Usage

``` r
shmi_weights()
```

## Value

A named numeric vector: `Cover`, `OrgInput`, `Diversity`, `InvDist`,
summing to 1.

## Examples

``` r
shmi_weights()
#>     Cover  OrgInput Diversity   InvDist 
#>     0.400     0.317     0.153     0.130 
```
