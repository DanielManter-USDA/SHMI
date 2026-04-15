# SHMI: Soil Health Management Index

The \*\*SHMI\*\* package provides a complete, reproducible workflow for
computing the Soil Health Management Index (SHMI) from standardized
Excel workbooks. SHMI is a composite indicator integrating four
management pillars:

## Details

- **Cover** — seasonal plant presence

- **Diversity** — rotation-scale crop diversity (Hill numbers)

- **Inverse Disturbance** — mechanistic mixing-efficiency × depth metric

- **Organic Inputs** — amendments and animal presence

The package includes:

- robust input validation and harmonization

- biologically realistic crop-window processing

- fast vectorized daily-grid construction

- mechanistic disturbance modeling

- rotation-scale aggregation

- official national SHMI settings (locked mode)

- expert-mode overrides for research and scenario analysis

## Workflow

A complete SHMI workflow consists of:

1.  **Prepare inputs**
    [`prepare_shmi_inputs()`](https://danielmanter-usda.github.io/SHMI/reference/prepare_shmi_inputs.md)
    Reads and validates the Excel workbook, harmonizes crop windows,
    constructs rotation bounds, and generates daily grids.

2.  **Compute SHMI**
    [`build_shmi()`](https://danielmanter-usda.github.io/SHMI/reference/build_shmi.md)
    Computes all four pillars and combines them into a final SHMI score.

3.  **Interpret results** The returned object includes pillar scores,
    final SHMI values, settings used, and a timestamp for
    reproducibility.

## Settings

By default, SHMI is computed using the official national settings
(locked mode). Setting `expert_mode = TRUE` allows users to override
weights and parameters, but resulting SHMI values are not comparable to
the national SHMI scale.

## Versioning and Reproducibility

All SHMI outputs include:

- `shmi_version` — version of the SHMI algorithm

- `timestamp` — computation time

- `settings_used` — full list of settings applied

## Key Functions

- [`prepare_shmi_inputs`](https://danielmanter-usda.github.io/SHMI/reference/prepare_shmi_inputs.md)
  — read, validate, harmonize inputs

- [`build_shmi`](https://danielmanter-usda.github.io/SHMI/reference/build_shmi.md)
  — compute SHMI scores

- [`compute_w.cover`](https://danielmanter-usda.github.io/SHMI/reference/compute_w.cover.md)
  — cover pillar

- [`compute_rot_diversity`](https://danielmanter-usda.github.io/SHMI/reference/compute_rot_diversity.md)
  — diversity pillar

- [`compute_avg_annual_disturbance`](https://danielmanter-usda.github.io/SHMI/reference/compute_avg_annual_disturbance.md)
  — inverse disturbance pillar

- [`compute_orginput`](https://danielmanter-usda.github.io/SHMI/reference/compute_orginput.md)
  — organic inputs pillar
