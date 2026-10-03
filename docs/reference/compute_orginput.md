# Compute the Organic Inputs sub-index

Share of years with an organic amendment or grazing animals, scaled
0-100.

## Usage

``` r
compute_orginput(rot_bounds, amend, animal)
```

## Arguments

- rot_bounds:

  Rotation bounds with `MGT_combo`, `rot_start_yr` and `rot_end_yr`.

- amend:

  Amendment events with `MGT_combo`, `SA_date` and `SA_cat`.

- animal:

  Animal events with `MGT_combo`, `AD_start_date` and `AD_end_date`.

## Value

A tibble with `MGT_combo` and `OrgInput` (0-100), one row per unit in
`rot_bounds`.

## Details

For every calendar year from `rot_start_yr` to `rot_end_yr`, a year
counts if it has an amendment with `SA_cat == "Organic"`, or animals:
every calendar year overlapped by an animal period (`AD_start_date` to
`AD_end_date`; a period without an end date counts in its start year).
Only presence is scored, not amounts. A unit with no organic amendments
or animals scores 0.

## See also

[`build_shmi()`](https://danielmanter-usda.github.io/SHMI/reference/build_shmi.md)

## Examples

``` r
rot_bounds <- data.frame(MGT_combo = "field_1", rot_start_yr = 2019, rot_end_yr = 2020)
amend <- data.frame(MGT_combo = "field_1", SA_date = as.Date("2019-04-01"), SA_cat = "Organic")
animal <- data.frame(MGT_combo = character(), AD_start_date = as.Date(character()),
                     AD_end_date = as.Date(character()))
compute_orginput(rot_bounds, amend, animal)   # 50: one of two years
#> # A tibble: 1 × 2
#>   MGT_combo OrgInput
#>   <chr>        <dbl>
#> 1 field_1         50
```
