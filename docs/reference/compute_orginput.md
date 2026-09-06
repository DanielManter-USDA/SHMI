# Compute the Organic Inputs Sub-index (Amendments + Animals)

Calculates the SHMI organic-inputs indicator for each management unit
(\`MGT_combo\`) by identifying rotation years in which \*any\* organic
input occurred—either an organic amendment or an animal event. Presence
is treated as binary within each year: a year receives a value of 1 if
at least one qualifying event occurred, regardless of the number of
applications or events. User-specified weights determine whether
amendments and/or animals contribute to presence, but do not affect
magnitude. The final score is the percentage of rotation years with
organic inputs (0–100), without min–max scaling.

## Usage

``` r
compute_orginput(rot_bounds, amend, animal, w_amend = 1, w_animal = 1)
```

## Arguments

- rot_bounds:

  A data frame from
  [`prepare_shmi_inputs()`](https://danielmanter-usda.github.io/SHMI/reference/prepare_shmi_inputs.md)
  containing rotation-year bounds for each management unit, with
  columns:

  - `MGT_combo`

  - `rot_start_yr`

  - `rot_end_yr`

- amend:

  A data frame of amendment events (from the `Amendment_Diversity`
  sheet), containing:

  - `MGT_combo`

  - `SA_date` — amendment date

  - `SA_cat` — amendment category (e.g., "Organic")

  Only rows with `SA_cat == "Organic"` contribute to the index.

- animal:

  A data frame of animal events (from the `Animal_Diversity` sheet),
  containing:

  - `MGT_combo`

  - `AD_start_date` — start of animal presence

- w_amend:

  Numeric weight controlling whether organic amendments contribute to
  presence (default 1; values \> 0 include amendments).

- w_animal:

  Numeric weight controlling whether animal events contribute to
  presence (default 1; values \> 0 include animals).

## Value

A data frame with:

- `MGT_combo`

- `OrgInputs` — organic-input score (0–100)

## Details

The algorithm proceeds in five steps:

1.  **Rotation-year grid**: Construct a sequence of rotation years for
    each `MGT_combo`.

2.  **Amendment presence**: Identify rotation years with organic
    amendments and mark them as `amend_present = 1`.

3.  **Animal presence**: Identify rotation years with animal events and
    mark them as `ani_present = 1`.

4.  **Binary organic-input presence**: A rotation year receives
    `org_present = 1` if either `amend_present == 1` and `w_amend > 0`,
    or `ani_present == 1` and `w_animal > 0`. Multiple events within a
    year do not increase the score.

5.  **Final score**: The organic-inputs indicator is returned as \$\$
    \mathrm{OrgInputs} = 100 \times \mathrm{mean}(org\\present) \$\$
    representing the percentage of rotation years with organic inputs.
    Units with no organic inputs receive a score of 0.
