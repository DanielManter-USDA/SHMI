# Years with organic amendments and animals

The shares of years that drive SHMI's two organic-input terms:
`p_animal` raises Diversity (grazing credit) and `p_amend` raises SHMI
to SHMI+ (amendment bonus); see
[`build_shmi()`](https://danielmanter-usda.github.io/SHMI/reference/build_shmi.md).

## Usage

``` r
compute_orginput_components(rot_bounds, amend, animal)
```

## Arguments

- rot_bounds:

  Rotation bounds with `MGT_combo`, `rot_start_yr`, `rot_end_yr`.

- amend:

  Amendment events with `MGT_combo`, `SA_date`, `SA_cat`.

- animal:

  Animal events with `MGT_combo`, `AD_start_date`, `AD_end_date`. Every
  calendar year overlapped by an animal period counts; periods without
  an end date count in their start year only.

## Value

A tibble with `MGT_combo`, `p_amend`, `p_animal`, `p_any` (share of
years with an organic amendment or animals, or both) and `n_years`.
