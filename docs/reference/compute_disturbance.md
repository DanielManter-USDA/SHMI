# Compute Inverse Disturbance Using EPA Mechanistic or STIR Methods

Computes the SHMI disturbance sub-index for each management unit
(\`MGT_combo\`) using either:

## Usage

``` r
compute_disturbance(
  dist,
  rot_bounds,
  dist_meth = c("EPA", "STIR"),
  max_stir = 190
)
```

## Arguments

- dist:

  Disturbance-event table (EPA or STIR inputs).

- rot_bounds:

  Rotation-year boundaries for each management unit.

- dist_meth:

  Character string: \`"EPA"\` or \`"STIR"\`.

- max_stir:

  Maximum annual STIR value used for normalization (default 190).

## Value

A data frame with:

- `MGT_combo`

- `InvDist` — inverse disturbance score (0–100)

## Details

- \*\*EPA mechanistic soil-mixing model\*\* (profile penetration–based),
  or

- \*\*STIR disturbance intensity\*\* (daily summed mixing efficiency).

Both methods produce an annual tillage-intensity (TI) value for each
rotation year. Annual TI values are then classified into a \*\*modified
Tier 3 tillage-intensity scheme (Z–K)\*\* derived from the EPA
Soil-Mixing Report.

\## Modified Tier 3 Classification (Z–K)

The published Tier 3 ranges (A–K) contain gaps and do not include a
zero-disturbance class. To ensure complete coverage of the `[0, 1]`
domain:

- A new class \*\*Z\*\* is added for `TI = 0`.

- All class boundaries are converted to \*\*closed–open intervals\*\*
  (e.g., `[0.01, 0.04)`), ensuring each TI maps to exactly one class.

- The midpoint for class Z is explicitly set to \*\*0\*\*.

Each annual TI is replaced by the midpoint of its class:

\$\$ T\_{t}^{mid} = (TI\_{min} + TI\_{max}) / 2 \$\$

with `T_{t}^{mid} = 0` for class Z.

The inverse-disturbance score rescales midpoints so that:

- \*\*0 disturbance → 100\*\*, and

- \*\*midpoint of class K → 0\*\*.

\$\$ T\_{t}^{inv} = 100 \times \left(1 -
\frac{T\_{t}^{mid}}{T\_{K}^{mid}}\right) \$\$

Rotation-level disturbance is the mean of annual inverse-disturbance
values. Units with no disturbance events receive a score of 100.

\## EPA Mechanistic Method

The EPA method computes mechanistic profile penetration for each tillage
pass using mixing efficiency and tillage depth. Passes occurring on the
same date are treated as sequential operations, producing a \*daily\* TI
value. Daily TI values are summed to annual TI.

Required columns in \`dist\`:

- `MGT_combo` — management unit identifier

- `SD_date` — date of tillage pass

- `SD_mixeff` — mixing efficiency (0–1)

- `SD_depth` — tillage depth (in inches; converted internally)

\## STIR Method

The STIR method computes daily disturbance intensity as:

\$\$ SDsum = \sum SD\\mixeff \$\$

summed across all passes on a given date. Annual STIR is the sum of
daily SDsum values. Annual STIR is normalized to
`TI = STIR\_raw / max\_stir` and classified using the same Z–K scheme.

Required columns in \`dist\`:

- `MGT_combo`

- `SD_date`

- `SD_mixeff`

\## Rotation Bounds

A data frame containing rotation-year boundaries:

- `MGT_combo`

- `rot_start`

- `rot_end`

- `rot_start_yr`

- `rot_end_yr`
