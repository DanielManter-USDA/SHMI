# SHMI: Soil Health Management Index

Computes the Soil Health Management Index (SHMI) from management records
entered in a standard Excel workbook. SHMI is a 0-100 composite of four
sub-indices:

## Details

- **Cover**: season-weighted proportion of days with living plants.

- **Diversity**: rotation-scale crop diversity.

- **Inverse disturbance**: soil disturbance from tillage, by the EPA
  soil-mixing model or STIR.

- **Organic inputs**: organic amendments and animal integration.

## Workflow

1.  [`download_shmi_template()`](https://danielmanter-usda.github.io/SHMI/reference/download_shmi_template.md)
    provides a blank workbook, and
    [`download_shmi_example()`](https://danielmanter-usda.github.io/SHMI/reference/download_shmi_example.md)
    a completed one;
    [`get_shmi_example()`](https://danielmanter-usda.github.io/SHMI/reference/get_shmi_example.md)
    gives the path of the installed example.

2.  [`prepare_shmi_inputs()`](https://danielmanter-usda.github.io/SHMI/reference/prepare_shmi_inputs.md)
    reads and validates the workbook, converts crop records into species
    episodes, and records every assumption it makes.

3.  [`build_shmi()`](https://danielmanter-usda.github.io/SHMI/reference/build_shmi.md)
    computes the four sub-indices and SHMI.

4.  [`plot_shmi_gauge()`](https://danielmanter-usda.github.io/SHMI/reference/plot_shmi_gauge.md)
    and
    [`plot_shmi_lollipop()`](https://danielmanter-usda.github.io/SHMI/reference/plot_shmi_lollipop.md)
    display the results.

The sub-indices can also be computed directly with
[`compute_cover()`](https://danielmanter-usda.github.io/SHMI/reference/compute_cover.md),
[`compute_diversity()`](https://danielmanter-usda.github.io/SHMI/reference/compute_diversity.md),
[`compute_disturbance()`](https://danielmanter-usda.github.io/SHMI/reference/compute_disturbance.md),
and
[`compute_orginput()`](https://danielmanter-usda.github.io/SHMI/reference/compute_orginput.md).

## Design principles

- **Missing records mean "did not happen".** No disturbance record means
  no disturbance (InvDist = 100); no crop means no cover; no amendment
  means no organic input.

- **The evaluation window is set by the data or by overrides.** Rotation
  bounds span the first to the last recorded event unless
  `start_date_override` / `end_date_override` are given to
  [`prepare_shmi_inputs()`](https://danielmanter-usda.github.io/SHMI/reference/prepare_shmi_inputs.md).

- **Assumptions are reported, not hidden.** Every imputed date and every
  value that could not be converted is listed in
  `prepare_shmi_inputs()$assumptions`.

## Settings

By default,
[`build_shmi()`](https://danielmanter-usda.github.io/SHMI/reference/build_shmi.md)
uses the official national settings ("locked mode"). With
`expert_mode = TRUE`, weights and parameters can be changed, but the
resulting scores are not comparable to the national SHMI scale. Each
result records the settings used, the package version, and a timestamp.

## See also

Useful links:

- <https://danielmanter-usda.github.io/SHMI/>

- <https://github.com/DanielManter-USDA/SHMI>

- Report bugs at <https://github.com/DanielManter-USDA/SHMI/issues>

## Author

**Maintainer**: Daniel Manter <daniel.manter@usda.gov>

Authors:

- Daniel Manter <daniel.manter@usda.gov>

- Jennifer Moore <jennifer.moore2@usda.gov>
