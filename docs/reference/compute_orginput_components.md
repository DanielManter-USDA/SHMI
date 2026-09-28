# Components of the Organic Inputs sub-index

Returns the proportion of rotation years with an organic amendment and
with animals.
[`compute_orginput()`](https://danielmanter-usda.github.io/SHMI/reference/compute_orginput.md)
is \\100 (w_a p\_{amend} + w_n p\_{animal}) / (w_a + w_n)\\.

## Usage

``` r
compute_orginput_components(
  rot_bounds,
  amend,
  animal,
  animal_presence = c("start", "span")
)
```

## Arguments

- rot_bounds:

  Rotation bounds with `MGT_combo`, `rot_start_yr`, `rot_end_yr`.

- amend:

  Amendment events with `MGT_combo`, `SA_date`, `SA_cat`.

- animal:

  Animal events with `MGT_combo`, `AD_start_date` and, for
  `animal_presence = "span"`, `AD_end_date`.

- animal_presence:

  `"start"` (SHMI \<= 1.1.0): a year has animals only if an animal
  period *starts* in it, so a grazing period spanning several years
  counts once. `"span"`: every calendar year overlapped by
  `AD_start_date`-`AD_end_date` counts; periods without an end date
  count in their start year only.

## Value

A tibble with `MGT_combo`, `p_amend`, `p_animal`, `n_years`, one row per
unit in `rot_bounds`.
