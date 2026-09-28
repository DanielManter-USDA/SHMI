# Compute the Organic Inputs sub-index

Proportion of rotation years with organic amendments and with animals,
weighted and scaled 0-100.

## Usage

``` r
compute_orginput(
  rot_bounds,
  amend,
  animal,
  w_amend = 0.6615,
  w_animal = 0.3385,
  animal_presence = c("start", "span")
)
```

## Arguments

- rot_bounds:

  Rotation bounds with `MGT_combo`, `rot_start_yr`, and `rot_end_yr`.

- amend:

  Amendment events with `MGT_combo`, `SA_date`, and `SA_cat`.

- animal:

  Animal events with `MGT_combo` and `AD_start_date`.

- w_amend, w_animal:

  Weights for amendments and animals. Defaults are the official values.

- animal_presence:

  `"start"` (SHMI \<= 1.1.0) or `"span"`; see
  [`compute_orginput_components()`](https://danielmanter-usda.github.io/SHMI/reference/compute_orginput_components.md).

## Value

A data frame with `MGT_combo` and `OrgInput` (0-100), one row per unit
in `rot_bounds`.

## Details

For every calendar year from `rot_start_yr` to `rot_end_yr`, a year
counts as having an amendment if any amendment with
`SA_cat == "Organic"` is dated in that year, and as having animals if
any animal period starts in that year (`AD_start_date`). Only presence
is scored; amounts are not used. With \\p\\ the proportion of years with
each input, \$\$OrgInput = 100 \frac{w\_{amend} p\_{amend} + w\_{animal}
p\_{animal}}{w\_{amend} + w\_{animal}}\$\$

A missing record means no input: a unit with no organic amendments or
animals scores 0.

With `animal_presence = "span"`, every calendar year overlapped by an
animal period (`AD_start_date` to `AD_end_date`) counts, so continuous
multi-year grazing is scored in every year rather than only its first.

## See also

[`compute_orginput_components()`](https://danielmanter-usda.github.io/SHMI/reference/compute_orginput_components.md),
[`build_shmi()`](https://danielmanter-usda.github.io/SHMI/reference/build_shmi.md)

## Examples

``` r
rot_bounds <- data.frame(MGT_combo = "field_1",
                         rot_start_yr = 2019, rot_end_yr = 2020)
amend <- data.frame(MGT_combo = "field_1",
                    SA_date = as.Date("2019-04-01"), SA_cat = "Organic")
animal <- data.frame(MGT_combo = character(),
                     AD_start_date = as.Date(character()))
compute_orginput(rot_bounds, amend, animal)
#> # A tibble: 1 × 2
#>   MGT_combo OrgInput
#>   <chr>        <dbl>
#> 1 field_1       33.1
```
