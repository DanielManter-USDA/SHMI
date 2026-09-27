# Validate an SHMI Excel workbook

Checks a workbook before it is read by
[`prepare_shmi_inputs()`](https://danielmanter-usda.github.io/SHMI/reference/prepare_shmi_inputs.md),
which calls this function automatically.

## Usage

``` r
validate_excel_input(path, verbose = TRUE)
```

## Arguments

- path:

  Path to the SHMI Excel workbook.

- verbose:

  Logical. Report rows removed while reading.

## Value

A list with `ok` (logical), `errors` and `warnings` (character vectors),
and `summary` (a tibble of row counts per sheet; empty if the check
stopped because sheets were missing).

## Details

Errors (validation fails):

- a required sheet is missing, or a required column is missing from a
  non-empty sheet;

- `MGT_combo` is missing in any row, is duplicated in `Mgt_Unit`, or
  does not appear in `Mgt_Unit`;

- a disturbance pass has a missing or unparseable `SD_date`;

- `SD_mixeff` or `SD_depth` is non-numeric or negative.

Warnings (validation passes):

- `SD_depth` greater than 20 inches (possibly entered in cm);

- stray blank rows in `Crop_Diversity`.

Checks that depend on the disturbance method (EPA or STIR) are made
later by
[`validate_shmi_input()`](https://danielmanter-usda.github.io/SHMI/reference/validate_shmi_input.md),
because the method is chosen in
[`build_shmi()`](https://danielmanter-usda.github.io/SHMI/reference/build_shmi.md).

## See also

[`prepare_shmi_inputs()`](https://danielmanter-usda.github.io/SHMI/reference/prepare_shmi_inputs.md),
[`validate_shmi_input()`](https://danielmanter-usda.github.io/SHMI/reference/validate_shmi_input.md)
