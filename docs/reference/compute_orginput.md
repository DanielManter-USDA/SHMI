# Compute the Organic Inputs Pillar (Amendments + Animals)

Calculates the SHMI organic-inputs indicator for each management unit
(\`MGT_combo\`) by combining amendment events and animal events across
the rotation. Each year of the rotation is assigned a weighted
organic-input presence based on user-specified weights for amendments
and animals. The final score is scaled to 0–100.

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

  Numeric weight applied to amendment events (default 1).

- w_animal:

  Numeric weight applied to animal events (default 1).

## Value

A data frame with:

- `MGT_combo`

- `events_per_year` — weighted organic-input frequency

- `Animals` — final SHMI organic-input score (0–100)

## Details

The algorithm proceeds in six steps:

1.  **Rotation-year grid**: For each `MGT_combo`, construct a sequence
    of years from `rot_start_yr` to `rot_end_yr`.

2.  **Amendment events**: Identify years with organic amendments and
    mark them as `amend_present = 1`.

3.  **Animal events**: Identify years with animal presence and mark them
    as `ani_present = 1`.

4.  **Weighted presence**: For each year of the rotation: \$\$
    \text{weighted\\input} = w\_{\text{amend}} \cdot
    \text{amend\\present} + w\_{\text{animal}} \cdot \text{ani\\present}
    \$\$

5.  **Rotation-average**: Weighted inputs are summed across the rotation
    and divided by the number of rotation years.

6.  **Scaling**: The rotation-average is rescaled to 0–100 using
    [`scales::rescale()`](https://scales.r-lib.org/reference/rescale.html).
