# Official SHMI weights

The weights of the three sub-indices in SHMI_base, the medians of 1,000
cross-validated calibration fits against measured soil health on 354 US
plots at 74 sites (NAPESHM). Diversity's weight was fixed at 0.150 and
the other two fitted under that constraint. Within Cover/Roots, the
growing season counts 0.760 and the non-growing season 0.240 (see
[`compute_cover()`](https://danielmanter-usda.github.io/SHMI/reference/compute_cover.md)).
Organic amendments are not weighted: they raise SHMI_base to SHMI (see
[`shmi_parameters()`](https://danielmanter-usda.github.io/SHMI/reference/shmi_parameters.md)
and
[`build_shmi()`](https://danielmanter-usda.github.io/SHMI/reference/build_shmi.md)).

## Usage

``` r
shmi_weights()
```

## Value

A named numeric vector: `Cover`, `Diversity`, `InvDist`, summing to 1.

## See also

[`shmi_parameters()`](https://danielmanter-usda.github.io/SHMI/reference/shmi_parameters.md)

## Examples

``` r
shmi_weights()
#>     Cover Diversity   InvDist 
#>     0.687     0.150     0.163 
```
