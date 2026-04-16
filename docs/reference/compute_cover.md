# Compute the SHMI Cover Pillar (Season‑Weighted Plant Presence)

Calculates the SHMI cover indicator for each management unit
(\`MGT_combo\`) using daily crop presence data and rotation bounds.
Cover is computed as a weighted average of seasonal plant‑days, where
each season (winter, spring, summer, fall) contributes a user‑specified
weight. Seasonal plant‑days are normalized by the expected number of
days per season (one‑quarter of the rotation length), and the final
cover score is scaled to 0–100.

## Usage

``` r
compute_cover(
  daily,
  rot_bounds,
  w_winter = 0.25,
  w_spring = 0.25,
  w_summer = 0.25,
  w_fall = 0.25
)
```

## Arguments

- daily:

  A daily data frame produced by
  [`prepare_shmi_inputs()`](https://danielmanter-usda.github.io/SHMI/reference/prepare_shmi_inputs.md),
  containing at least:

  - `MGT_combo` — management unit identifier

  - `date` — calendar date

  - `crop_present` — 1 if a crop is present, 0 otherwise

  - `CD_name` — crop name (used to treat "fallow" as 0 cover)

- rot_bounds:

  A data frame with rotation start and end dates for each `MGT_combo`,
  containing:

  - `MGT_combo`

  - `rot_start`

  - `rot_end`

- w_winter:

  Numeric weight for winter cover (default 0.25).

- w_spring:

  Numeric weight for spring cover (default 0.25).

- w_summer:

  Numeric weight for summer cover (default 0.25).

- w_fall:

  Numeric weight for fall cover (default 0.25).

## Value

A data frame with one row per `MGT_combo` and a single column:

- `Cover` — SHMI cover score (0–100)

## Details

The algorithm proceeds in four steps:

1.  Assign each daily record to a season based on calendar month.

2.  Sum plant‑days within each season for each `MGT_combo`.

3.  Normalize seasonal totals by one‑quarter of the rotation length.

4.  Apply seasonal weights and scale the final cover score to 0–100.

Days where `CD_name == "fallow"` are treated as zero cover.
