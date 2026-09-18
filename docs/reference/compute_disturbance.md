# Compute Inverse Disturbance Using EPA Mechanistic or STIR Methods

Computes the SHMI disturbance sub-index for each management unit
(\`MGT_combo\`) using either:

## Usage

``` r
compute_disturbance(
  dist,
  rot_bounds,
  dist_meth = c("EPA", "STIR"),
  max_stir = 300,
  ti_rep = c("mid", "min", "max")
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

  Maximum annual STIR value used for normalization (default 300).

- ti_rep:

  Class representative to use: \`"max"\` (default), \`"min"\`, or
  \`"mid"\`.

## Value

A data frame with:

- `MGT_combo`

- `InvDist` — inverse disturbance score (0–100)

## Details

- \*\*EPA mechanistic soil-mixing model\*\* (profile penetration–based),
  or

- \*\*STIR disturbance intensity\*\* (daily summed mixing efficiency).

Both methods produce an annual tillage-intensity (TI) value for each
rotation year. Annual TI values are then classified into a \*\*Tier 3
tillage-intensity scheme (Z–K)\*\* derived from the EPA Soil-Mixing
Report.

\## Tier 3 Classification (Z–K)

The Tier 3 scheme partitions the `[0, 1]` disturbance domain into
nonlinear classes (Z–K). Each class has a lower and upper TI bound
(`ti_min`, `ti_max`). Class Z is added to represent `TI = 0`. All
classes use closed–open intervals (e.g., `[0.01, 0.04)`) to ensure each
TI maps to exactly one class.

After classification, each TI is replaced by a \*\*class
representative\*\*:

- `"min"` — lower class boundary (`ti_min`)

- `"mid"` — class midpoint (`(ti_min + ti_max)/2`)

- `"max"` — upper class boundary (`ti_max`)

The default representative is `"mid"`, which corresponds to the
midpoint-based EPA Tier 3 interpretation used in the national SHMI.

\## Inverse Disturbance

The inverse-disturbance score is computed as:

\$\$ T\_{t}^{inv} = 100 \times (1 - TI\_{\text{used}}) \$\$

where `TI_used` is the class representative selected by `ti_rep`. This
formulation ensures:

- `TI_used = 0` → `InvDist = 100` (no disturbance)

- `TI_used = 1` → `InvDist = 0` (maximum disturbance)

Rotation-level disturbance is the mean of annual inverse-disturbance
values. Units with no disturbance events receive a score of 100.

\## EPA Mechanistic Method

The EPA method computes mechanistic profile penetration for each tillage
pass using mixing efficiency and tillage depth. Passes occurring on the
same date are treated as sequential operations, producing a \*daily\* TI
value. Daily TI values are summed to annual TI. EPA TI values are
naturally bounded in `[0, 1]` and require no additional normalization.

Required columns in \`dist\`:

- `MGT_combo` — management unit identifier

- `SD_date` — date of tillage pass

- `SD_mixeff` — mixing efficiency (0–1)

- `SD_depth` — tillage depth (in inches; converted internally)

\## STIR Method

The STIR method computes daily disturbance intensity as:

\$\$ SDsum = \sum SD\\mixeff \$\$

summed across all passes on a given date. Annual STIR is the sum of
daily SDsum values. Because STIR is unbounded, annual STIR is normalized
to:

\$\$ TI = \frac{STIR\_{\text{raw}}}{\text{max\\stir}} \$\$

and truncated to `[0, 1]` before Tier 3 classification.

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
