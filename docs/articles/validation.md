# SHMI Input Validation

## Overview

SHMI uses a two‑layer validation system to ensure that all inputs are
structurally complete, biologically realistic, and internally consistent
before any SHMI pillars are computed. This prevents silent failures,
protects against malformed Excel files, and guarantees reproducible SHMI
scores.

There are two validators:

1.  [`validate_excel_input()`](https://danielmanter-usda.github.io/SHMI/reference/validate_excel_input.md)
    — runs before ingestion and checks the raw Excel workbook.
2.  [`validate_shmi_input()`](https://danielmanter-usda.github.io/SHMI/reference/validate_shmi_input.md)
    — runs after ingestion and checks the harmonized SHMI data list.

Both validators run automatically inside the SHMI workflow:

    Excel Workbook
          ↓
    validate_excel_input()
          ↓
    prepare_shmi_inputs()
          ↓
    validate_shmi_input()
          ↓
    build_shmi()
          ↓
    SHMI Pillars + Composite Score

------------------------------------------------------------------------

## 1. Excel‑Level Validation (`validate_excel_input()`)

[`validate_excel_input()`](https://danielmanter-usda.github.io/SHMI/reference/validate_excel_input.md)
checks the raw Excel workbook before any processing occurs.

### Required Sheets

The following sheets must be present:

- Mgt_Unit
- Crop_Diversity
- Soil_Disturbance
- Soil_Amendments
- Animal_Diversity
- Soil_Test

Optional sheets:

- User_Info
- Dropdowns_Manual

Missing required sheets cause immediate failure.

### Required Columns

Each sheet must contain specific columns. Examples:

#### Crop_Diversity

- MGT_combo
- CD_seq_num
- CD_mix
- CD_cat
- CD_group
- CD_name
- CD_plant_date
- CD_harv_date
- CD_term_date

#### Soil_Disturbance

- MGT_combo
- SD_phase
- SD_date
- SD_equip_cat
- SD_equip
- SD_mixeff
- SD_depth

Missing columns produce hard errors.

### Date Validation

All date columns must be valid Excel dates. Text dates or mixed formats
cause validation failure.

### MGT_combo Consistency

All sheets must use the same set of MGT_combo identifiers.

Validation fails if:

- a sheet contains MGT_combo not found in Mgt_Unit
- any sheet contains NA in MGT_combo

### Mixture Syntax

`CD_mix` must be:

- “No”, or
- a valid mixture containing “+”, or
- empty

Malformed entries such as “++”, “Corn+”, or “+Rye” produce warnings.

### Stray Rows

Blank or partially blank rows are detected and reported.

### Example

``` r
validate_excel_input("my_shmi_file.xlsx")
```

Example output:

    ❌ Excel input validation failed.
    Errors:
     - Sheet Crop_Diversity is missing required columns: cd_term_date
     - Sheet Soil_Disturbance contains NA MGT_combo values

------------------------------------------------------------------------

## 2. Internal Validation (`validate_shmi_input()`)

After ingestion and harmonization,
[`prepare_shmi_inputs()`](https://danielmanter-usda.github.io/SHMI/reference/prepare_shmi_inputs.md)
produces a structured list of SHMI tables. Before computing pillars,
[`build_shmi()`](https://danielmanter-usda.github.io/SHMI/reference/build_shmi.md)
validates this list using
[`validate_shmi_input()`](https://danielmanter-usda.github.io/SHMI/reference/validate_shmi_input.md).

### Required Tables

- rot_bounds
- crop_harmonized
- daily
- daily_dist
- amend
- animal

Missing tables produce hard errors.

### Required Columns

Each table must contain specific columns. Examples:

#### daily

- MGT_combo
- date
- CD_name
- crop_present

#### rot_bounds

- MGT_combo
- rot_start
- rot_end

### Duplicate Daily Rows

Duplicate `(MGT_combo, date)` rows are not allowed.

### Date Types

All date columns must be of class `Date`.

### Biological Chronology

- annual crops must terminate within the same year
- perennials may span years but must follow valid chronology
- mixtures must collapse to valid windows

### Example

``` r
val <- validate_shmi_input(dat)
print(val$summary)
```

Example output:

    fields: 12
    years: 5
    species: 8
    mixtures: 0
    fallow_days: 0

------------------------------------------------------------------------

## 3. Automatic Validation in the SHMI Workflow

Users normally do not call the validators directly.

They run automatically:

#### Inside `prepare_shmi_inputs()`

``` r
validate_excel_input(path)
```

#### Inside `build_shmi()`

``` r
validate_shmi_input(shmi_inputs)
```

If validation fails at either stage, execution stops with clear,
actionable messages.

------------------------------------------------------------------------

## 4. Common Validation Errors and Fixes

### Missing Sheets

**Error**

    Missing required sheets: Crop_Diversity, Soil_Amendments

**Fix**  
Add the missing sheets.

------------------------------------------------------------------------

### Missing Columns

**Error**

    Sheet Soil_Disturbance is missing required columns: sd_depth

**Fix**  
Add the missing column.

------------------------------------------------------------------------

### Invalid Dates

**Error**

    Column cd_plant_date in sheet Crop_Diversity is not a valid Date

**Fix**  
Format the column as an Excel date.

------------------------------------------------------------------------

### Unknown Species

**Error**

    Species in Crop_Diversity not found in Species_Lookup: Mustard, Rye

**Fix**  
Add missing species to the lookup table.

------------------------------------------------------------------------

## 5. Summary

SHMI’s two‑layer validation system ensures:

- clean Excel files  
- biologically realistic crop windows  
- consistent MGT_combo identifiers  
- valid dates  
- no silent failures  
- reproducible SHMI scores

------------------------------------------------------------------------

## 6. See Also

- [`validate_excel_input()`](https://danielmanter-usda.github.io/SHMI/reference/validate_excel_input.md)
- [`validate_shmi_input()`](https://danielmanter-usda.github.io/SHMI/reference/validate_shmi_input.md)
- [`prepare_shmi_inputs()`](https://danielmanter-usda.github.io/SHMI/reference/prepare_shmi_inputs.md)
- [`build_shmi()`](https://danielmanter-usda.github.io/SHMI/reference/build_shmi.md)
