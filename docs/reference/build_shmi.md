# Build SHMI Scores from Prepared Inputs

Computes the Soil Health Management Index (SHMI) for each management
unit (\`MGT_combo\`) using the harmonized inputs produced by
[`prepare_shmi_inputs()`](https://danielmanter-usda.github.io/SHMI/reference/prepare_shmi_inputs.md).
SHMI is a weighted composite of four sub-indices: cover, diversity,
inverse disturbance, and organic inputs (amendments + animals). By
default, the function uses the official national SHMI settings (locked
mode). In expert mode, users may override settings, but resulting scores
are no longer comparable to the national SHMI scale.

## Usage

``` r
build_shmi(shmi_inputs, settings = NULL, expert_mode = FALSE)
```

## Arguments

- shmi_inputs:

  A list returned by
  [`prepare_shmi_inputs()`](https://danielmanter-usda.github.io/SHMI/reference/prepare_shmi_inputs.md),
  containing at minimum:

  - `rot_bounds` — rotation start/end dates

  - `crop_harmonized` — harmonized crop windows

  - `daily` — daily crop presence table

  - `daily_dist` — daily disturbance table

  - `amend` — amendment events

  - `animal` — animal events

  Additional optional elements:

  - `yield` — crop-event-level yield data (kg/ha), if
    `calc_yield = TRUE` in
    [`prepare_shmi_inputs()`](https://danielmanter-usda.github.io/SHMI/reference/prepare_shmi_inputs.md)

  - `n_rate` — year-level nitrogen application data (kg N/ha), if
    `calc_n_rate = TRUE` in
    [`prepare_shmi_inputs()`](https://danielmanter-usda.github.io/SHMI/reference/prepare_shmi_inputs.md)

- settings:

  Optional named list of SHMI settings (seasonal cover weights, Hill
  number, max diversity, pillar weights, etc.). Ignored unless
  `expert_mode = TRUE`. Missing elements are filled with official
  defaults.

- expert_mode:

  Logical; if `FALSE` (default), SHMI is computed using official
  national settings and any custom `settings` are ignored. If `TRUE`,
  custom settings are allowed but the resulting SHMI values are not
  comparable to the national SHMI scale.

## Value

A list with:

- `indicator_df` — data frame with columns: `MGT_combo`, `SHMI`,
  `Cover`, `Diversity`, `InvDist`, `OrgInputs`, and (if available) yield
  and N-rate summaries.

- `yield_summary` — rotation-level yield summaries (or `NULL`)

- `n_rate_summary` — rotation-level N-rate summaries (or `NULL`)

- `settings_used` — the settings actually applied

- `expert_mode` — logical flag

- `shmi_version` — version string for reproducibility

- `timestamp` — computation time

## Details

Optionally, if yield or nitrogen-rate data were computed in
[`prepare_shmi_inputs()`](https://danielmanter-usda.github.io/SHMI/reference/prepare_shmi_inputs.md)
(via `calc_yield = TRUE` or `calc_n_rate = TRUE`), this function also
produces rotation-level summaries of yield (kg/ha) and nitrogen
application rate (kg N/ha). These summaries are merged into the final
SHMI output and returned as separate tables for downstream modeling
(e.g., N-response curves, ANOVA at N100, yield stability analysis).

The SHMI computation proceeds in five stages:

1.  **Settings**: In locked mode, the official national SHMI settings
    are always used. In expert mode, user-supplied settings override
    defaults.

2.  **Input validation**: Ensures that all required elements from
    [`prepare_shmi_inputs()`](https://danielmanter-usda.github.io/SHMI/reference/prepare_shmi_inputs.md)
    are present and structurally valid.

3.  **Pillar computation**:

    - Cover — via
      [`compute_cover()`](https://danielmanter-usda.github.io/SHMI/reference/compute_cover.md)

    - Diversity — via
      [`compute_diversity()`](https://danielmanter-usda.github.io/SHMI/reference/compute_diversity.md)

    - Inverse disturbance — via
      [`compute_disturbance()`](https://danielmanter-usda.github.io/SHMI/reference/compute_disturbance.md)

    - Organic inputs — via
      [`compute_orginput()`](https://danielmanter-usda.github.io/SHMI/reference/compute_orginput.md)

4.  **Weighted combination**: Sub-indices are normalized so their
    weights sum to 1, then combined into a single SHMI score: \$\$ SHMI
    = w\_{cover} \cdot Cover + w\_{div} \cdot Diversity + w\_{dist}
    \cdot InvDist + w\_{orginput} \cdot OrgInputs \$\$

5.  **Optional rotation-level summaries**: If yield or nitrogen-rate
    data are present in `shmi_inputs`, the function computes
    rotation-level summaries:

    - `yield_mean`, `yield_var`, `yield_min`, `yield_max`, `yield_n`

    - `n_rate_mean`, `n_rate_var`, `n_rate_min`, `n_rate_max`, `n_years`

    These summaries are merged into the final SHMI table and also
    returned separately for downstream analysis.

6.  **Output assembly**: Returns a tidy data frame of SHMI scores along
    with metadata describing the settings used and computation
    timestamp.
