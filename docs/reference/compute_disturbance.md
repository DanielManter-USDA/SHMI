# Compute the Inverse Disturbance sub-index

Tillage intensity computed as in USDA's Tillage Disturbance Index for
Soil Carbon (T-DISC), scored 0-100 (100 = no tillage).

## Usage

``` r
compute_disturbance(
  dist,
  rot_bounds,
  crop = NULL,
  harvests = NULL,
  dist_meth = c("EPA", "STIR"),
  implements = NULL,
  max_stir = SHMI_STIR_MAX,
  details = FALSE
)
```

## Arguments

- dist:

  Tillage passes with `MGT_combo`, `SD_date` and, for EPA, `SD_equip`
  and the optional overrides `SD_mixeff` and `SD_depth`; for STIR,
  `SD_stir` (or `SD_mixeff` in workbooks without an `SD_stir` column).

- rot_bounds:

  Rotation bounds with `MGT_combo`, `rot_start_yr`, `rot_end_yr` and,
  optionally, `rot_start` / `rot_end` (dates).

- crop:

  Crop episodes (`prepare_shmi_inputs()$crop`), for planting dates. If
  `NULL`, every calendar year is one interval with one window.

- harvests:

  Harvest records (`prepare_shmi_inputs()$harvests`) with `MGT_combo`,
  `CD_name`, `CD_cat` and `harv_date`. If `NULL`, as for `crop`.

- dist_meth:

  `"EPA"` (default; mixing efficiency and depth, from the implement or
  the pass's overrides) or `"STIR"` (STIR values in `SD_stir`).

- implements:

  Optional user implement table with `implement`, `mixing_efficiency`
  (0-1) and `depth_cm`; its entries take precedence over
  [`tdisc_implements()`](https://danielmanter-usda.github.io/SHMI/reference/tdisc_implements.md)
  and
  [`tdisc_mapping()`](https://danielmanter-usda.github.io/SHMI/reference/tdisc_mapping.md).

- max_stir:

  For `"STIR"`: summed STIR in a window corresponding to an intensity
  of 1. The default (135) best matches T-DISC ratings on the NAPESHM
  data.

- details:

  If `TRUE`, the result carries an `"intervals"` attribute with each
  crop interval's dates, rating, class and designation.

## Value

A tibble, one row per unit in `rot_bounds`: `MGT_combo`, `InvDist`
(0-100), `TI` (length-weighted mean interval rating, 0-1), `designation`
(T-DISC designation of `TI`: `"NT"` up to 0.075, `"RT"` up to 0.252,
otherwise `"CT"`) and `n_intervals`. Units without passes score 100.

## Details

**Crop intervals.** Each cash crop (harvest records with category
`"cash"` or `"annual"`) defines a crop interval, from the day after the
previous cash crop's harvest to its own last harvest. Its planting date
is the start of the latest episode of the same crop beginning on or
before the harvest. Days outside every crop interval (years without a
cash crop, or the end of the record after the last harvest) form one
interval per calendar year.

**Tillage windows.** Within a cash-crop interval with planting date P, a
pass belongs to: *field preparation* (up to 56 days before P), *before
planting* (55-7 days before P), *planting* (6-0 days before P), *after
planting* (after P, outside harvest days) or *harvest* (a harvest day).
Intervals without a planting date, or outside cash crops, have a single
window.

**Window intensity (EPA soil-mixing model).** Implements are applied
from shallowest to deepest (ties: least to most intensive); each mixes
its share of the soil still unmixed within its depth \\d_k\\ (cm, capped
at 30): \$\$S_k = S\_{k-1} + m_k (d_k - S\_{k-1})\$\$ and the window's
intensity is \\S / 30\\. With `dist_meth = "STIR"`, the window's
intensity is its summed STIR divided by `max_stir`, truncated to 1.

**Interval rating and score.** An interval's rating is the maximum of
its window intensities (T-DISC's crop-interval rating). It is placed in
an EPA Tier-3 class and replaced by the class's upper bound (class Z:
0); the interval scores \\100 (1 - \text{class value})\\. The unit's
InvDist is the mean over its intervals, weighted by interval length in
days.

**Implement values (EPA).** Each pass names its implement (`SD_equip`);
its mixing efficiency and depth come from `implements` (a user table
that replaces or adds entries) or else from
[`tdisc_implements()`](https://danielmanter-usda.github.io/SHMI/reference/tdisc_implements.md),
directly or through the operation names in
[`tdisc_mapping()`](https://danielmanter-usda.github.io/SHMI/reference/tdisc_mapping.md).
An operation that maps to several implements counts as several passes on
the same day.

`SD_mixeff` (0-1) and `SD_depth` (inches) are **overrides**: leave them
blank to use the implement's values, or enter either or both to replace
them. A pass with both values needs no implement. For an operation that
maps to several implements, enter both overrides or neither.

Names are matched case- and whitespace-insensitively. Passes that cannot
be resolved stop with a list of the unknown implement names.

## See also

[`tdisc_implements()`](https://danielmanter-usda.github.io/SHMI/reference/tdisc_implements.md),
[`tdisc_mapping()`](https://danielmanter-usda.github.io/SHMI/reference/tdisc_mapping.md),
[`build_shmi()`](https://danielmanter-usda.github.io/SHMI/reference/build_shmi.md)

## Examples

``` r
rot_bounds <- data.frame(MGT_combo = "field_1", rot_start_yr = 2020, rot_end_yr = 2020)
dist <- data.frame(MGT_combo = "field_1", SD_date = as.Date("2020-04-15"),
                   SD_equip = "HARROW, DISK, TANDEM, HEAVYDUTY")
compute_disturbance(dist, rot_bounds)    # T-DISC implement values
#>   MGT_combo InvDist  TI designation n_intervals
#> 1   field_1    55.1 0.4          CT           1

# a user value for the same implement
mine <- data.frame(implement = "HARROW, DISK, TANDEM, HEAVYDUTY",
                   mixing_efficiency = 0.6, depth_cm = 10)
compute_disturbance(dist, rot_bounds, implements = mine)
#>   MGT_combo InvDist  TI designation n_intervals
#> 1   field_1    79.8 0.2          RT           1
```
