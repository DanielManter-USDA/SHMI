# Validate SHMI Excel Input File

Validates the raw Excel file supplied to \`prepare_shmi_inputs()\`. This
function checks for required sheets, required columns, valid date
formats, missing or invalid \`MGT_combo\` values, malformed mixtures,
species lookup consistency, and rotation boundary completeness. It is
designed to fail early and explicitly before any ingestion or
harmonization occurs.

## Usage

``` r
validate_excel_input(path)
```

## Arguments

- path:

  Character string. Path to the Excel file supplied by the user.

## Value

A list with:

- ok:

  Logical. TRUE if validation passed; FALSE otherwise.

- errors:

  Character vector of critical validation failures.

- warnings:

  Character vector of non-fatal issues.

- summary:

  A tibble summarizing sheet counts and row counts.
