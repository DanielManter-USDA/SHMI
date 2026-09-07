# Build SHMI Scores from Prepared Inputs

Computes the Soil Health Management Index (SHMI) for each management
unit (\`MGT_combo\`) using harmonized rotation‑scale inputs produced by
[`prepare_shmi_inputs()`](https://danielmanter-usda.github.io/SHMI/reference/prepare_shmi_inputs.md).
SHMI is a weighted composite of four sub‑indices:

## Usage

``` r
build_shmi(
  shmi_inputs,
  dist_meth = c("EPA", "STIR"),
  settings = NULL,
  expert_mode = FALSE
)
```

## Arguments

- shmi_inputs:

  A list returned by
  [`prepare_shmi_inputs()`](https://danielmanter-usda.github.io/SHMI/reference/prepare_shmi_inputs.md)
  containing harmonized rotation‑scale inputs (see Details).

- dist_meth:

  Disturbance method: `"EPA"` or `"STIR"`.

- settings:

  Optional named list of SHMI settings. Ignored unless
  `expert_mode = TRUE`.

- expert_mode:

  Logical; if `TRUE`, user‑supplied settings override official defaults.

## Value

A list with:

- `indicator_df` — data frame with: `MGT_combo`, `SHMI`, `Cover`,
  `Diversity`, `InvDist`, `OrgInput`, and available metadata.

- `settings_used` — settings actually applied

- `expert_mode` — logical flag

- `shmi_version` — version string

- `timestamp` — computation time

## Details

- **Cover** — season‑weighted plant presence

- **Diversity** — rotation‑scale crop diversity (Hill numbers)

- **Inverse disturbance** — EPA mechanistic or STIR method

- **Organic inputs** — amendments + animal integration

By default, SHMI is computed using the official national settings
(“locked mode”). In expert mode, users may override any setting, but the
resulting SHMI values are no longer comparable to the national SHMI
scale.

\## Required inputs

The function expects a list returned by
[`prepare_shmi_inputs()`](https://danielmanter-usda.github.io/SHMI/reference/prepare_shmi_inputs.md)
with:

- `rot_bounds` — rotation start/end dates and rotation years

- `crop` — harmonized crop windows (one row per species)

- `dist` — disturbance events (EPA/STIR inputs)

- `amend` — amendment events

- `animal` — animal integration events

- `mgt` — management metadata (study, farm, field, treatment)

\## Disturbance method

Disturbance can be computed using:

- `"EPA"` — mechanistic soil‑mixing model (profile penetration)

- `"STIR"` — daily summed mixing efficiency (SD_mixeff)

Both methods classify annual tillage intensity using the modified Tier‑3
Z–K scheme and compute inverse disturbance on a 0–100 scale.

\## Settings and expert mode

In locked mode (`expert_mode = FALSE`), SHMI uses the official national
settings:

- seasonal cover weights

- Hill‑number order and maximum diversity

- STIR normalization constant

- amendment/animal weights

- pillar weights for SHMI aggregation

In expert mode, user‑supplied settings override defaults. Missing
settings are filled from the official values.

\## SHMI computation workflow

1.  **Settings**: locked mode vs expert mode.

2.  **Input validation**: structural checks on all required inputs.

3.  **Pillar computation**:

    - Cover —
      [`compute_cover()`](https://danielmanter-usda.github.io/SHMI/reference/compute_cover.md)

    - Diversity —
      [`compute_diversity()`](https://danielmanter-usda.github.io/SHMI/reference/compute_diversity.md)

    - Inverse disturbance —
      [`compute_disturbance()`](https://danielmanter-usda.github.io/SHMI/reference/compute_disturbance.md)

    - Organic inputs —
      [`compute_orginput()`](https://danielmanter-usda.github.io/SHMI/reference/compute_orginput.md)

4.  **Weighted combination**: Pillar scores are normalized so weights
    sum to 1, then combined:

    \$\$ SHMI = w\_{cover} \cdot Cover + w\_{div} \cdot Diversity +
    w\_{dist} \cdot InvDist + w\_{ani} \cdot OrgInput \$\$

5.  **Output assembly**: Returns a tidy data frame of SHMI scores and
    metadata describing the settings used, SHMI version, and computation
    timestamp.
