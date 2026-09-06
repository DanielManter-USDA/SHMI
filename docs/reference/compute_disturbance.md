# Compute Mechanistic Inverse Disturbance (EPA Soil-Mixing Model + Modified Tier 3 TI)

Calculates the SHMI disturbance sub-index for each management unit
(\`MGT_combo\`) using the EPA mechanistic soil-mixing model based on
mixing efficiency and tillage depth. Each tillage pass contributes a
mechanistic profile-penetration value. Passes occurring on the same date
are treated as sequential operations, and their contributions are summed
to produce a single \*daily\* tillage intensity (TI). Daily TI values
are aggregated to an annual TI, which is then classified into a
\*\*modified Tier 3 tillage-intensity scheme (Z–K)\*\* derived from the
EPA Soil-Mixing Report.

## Usage

``` r
compute_disturbance(dist, rot_bounds)
```

## Arguments

- dist:

  A disturbance-event table containing one row per tillage pass, with
  columns:

  - `MGT_combo` — management unit identifier

  - `SD_date` — date of tillage pass

  - `SD_mixeff` — mixing efficiency (0–1)

  - `SD_depth` — tillage depth (in inches; converted internally)

  Multiple passes on the same date are treated as sequential operations.

- rot_bounds:

  A data frame containing rotation bounds for each management unit, with
  columns:

  - `MGT_combo`

  - `rot_start`

  - `rot_end`

## Value

A data frame with:

- `MGT_combo`

- `InvDist` — inverse disturbance score (0–100)

## Details

The published Tier 3 ranges (A–K) contain small gaps between categories
and do not include a zero-disturbance class. To ensure complete coverage
of the \[0, 1\] TI domain and to correctly represent no-disturbance
conditions, the ranges are modified as follows:

- A new class \*\*Z\*\* is added for `TI = 0`, representing true
  zero-disturbance conditions.

- All class boundaries are adjusted to form \*\*closed–open
  intervals\*\* (e.g., `[0.01, 0.04)`) so that every TI value maps to
  exactly one class with no gaps or overlaps.

- The midpoint for class Z is explicitly set to \*\*0\*\*, rather than
  the numerical midpoint of its interval, to reflect the conceptual
  meaning of no disturbance.

Each annual TI is assigned to one of the Z–K classes, and each class is
replaced by the midpoint of its intensity range: \$\$ T\_{t}^{mid} =
(TI\_{min} + TI\_{max}) / 2 \$\$ with the exception that
`T_{t}^{mid} = 0` for class Z.

The inverse-disturbance value for each year is then computed by
rescaling the midpoint so that the midpoint of class K corresponds to 0
and no disturbance corresponds to 100: \$\$ T\_{t}^{inv} = 100 \times
\left(1 - \frac{T\_{t}^{mid}}{T\_{K}^{mid}}\right) \$\$

Rotation-level disturbance is the mean of annual inverse-disturbance
values. Units with no disturbance events receive an inverse-disturbance
score of 100.
