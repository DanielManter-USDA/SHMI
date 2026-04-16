# Prepare and Validate SHMI Input Data from an Excel Workbook

Reads, validates, harmonizes, and expands all input sheets required to
compute the Soil Health Management Index (SHMI). This function is the
official entry point for SHMI data preparation and produces a
standardized list of objects used directly by
[`build_shmi()`](https://danielmanter-usda.github.io/SHMI/reference/build_shmi.md).

## Usage

``` r
prepare_shmi_inputs(
  path,
  exclude = NULL,
  verbose = TRUE,
  start_date_override = NULL,
  end_date_override = NULL
)
```

## Arguments

- path:

  Path to the SHMI Excel workbook. Must contain the standard SHMI
  sheets: `Mgt_Unit`, `Crop_Diversity`, `Soil_Disturbance`,
  `Amendment_Diversity`, and `Animal_Diversity`. Sheets may be empty;
  empty sheets are safely ignored.

- exclude:

  Optional character vector of `MGT_combo` identifiers to exclude from
  processing. Default is `NULL`.

- verbose:

  Logical; if `TRUE` (default), prints progress messages describing
  sheet ingestion, validation steps, and grid construction.

- start_date_override:

  Optional `Date` or date‑coercible value. If supplied, all crop,
  disturbance, amendment, and animal events occurring before this date
  are removed, and rotation bounds are clipped accordingly.

- end_date_override:

  Optional `Date` or date‑coercible value. If supplied, all events
  occurring after this date are removed, and rotation bounds are clipped
  accordingly.

## Value

A named list containing:

- `rot_bounds`:

  Rotation start/end dates for each `MGT_combo`.

- `crop_harmonized`:

  One row per crop event with harmonized start/end dates.

- `daily`:

  Daily crop‑presence grid (one row per day).

- `daily_dist`:

  Daily disturbance table with mixing efficiency and depth (cm).

- `mgt`:

  Management‑unit metadata.

- `crop`:

  Validated crop event table.

- `dist`:

  Disturbance event table.

- `amend`:

  Amendment event table.

- `animal`:

  Animal event table.

## Details

The function performs:

- robust Excel ingestion with sheet‑level validation

- management‑unit filtering

- crop‑level biological validation (chronology, annual/perennial rules)

- harmonization of crop windows across mixtures

- construction of rotation bounds

- daily grid expansion (fast vectorized implementation)

- mechanistic daily disturbance processing (mixing efficiency × depth)

- assembly of amendment and animal event tables

The function enforces biologically realistic crop windows, including:

- annual crops must terminate within the same year

- perennials may span years but must follow valid chronology

- mixtures are collapsed to event‑level windows

Rotation bounds are computed from all available event types (crop,
disturbance, amendment, animal). Empty sheets contribute no bounds.

Daily grids are generated using a fully vectorized expansion, ensuring
extremely fast performance even for large datasets.

Additionally, this function automatically performs front‑end validation
of the Excel input file using
[`validate_excel_input()`](https://danielmanter-usda.github.io/SHMI/reference/validate_excel_input.md).
The validator checks for required sheets, required columns, valid date
formats, consistent `MGT_combo` values, and malformed entries before any
ingestion or harmonization occurs.

If validation fails, execution stops immediately with clear, actionable
error messages. Users must correct the Excel file before re‑running
`prepare_shmi_inputs()`.

## Error Handling

The function stops with informative errors if:

- required sheets are missing

- required columns are missing

- crop chronology is biologically impossible

- date overrides produce empty rotations

## See also

[`build_shmi`](https://danielmanter-usda.github.io/SHMI/reference/build_shmi.md)
for computing SHMI scores from the returned object.
