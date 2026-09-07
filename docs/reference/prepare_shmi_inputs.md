# Prepare and Validate SHMI Input Data from an Excel Workbook

Reads, validates, harmonizes, and expands all input sheets required to
compute the Soil Health Management Index (SHMI). This function is the
official entry point for SHMI data preparation and produces a
standardized list of rotation‑scale objects used directly by
[`build_shmi()`](https://danielmanter-usda.github.io/SHMI/reference/build_shmi.md).

## Usage

``` r
prepare_shmi_inputs(
  path,
  exclude = NULL,
  verbose = TRUE,
  rot_calc = c("napeshm", "farmer"),
  start_date_override = NULL,
  end_date_override = NULL,
  end_sample_date = FALSE,
  calc_yield = FALSE,
  calc_n_rate = FALSE
)
```

## Arguments

- path:

  Path to the SHMI Excel workbook.

- exclude:

  Optional character vector of `MGT_combo` identifiers to exclude from
  processing.

- verbose:

  Logical; if `TRUE`, prints progress messages.

- start_date_override:

  Optional `Date` or date‑coercible value.

- end_date_override:

  Optional `Date` or date‑coercible value.

- calc_yield:

  Logical; if `TRUE`, extract and standardize yield.

- calc_n_rate:

  Logical; if `TRUE`, extract and standardize N‑rate.

## Value

A named list containing:

- `rot_bounds`:

  Rotation start/end dates and rotation years.

- `crop`:

  Mixture‑aware crop windows (one row per species).

- `dist`:

  Disturbance event table (EPA/STIR‑ready).

- `amend`:

  Amendment event table.

- `animal`:

  Animal event table.

- `mgt`:

  Management‑unit metadata.

- `yield`:

  Optional crop‑event‑level yield table (kg/ha).

- `n_rate`:

  Optional year‑level nitrogen‑rate table (kg N/ha).

## Details

\## Overview

The function performs:

- robust Excel ingestion with sheet‑level validation

- management‑unit filtering

- biological validation of crop chronology (annual/perennial rules)

- mixture‑aware harmonization of crop windows

- construction of rotation bounds (start/end dates and rotation years)

- assembly of disturbance, amendment, and animal event tables

- optional extraction of yield and nitrogen‑rate data

- override‑aware clipping of all event types

The result is a clean, rotation‑scale dataset suitable for SHMI pillar
computation: cover, diversity, inverse disturbance, and organic inputs.

\## Required workbook structure

The Excel file must contain the standard SHMI sheets:

- `Mgt_Unit`

- `Crop_Diversity`

- `Soil_Disturbance`

- `Amendment_Diversity`

- `Animal_Diversity`

Sheets may be empty; empty sheets are safely ignored.

\## Date overrides

If `start_date_override` or `end_date_override` are supplied, all event
types (crop, disturbance, amendment, animal, yield, N‑rate) occurring
outside the override window are removed, and rotation bounds are clipped
accordingly.

\## Crop harmonization

Crop windows are validated for biological realism:

- annual crops must terminate within the same year

- perennials may span years but must follow valid chronology

- mixtures are collapsed to event‑level windows (min start, max end)

The returned `crop` table contains one row per species with harmonized
start/end dates suitable for cover and diversity scoring.

\## Disturbance, amendments, and animals

Disturbance events are returned in EPA/STIR‑ready format:

- `SD_date`

- `SD_mixeff`

- `SD_depth`

Amendment and animal events are clipped by overrides and returned in
rotation‑scale format for
[`compute_orginput()`](https://danielmanter-usda.github.io/SHMI/reference/compute_orginput.md).

\## Optional yield and nitrogen‑rate extraction

If enabled:

- Yield is extracted per crop event, unit‑standardized to kg/ha, and
  clipped by overrides.

- Nitrogen rate is extracted from amendment events, converted to kg
  N/ha, summarized per `MGT_combo × year`, and clipped by overrides.

Missing values are retained as `NA`.

\## Front‑end validation

The function automatically runs
[`validate_excel_input()`](https://danielmanter-usda.github.io/SHMI/reference/validate_excel_input.md)
to check:

- required sheets and columns

- valid date formats

- consistent `MGT_combo` values

- malformed entries

If validation fails, execution stops with clear, actionable error
messages.

## Error Handling

The function stops with informative errors if:

- required sheets or columns are missing

- crop chronology is biologically impossible

- date overrides produce empty rotations

## See also

[`build_shmi`](https://danielmanter-usda.github.io/SHMI/reference/build_shmi.md)
for computing SHMI scores from prepared inputs.
