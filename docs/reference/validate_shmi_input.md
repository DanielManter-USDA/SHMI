# Validate prepared SHMI inputs

Checks the list returned by
[`prepare_shmi_inputs()`](https://danielmanter-usda.github.io/SHMI/reference/prepare_shmi_inputs.md)
before scoring.
[`build_shmi()`](https://danielmanter-usda.github.io/SHMI/reference/build_shmi.md)
calls this function automatically, passing the disturbance method in
use.

## Usage

``` r
validate_shmi_input(shmi_inputs, dist_meth = NULL)
```

## Arguments

- shmi_inputs:

  A list returned by
  [`prepare_shmi_inputs()`](https://danielmanter-usda.github.io/SHMI/reference/prepare_shmi_inputs.md),
  containing at least `mgt`, `crop`, `rot_bounds`, `dist`, `amend`, and
  `animal`.

- dist_meth:

  Optional disturbance method, `"EPA"` or `"STIR"`. When supplied,
  method-specific disturbance checks are run.

## Value

A list with `ok` (logical), `errors` and `warnings` (character vectors),
and `summary` (a tibble with the numbers of fields, years, species, and
mixtures, and whether fallow is present).

## Details

Errors: a required table is missing; `MGT_combo` is missing or `NA`;
required crop columns are missing; dates are not of class `Date`; a
crop, rotation, or animal period ends before it starts; or disturbance
inputs do not suit `dist_meth`. For `"EPA"`, every pass with
`SD_mixeff > 0` needs `SD_depth` and `SD_mixeff` must lie within 0-1.

Warnings: for `"STIR"`, all non-zero `SD_mixeff` values are 1 or less,
which suggests EPA mixing proportions were entered instead of STIR
values.

## See also

[`build_shmi()`](https://danielmanter-usda.github.io/SHMI/reference/build_shmi.md),
[`validate_excel_input()`](https://danielmanter-usda.github.io/SHMI/reference/validate_excel_input.md)
