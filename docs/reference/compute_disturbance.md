# Compute Mechanistic Inverse Disturbance (Mixing-Efficiency × Depth Metric)

Calculates the SHMI disturbance sub-index for each management unit
(\`MGT_combo\`) using a mechanistic soil-mixing model based on mixing
efficiency and tillage depth. Disturbance is computed at the \*annual\*
scale and then averaged across the rotation. The final
inverse-disturbance score is scaled to 0–100.

## Usage

``` r
compute_disturbance(daily_dist, rot_bounds)
```

## Arguments

- daily_dist:

  A daily disturbance table produced by
  [`prepare_shmi_inputs()`](https://danielmanter-usda.github.io/SHMI/reference/prepare_shmi_inputs.md),
  containing:

  - `MGT_combo` — management unit identifier

  - `date` — calendar date

  - `SD_mixeff` — mixing efficiency (0–1)

  - `SD_depth_cm` — tillage depth in cm (already capped at 30)

- rot_bounds:

  A data frame with rotation bounds for each management unit,
  containing:

  - `MGT_combo`

  - `rot_start`

  - `rot_end`

## Value

A data frame with:

- `MGT_combo`

- `InvDist` — inverse disturbance score (0–100)

## Details

Disturbance is computed using a mechanistic soil-mixing model:

1.  **Depth normalization**: Tillage depth is converted to cm and capped
    at 30 cm.

2.  **Annual ordering**: Within each year, disturbance events are
    ordered by depth and mixing efficiency.

3.  **Cumulative mechanical energy**: \$\$ ME_i = SD\\mixeff_i \times
    SD\\depth\\cm_i \$\$ \$\$ cumME_i = \sum\_{j \< i} ME_j \$\$

4.  **Profile penetration (T_t)**: \$\$ T\_{t,i} = SD\\mixeff_i \times
    \max(0, SD\\depth\\cm_i - cumME_i) \$\$ \$\$ T\_{t,i}^{norm} =
    T\_{t,i} / 30 \$\$

5.  **Annual disturbance**: \$\$ T_t^{annual} = \sum_i T\_{t,i}^{norm}
    \$\$

6.  **Inverse disturbance**: \$\$ T_t^{inv} = 1 - T_t^{annual} \$\$

7.  **Rotation average**: Annual inverse disturbance is averaged across
    all rotation years and scaled to 0–100.

If a management unit has no disturbance events, its inverse disturbance
is defined as 100 (no disturbance).
