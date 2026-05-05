# Validate SHMI Input Tables

Performs structural and semantic validation of the input data list used
by \`build_shmi()\`. This function checks for required tables, required
columns, valid data types, missing or invalid values, duplicated keys
where they should be unique, and rotation boundary consistency. It
returns a structured list containing validation status, error messages,
warnings, and a summary of key dataset properties.

This validator is designed to fail early and explicitly when critical
issues are detected (e.g., missing \`MGT_combo\`, malformed dates,
invalid crop windows). Non-fatal issues are returned as warnings. A
summary of field counts, years, species richness, mixture counts, and
fallow presence is included for diagnostic transparency.

## Usage

``` r
validate_shmi_input(shmi_inputs)
```

## Arguments

- shmi_inputs:

  A named list of SHMI input tables, typically produced by
  \`prepare_shmi_inputs()\`. Must contain at least:

  mgt

  :   Management table with \`MGT_combo\` and metadata columns.

  crop_harmonized

  :   Tibble of harmonized crop records with \`MGT_combo\`, \`CD_name\`,
      \`CD_seq_num\`, \`crop_start\`, \`crop_end\`.

  rot_bounds

  :   Tibble defining rotation start and end dates for each
      \`MGT_combo\`, with \`MGT_combo\`, \`rot_start\`, \`rot_end\`.

  daily_dist

  :   Daily disturbance table with \`MGT_combo\`, \`date\`, and
      disturbance attributes.

  amend

  :   Amendment events with \`MGT_combo\` and \`SA_date\`.

  animal

  :   Animal events with \`MGT_combo\`, \`AD_start_date\`,
      \`AD_end_date\`.

## Value

A list with:

- ok:

  Logical. \`TRUE\` if validation passed with no errors; \`FALSE\`
  otherwise.

- errors:

  Character vector of critical validation failures. If non-empty,
  \`build_shmi()\` should stop execution.

- warnings:

  Character vector of non-fatal issues.

- summary:

  A tibble summarizing key dataset properties (fields, years, species,
  mixtures, fallow presence).
