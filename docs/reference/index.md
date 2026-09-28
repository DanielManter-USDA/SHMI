# Package index

## Core Workflow

- [`prepare_shmi_inputs()`](https://danielmanter-usda.github.io/SHMI/reference/prepare_shmi_inputs.md)
  : Read, validate, and prepare SHMI inputs from an Excel workbook
- [`build_shmi()`](https://danielmanter-usda.github.io/SHMI/reference/build_shmi.md)
  : Compute SHMI scores from prepared inputs

## Sub-index Functions

- [`compute_cover()`](https://danielmanter-usda.github.io/SHMI/reference/compute_cover.md)
  : Compute the Cover sub-index
- [`compute_diversity()`](https://danielmanter-usda.github.io/SHMI/reference/compute_diversity.md)
  : Compute the Diversity sub-index
- [`compute_disturbance()`](https://danielmanter-usda.github.io/SHMI/reference/compute_disturbance.md)
  : Compute the inverse-disturbance sub-index
- [`compute_orginput()`](https://danielmanter-usda.github.io/SHMI/reference/compute_orginput.md)
  : Compute the Organic Inputs sub-index

## Calibration and Diagnostics

Linear components of Cover and Organic Inputs, used to evaluate or
estimate SHMI weights, and a report of records affected by the
evaluation window.

- [`compute_shmi_components()`](https://danielmanter-usda.github.io/SHMI/reference/compute_shmi_components.md)
  : All linear components needed to calibrate SHMI weights
- [`compute_cover_components()`](https://danielmanter-usda.github.io/SHMI/reference/compute_cover_components.md)
  : Seasonal components of the Cover sub-index
- [`compute_orginput_components()`](https://danielmanter-usda.github.io/SHMI/reference/compute_orginput_components.md)
  : Components of the Organic Inputs sub-index
- [`shmi_window_report()`](https://danielmanter-usda.github.io/SHMI/reference/shmi_window_report.md)
  : Report records that fall outside, or straddle, the evaluation window

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
