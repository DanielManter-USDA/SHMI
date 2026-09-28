# Compute the inverse-disturbance sub-index

Scores soil disturbance for each calendar year of the rotation and
averages the years, so that 100 means no disturbance and 0 means maximum
disturbance.

## Usage

``` r
compute_disturbance(
  dist,
  rot_bounds,
  dist_meth = c("EPA", "STIR"),
  max_stir = 342,
  ti_rep = c("max", "min", "mid")
)
```

## Arguments

- dist:

  Disturbance passes with `MGT_combo`, `SD_date`, `SD_mixeff`, and, for
  `"EPA"`, `SD_depth` (inches).

- rot_bounds:

  Rotation bounds with `MGT_combo`, `rot_start_yr`, and `rot_end_yr`.

- dist_meth:

  Disturbance method, `"EPA"` or `"STIR"`.

- max_stir:

  Annual STIR value that corresponds to TI = 1 (`"STIR"` only).

- ti_rep:

  Class representative: `"max"`, `"min"`, or `"mid"`.

## Value

A data frame with `MGT_combo` and `InvDist` (0-100), one row per unit in
`rot_bounds`.

## Details

**Methods.**

- `"EPA"` (official): mechanistic soil-mixing model. `SD_mixeff` is the
  mixing efficiency (a proportion, 0-1) and `SD_depth` the tillage depth
  in inches, converted to cm and capped at 30 cm. Passes on the same day
  are processed from shallowest to deepest, and each disturbs fraction
  \\m\\ of the soil still undisturbed within its depth \\d\\, so
  overlapping passes are not double-counted: \\S_k = S\_{k-1} + m_k
  (d_k - S\_{k-1})\\. The daily value is \\S / 30\\, and daily values
  are summed within each calendar year.

- `"STIR"`: `SD_mixeff` holds STIR values. They are summed within each
  calendar year, divided by `max_stir`, and truncated to 1.

**Classes.** Each annual tillage intensity (TI) is placed in a Tier-3
class (left-closed, right-open intervals):

|       |                 |       |                 |
|-------|-----------------|-------|-----------------|
| Class | TI range        | Class | TI range        |
| Z     | `0 - 0.001`     | F     | `0.144 - 0.162` |
| A     | `0.001 - 0.01`  | G     | `0.162 - 0.202` |
| B     | `0.01 - 0.04`   | H     | `0.202 - 0.252` |
| C     | `0.04 - 0.075`  | I     | `0.252 - 0.268` |
| D     | `0.075 - 0.111` | J     | `0.268 - 0.449` |
| E     | `0.111 - 0.144` | K     | `0.449 - 1`     |

Annual TI is capped at 1 before classification (under `"EPA"` the sum of
daily values can exceed 1), so class K covers 0.449-1 inclusive.

TI is then replaced by a class representative chosen by `ti_rep`: the
lower bound (`"min"`), midpoint (`"mid"`), or upper bound (`"max"`, the
official choice). Class Z always uses 0. The annual score is \\100 (1 -
TI\_{used})\\, and the rotation score is the mean over all calendar
years from `rot_start_yr` to `rot_end_yr`.

**Missing records.** A missing record means no disturbance occurred (for
example, continuous no-till): years without passes score 100, and a unit
with no passes at all scores 100.

**Checks.** Inputs are checked for the chosen method. Under `"EPA"`,
every pass with `SD_mixeff > 0` needs `SD_depth`, `SD_mixeff` must lie
within 0-1 (larger values look like STIR), and depths above 20 inches
give a warning because they may have been entered in cm.

## See also

[`build_shmi()`](https://danielmanter-usda.github.io/SHMI/reference/build_shmi.md),
[`validate_shmi_input()`](https://danielmanter-usda.github.io/SHMI/reference/validate_shmi_input.md)

## Examples

``` r
dist <- data.frame(
  MGT_combo = "field_1",
  SD_date   = as.Date(c("2020-04-15", "2020-05-01")),
  SD_mixeff = c(39, 2.4)   # STIR values: disk harrow, planter
)
rot_bounds <- data.frame(MGT_combo = "field_1",
                         rot_start_yr = 2020, rot_end_yr = 2021)
compute_disturbance(dist, rot_bounds, dist_meth = "STIR")
#>   MGT_combo InvDist
#> 1   field_1    92.8
```
