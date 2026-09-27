# Read, validate, and prepare SHMI inputs from an Excel workbook

Reads a completed SHMI workbook, validates it, converts crop records
into species episodes, and returns the rotation-scale tables used by
[`build_shmi()`](https://danielmanter-usda.github.io/SHMI/reference/build_shmi.md),
together with a table of every assumption made along the way.

## Usage

``` r
prepare_shmi_inputs(
  path,
  exclude = NULL,
  verbose = TRUE,
  start_date_override = NULL,
  end_date_override = NULL,
  end_at_sample_date = FALSE,
  max_rot_range = 200,
  calc_yield = FALSE,
  calc_n_rate = FALSE
)
```

## Arguments

- path:

  Path to the SHMI Excel workbook.

- exclude:

  Optional character vector of `MGT_combo` values to leave out.

- verbose:

  Logical. Print progress and a summary of assumptions.

- start_date_override, end_date_override:

  Optional start and end of the evaluation window (a `Date` or a string
  such as `"2018-01-01"`).

- end_at_sample_date:

  Logical. Cut each unit's records off at its `MGT_sample_date`.

- max_rot_range:

  Maximum plausible rotation length in years; longer spans stop with an
  error, since they usually indicate a mistyped date.

- calc_yield:

  Logical. Also return converted yields.

- calc_n_rate:

  Logical. Also return annual nitrogen rates.

## Value

A named list:

- `rot_bounds`: rotation start and end dates and years for each unit.

- `mgt`: management-unit metadata for units with at least one dated
  record.

- `crop`: species episodes (`MGT_combo`, `episode_id`, `CD_cat`,
  `CD_name`, `crop_start`, `crop_end`, `start_imputed`, `end_imputed`).

- `dist`, `amend`, `animal`: disturbance, amendment, and animal events
  within the rotation window.

- `yield`: one row per harvest with a yield (`CD_yield`,
  `CD_yield_units`, `yield_kg_ha`, `yield_status`, `lb_per_bu`), or
  `NULL`.

- `n_rate`: one row per unit and year (`N_kg_ha_yr`, `n_events`,
  `n_unconverted`), or `NULL`.

- `assumptions`: one row per imputation or data check, with `MGT_combo`,
  `source` (`"crop"`, `"yield"`, or `"n_rate"`), `name`, `date_start`,
  `date_end`, `level` (`"assumption"` or `"check"`), `type`, and
  `message`.

## Workbook

The workbook follows the SHMI template (see
[`download_shmi_template()`](https://danielmanter-usda.github.io/SHMI/reference/download_shmi_template.md)).
Sheets `Mgt_Unit`, `Crop_Diversity`, `Soil_Disturbance`,
`Soil_Amendments`, and `Animal_Diversity` are read, each with column
names on the fourth row. The disturbance, amendment, and animal sheets
may be empty. The workbook is first checked by
[`validate_excel_input()`](https://danielmanter-usda.github.io/SHMI/reference/validate_excel_input.md),
and execution stops with a list of errors if it fails.

## Crop episodes

Crop rows become species episodes: one row per species per continuous
period of presence. Mixtures, relays, and intercrops are simply
overlapping episodes; `CD_seq_num` and `CD_mix` are not used. A plant
date starts an episode. Non-perennials end at harvest (a termination
date is also accepted; if both are given, the earlier is used).
Perennials end only at termination, and harvest rows without a plant
date are attached to the standing crop as cuttings. Missing dates are
filled as follows:

- a crop with no plant date starts at the end of the most recent earlier
  crop, or at the rotation start if nothing ended earlier (records cut
  off at the start of a calendar year);

- a crop with no end date ends at the next recorded planting, or at the
  rotation end if there is none (records cut off at the end of a
  calendar year).

Every such imputation and data-quality check is recorded in
`assumptions`.

## Rotation window and overrides

Rotation bounds run from the first to the last recorded event of any
type. To evaluate a fixed period, set `start_date_override` and/or
`end_date_override`: events outside the window are removed, crop and
animal periods are clipped to it, and the rotation bounds are
recomputed. With `end_at_sample_date = TRUE`, each unit is instead cut
off at its `MGT_sample_date` (from the `Mgt_Unit` sheet).

## Yield and nitrogen rate

With `calc_yield = TRUE`, each harvest row with a yield is converted to
kg/ha. Bushels are converted with a standard test weight for the crop
(results at market moisture); other units are kept unconverted and
reported. With `calc_n_rate = TRUE`, `SA_N` is converted to kg N/ha
using `SA_units` and summed by unit and year; years whose N cannot be
converted are `NA`, not zero. Unconverted values are listed in
`assumptions`.

## See also

[`build_shmi()`](https://danielmanter-usda.github.io/SHMI/reference/build_shmi.md),
[`validate_excel_input()`](https://danielmanter-usda.github.io/SHMI/reference/validate_excel_input.md),
[`download_shmi_template()`](https://danielmanter-usda.github.io/SHMI/reference/download_shmi_template.md),
[`get_shmi_example()`](https://danielmanter-usda.github.io/SHMI/reference/get_shmi_example.md)

## Examples

``` r
inputs <- prepare_shmi_inputs(get_shmi_example(), verbose = FALSE)
#> ℹ Validating inputs...
#> ✔ Validating inputs... [335ms]
#> 
#> ℹ Reading Excel file...
#> ✔ Reading Excel file... [302ms]
#> 
#> ℹ Calculating rotation lengths...
#> ✔ Calculating rotation lengths... [30ms]
#> 
#> ℹ Calculating crop start/end dates...
#> ✔ Calculating crop start/end dates... [141ms]
#> 
#> ℹ Applying overrides...
#> ✔ Applying overrides... [13ms]
#> 
#> ℹ Re-calculating rotation lengths...
#> ✔ Re-calculating rotation lengths... [25ms]
#> 

# What was assumed, and what should be reviewed?
table(inputs$assumptions$type)
#> < table of extent 0 >
subset(inputs$assumptions, level == "check")
#> # A tibble: 0 × 8
#> # ℹ 8 variables: MGT_combo <chr>, source <chr>, name <chr>, date_start <date>,
#> #   date_end <date>, level <chr>, type <chr>, message <chr>

# Evaluate a fixed period
inputs_2022_23 <- prepare_shmi_inputs(get_shmi_example(), verbose = FALSE,
                                      start_date_override = "2022-01-01",
                                      end_date_override   = "2023-12-31")
#> ℹ Validating inputs...
#> ✔ Validating inputs... [307ms]
#> 
#> ℹ Reading Excel file...
#> ✔ Reading Excel file... [301ms]
#> 
#> ℹ Calculating rotation lengths...
#> ✔ Calculating rotation lengths... [29ms]
#> 
#> ℹ Calculating crop start/end dates...
#> ✔ Calculating crop start/end dates... [139ms]
#> 
#> ℹ Applying overrides...
#> ✔ Applying overrides... [22ms]
#> 
#> ℹ Re-calculating rotation lengths...
#> ✔ Re-calculating rotation lengths... [25ms]
#> 
inputs_2022_23$rot_bounds
#> # A tibble: 8 × 5
#>   MGT_combo                   rot_start  rot_end    rot_start_yr rot_end_yr
#>   <chr>                       <date>     <date>            <dbl>      <dbl>
#> 1 MLSH_ARDEC_200A_DMP-Manure  2022-04-08 2023-10-23         2022       2023
#> 2 MLSH_ARDEC_200A_DMP-Manure+ 2022-04-08 2023-10-23         2022       2023
#> 3 MLSH_ARDEC_200A_DMP-N0      2022-04-08 2023-10-23         2022       2023
#> 4 MLSH_ARDEC_200A_DMP-N160    2022-04-08 2023-10-23         2022       2023
#> 5 MLSH_ARDEC_200A_Rot1-N0     2022-04-27 2023-10-23         2022       2023
#> 6 MLSH_ARDEC_200A_Rot1-N120   2022-04-27 2023-10-23         2022       2023
#> 7 MLSH_ARDEC_200A_Rot1-N180   2022-04-27 2023-10-23         2022       2023
#> 8 MLSH_ARDEC_200A_Rot1-N60    2022-04-27 2023-10-23         2022       2023
```
