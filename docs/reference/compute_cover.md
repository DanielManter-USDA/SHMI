# Compute the SHMI Cover Sub‑index (Season‑Weighted Plant Presence)

Computes the SHMI cover indicator for each management unit
(\`MGT_combo\`) using crop start/end dates and rotation bounds. Cover
represents the proportion of the rotation during which living plant
cover is present, weighted by season to reflect differential ecological
importance.

## Usage

``` r
compute_cover(
  crop,
  rot_bounds,
  w_winter = 0.13,
  w_spring = 0.129,
  w_summer = 0.513,
  w_fall = 0.227
)
```

## Arguments

- crop:

  A data frame containing one row per crop species with harmonized
  start/end dates, including:

  - `MGT_combo` — management unit identifier

  - `CD_seq_num` — planting event identifier

  - `crop_start`, `crop_end` — daily cover interval

- rot_bounds:

  A data frame containing rotation bounds for each management unit,
  with:

  - `MGT_combo`

  - `rot_start`

  - `rot_end`

- w_winter:

  Weight for winter cover (default 0.130).

- w_spring:

  Weight for spring cover (default 0.129).

- w_summer:

  Weight for summer cover (default 0.513).

- w_fall:

  Weight for fall cover (default 0.227).

## Value

A data frame with:

- `MGT_combo`

- `Cover` — SHMI cover score (0–100)

## Details

\## Mixture‑aware cover windows

The input \`crop\` table contains one row per crop species. Mixtures
therefore appear as multiple rows with identical \`CD_seq_num\` values.
For cover scoring, mixtures must be treated as a \*single\* planting
event. The function collapses mixtures by grouping on:

- `MGT_combo`

- `CD_seq_num`

and computing:

- earliest `crop_start`

- latest `crop_end`

This produces one cover window per planting event, regardless of mixture
complexity.

\## Daily plant‑presence expansion

Each cover window is expanded into daily records. Each day is assigned
to a season based on calendar month:

- Winter: December–February

- Spring: March–May

- Summer: June–August

- Fall: September–November

Seasonal plant‑days are counted for each management unit.

\## Rotation‑based normalization

Rotation bounds (\`rot_start\`, \`rot_end\`) are expanded into daily
records to compute the number of \*possible\* days in each season.
Seasonal cover proportion is:

\$\$ p\_{season} = \frac{\text{plant-days}}{\text{possible-days}} \$\$

Seasons with zero possible days contribute zero.

\## Seasonal weighting and scaling

Seasonal proportions are combined using user‑specified weights:

- `w_winter`

- `w_spring`

- `w_summer`

- `w_fall`

Weights are normalized to sum to 1. The final cover score is:

\$\$ \text{Cover} = 100 \times \sum\_{season} w\_{season} \\ p\_{season}
\$\$

yielding a value in `[0, 100]`.
