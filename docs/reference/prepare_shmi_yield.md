# Prepare crop-specific yield data for SHMI analysis

Reads the \`Crop_Diversity\` sheet from an SHMI Excel template, extracts
yield information, validates units and structure, and computes
per-management-unit \*and per-crop\* yield statistics including mean
yield, variance, coefficient of variation, and Taylor's law parameters.

## Usage

``` r
prepare_shmi_yield(
  path,
  exclude = NULL,
  verbose = TRUE,
  start_date_override = NULL,
  end_date_override = NULL
)
```

## Arguments

- path:

  Path to an SHMI Excel template (e.g., \`"SHMI_template.xlsx"\`).

- exclude:

  Optional character vector of \`MGT_combo\` identifiers to exclude from
  the yield summary.

- verbose:

  Logical; print progress messages? Default \`TRUE\`.

- start_date_override:

  Optional date (YYYY-MM-DD) to override the earliest allowable date for
  yield records.

- end_date_override:

  Optional date (YYYY-MM-DD) to override the latest allowable date for
  yield records.

## Value

A tibble with one row per \`(MGT_combo, crop)\` containing:

- `MGT_combo`

- `crop` — crop name (CD_name)

- `n_years`

- `mean_yield`

- `var_yield`

- `cv_yield`

- `log_mean`

- `log_var`

- `yield_units`

## Details

This function mirrors the structure and validation workflow of
\`prepare_shmi_inputs()\`, but focuses exclusively on yield. It is
intentionally separate from the SHMI core so that yield remains optional
and analysis-focused.
