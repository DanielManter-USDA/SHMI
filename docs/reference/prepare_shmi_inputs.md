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
  end_date_override = NULL,
  calc_yield = FALSE,
  calc_n_rate = FALSE
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
  disturbance, amendment, animal, yield, and N‑rate events occurring
  before this date are removed, and rotation bounds are clipped
  accordingly.

- end_date_override:

  Optional `Date` or date‑coercible value. If supplied, all events
  occurring after this date are removed, and rotation bounds are clipped
  accordingly.

- calc_yield:

  Logical, default = FALSE. If `TRUE`, yield (kg/ha) is extracted from
  `Crop_Diversity`, clipped by date overrides, unit‑standardized, and
  returned for each `MGT_combo × crop event`. If `FALSE`, yield is not
  processed and the returned list contains `yield = NULL`.

- calc_n_rate:

  Logical, default = FALSE. If `TRUE`, nitrogen rate (kg N/ha) is
  extracted from `Amendment_Diversity`, clipped by date overrides,
  unit‑standardized, and summarized for each `MGT_combo × year`. If
  `FALSE`, N‑rate is not processed and the returned list contains
  `n_rate = NULL`.

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

- `yield`:

  (Optional) Crop‑event‑level yield table (kg/ha), or `NULL` if
  `calc_yield = FALSE`.

- `n_rate`:

  (Optional) Year‑level nitrogen‑rate table (kg N/ha), or `NULL` if
  `calc_n_rate = FALSE`.

## Details

The function performs:

- robust Excel ingestion with sheet‑level validation

- management‑unit filtering

- crop‑level biological validation (chronology, annual/perennial rules)

- harmonization of crop windows across mixtures

- construction of rotation bounds (full‑year expansion)

- daily grid expansion (fast vectorized implementation)

- mechanistic daily disturbance processing (mixing efficiency × depth)

- assembly of amendment and animal event tables

- optional extraction of yield and nitrogen‑rate data

The function enforces biologically realistic crop windows, including:

- annual crops must terminate within the same year

- perennials may span years but must follow valid chronology

- mixtures are collapsed to event‑level windows

Rotation bounds are computed from all available event types (crop,
disturbance, amendment, animal) and expanded to full calendar years to
ensure consistent SHMI computation. Date overrides further restrict all
event types, including optional yield and N‑rate extraction.

Daily grids are generated using a fully vectorized expansion, ensuring
extremely fast performance even for large datasets.

Yield extraction (if enabled) preserves one row per crop event, applies
override‑aware clipping, and converts all supported units to kg/ha.
Missing yield or missing units are retained as `NA`.

Nitrogen‑rate extraction (if enabled) uses the `SA_N` field as the
authoritative N applied, converts units to kg N/ha, clips by overrides,
and returns one row per `MGT_combo × year`. Missing `SA_N` values are
retained as `NA`.

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
for computing SHMI scores and optional rotation‑level summaries of yield
and nitrogen rate.
