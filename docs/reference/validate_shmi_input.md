# Validate SHMI Input Tables

Performs structural and semantic validation of the input data list used
by \`build_shmi()\`. This function checks for required tables, required
columns, valid data types, missing or invalid values, duplicated rows,
and rotation boundary consistency. It returns a structured list
containing validation status, error messages, warnings, and a summary of
key dataset properties.

This validator is designed to fail early and explicitly when critical
issues are detected (e.g., missing \`MGT_combo\`, malformed dates,
duplicated daily rows). Non-fatal issues are returned as warnings. A
summary of field counts, years, species richness, mixture counts, and
fallow days is included for diagnostic transparency.

## Usage

``` r
validate_shmi_input(shmi_inputs)
```

## Arguments

- dat:

  A named list of SHMI input tables, typically produced by
  \`prepare_shmi_inputs()\`. Must contain at least:

  crop_harmonized

  :   A tibble of harmonized crop records with \`MGT_combo\`, \`date\`,
      and \`CD_name\`.

  daily

  :   A tibble of daily crop presence with \`MGT_combo\`, \`date\`,
      \`CD_name\`, and \`crop_present\`.

  rot_bounds

  :   A tibble defining rotation start and end dates for each
      \`MGT_combo\`, with columns \`rot_start\` and \`rot_end\`.

## Value

A list with the following elements:

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
  mixtures, fallow days).

## Details

This function enforces SHMI input integrity by checking:

- Presence of required tables and columns.

- No missing \`MGT_combo\` values.

- All date columns are of class \`Date\`.

- Rotation boundaries are valid (\`rot_start\` ≤ \`rot_end\`).

- No duplicated \`(MGT_combo, date)\` rows in the daily table.

- \`crop_present\` contains only 0, 1, or \`NA\`.

- Basic dataset diagnostics (fields, years, species richness, mixtures).

## Examples

``` r
if (FALSE) { # \dontrun{
dat <- prepare_shmi_inputs("path/to/input/folder")
val <- validate_shmi_input(dat)
if (!val$ok) stop("Validation failed:\n", paste(val$errors, collapse = "\n"))
print(val$summary)
} # }
```
