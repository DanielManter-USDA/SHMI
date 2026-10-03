# Package index

## Core Workflow

- [`prepare_shmi_inputs()`](https://danielmanter-usda.github.io/SHMI/reference/prepare_shmi_inputs.md)
  : Read, validate, and prepare SHMI inputs from an Excel workbook
- [`get_shmi_climate()`](https://danielmanter-usda.github.io/SHMI/reference/get_shmi_climate.md)
  : Monthly climate normals for SHMI's Cover seasons
- [`build_shmi()`](https://danielmanter-usda.github.io/SHMI/reference/build_shmi.md)
  : Compute SHMI scores
- [`shmi_weights()`](https://danielmanter-usda.github.io/SHMI/reference/shmi_weights.md)
  : Official SHMI weights

## Tillage (T-DISC)

USDA T-DISC implement values and operation names used to compute tillage
intensity.

- [`tdisc_implements()`](https://danielmanter-usda.github.io/SHMI/reference/tdisc_implements.md)
  : T-DISC implement values
- [`tdisc_mapping()`](https://danielmanter-usda.github.io/SHMI/reference/tdisc_mapping.md)
  : Operation names translated to T-DISC implements

## Climate

Monthly climate normals and the growing-season months they define for
Cover.

- [`growing_months()`](https://danielmanter-usda.github.io/SHMI/reference/growing_months.md)
  : Growing-season months from monthly climate normals

## Sub-index Functions

- [`compute_cover()`](https://danielmanter-usda.github.io/SHMI/reference/compute_cover.md)
  : Compute the Cover sub-index
- [`compute_diversity()`](https://danielmanter-usda.github.io/SHMI/reference/compute_diversity.md)
  : Compute the Diversity sub-index
- [`compute_disturbance()`](https://danielmanter-usda.github.io/SHMI/reference/compute_disturbance.md)
  : Compute the Inverse Disturbance sub-index
- [`compute_orginput()`](https://danielmanter-usda.github.io/SHMI/reference/compute_orginput.md)
  : Compute the Organic Inputs sub-index

## Components

All four sub-indices at once, and the monthly and yearly components of
Cover and Organic Inputs, for calibration or inspection.

- [`shmi_components()`](https://danielmanter-usda.github.io/SHMI/reference/shmi_components.md)
  : The four SHMI sub-indices for each management unit
- [`compute_cover_monthly()`](https://danielmanter-usda.github.io/SHMI/reference/compute_cover_monthly.md)
  : Plant days and window days by calendar month
- [`compute_orginput_components()`](https://danielmanter-usda.github.io/SHMI/reference/compute_orginput_components.md)
  : Years with organic amendments and animals

## Helper Functions

- [`clip_crop_to_rotation()`](https://danielmanter-usda.github.io/SHMI/reference/clip_crop_to_rotation.md)
  : Clip crop episodes to each unit's rotation window
- [`download_shmi_example()`](https://danielmanter-usda.github.io/SHMI/reference/download_shmi_example.md)
  : Download the example SHMI Excel workbook
- [`download_shmi_template()`](https://danielmanter-usda.github.io/SHMI/reference/download_shmi_template.md)
  : Download a blank SHMI Excel template
- [`get_shmi_example()`](https://danielmanter-usda.github.io/SHMI/reference/get_shmi_example.md)
  : Path to the example SHMI workbook

## Validation Functions

- [`validate_excel_input()`](https://danielmanter-usda.github.io/SHMI/reference/validate_excel_input.md)
  : Validate an SHMI Excel workbook
- [`validate_shmi_input()`](https://danielmanter-usda.github.io/SHMI/reference/validate_shmi_input.md)
  : Validate prepared SHMI inputs

## Plotting Functions

- [`plot_shmi_gauge()`](https://danielmanter-usda.github.io/SHMI/reference/plot_shmi_gauge.md)
  : Plot gauges of SHMI and its sub-indices for one management unit
- [`plot_shmi_lollipop()`](https://danielmanter-usda.github.io/SHMI/reference/plot_shmi_lollipop.md)
  : Plot SHMI across management units
