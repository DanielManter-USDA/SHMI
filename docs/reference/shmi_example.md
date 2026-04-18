# Example SHMI dataset

A small example dataset included with the SHMI package for demonstrating
the minimal R-native workflow:

## Usage

``` r
data(shmi_example)
```

## Format

A data frame with X rows and Y variables:

- MGT_combo:

  Management unit identifier

- date:

  Calendar date

- CD_name:

  Crop or mixture name

- crop_present:

  1 if crop present, 0 otherwise

- SD_mixeff:

  Mixing efficiency (if present)

- SD_depth_cm:

  Tillage depth in cm (if present)

- ...:

  Additional variables depending on the example

## Details

“\` data(shmi_example) inputs \<- prepare_shmi_inputs(shmi_example)
result \<- build_shmi(inputs) “\`

This dataset is a simplified, single-table representation of the SHMI
input structure. It is intended for quick examples, teaching, and unit
tests. For the full Excel-based workflow, use
\[\`download_shmi_example()\`\] or \[\`download_shmi_template()\`\].

## See also

\[prepare_shmi_inputs()\], \[build_shmi()\],
\[download_shmi_example()\], \[download_shmi_template()\]

Other SHMI helper functions:
[`download_shmi_example()`](https://danielmanter-usda.github.io/SHMI/reference/download_shmi_example.md),
[`download_shmi_template()`](https://danielmanter-usda.github.io/SHMI/reference/download_shmi_template.md)
