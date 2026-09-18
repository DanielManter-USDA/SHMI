# Compute the Organic Inputs Sub-index (Amendments + Animals)

Calculates the SHMI organic-inputs indicator for each management unit
(\`MGT_combo\`) by determining the proportion of rotation years in which
organic amendments and animal inputs occurred. Each component is treated
independently:

## Usage

``` r
compute_orginput(rot_bounds, amend, animal, w_amend = 0.5, w_animal = 0.5)
```

## Arguments

- rot_bounds:

  Rotation-year boundaries for each management unit.

- amend:

  Amendment event table.

- animal:

  Animal event table.

- w_amend:

  Weight for amendment presence (default 0.5).

- w_animal:

  Weight for animal presence (default 0.5).

## Value

A data frame with:

- `MGT_combo`

- `OrgInput` — organic-input score (0–100)

## Details

- **Amendment proportion** — fraction of rotation years with at least
  one organic amendment event.

- **Animal proportion** — fraction of rotation years with at least one
  animal event.

User-specified weights (`w_amend`, `w_animal`) determine the relative
importance of amendments versus animals in the final score. Weighted
proportions are combined and rescaled to a 0–100 SHMI-compatible index:

\$\$ \mathrm{OrgInput} = 100 \times \frac{ w\_{\mathrm{amend}} \cdot
p\_{\mathrm{amend}} + w\_{\mathrm{animal}} \cdot p\_{\mathrm{animal}} }{
w\_{\mathrm{amend}} + w\_{\mathrm{animal}} } \$\$

Units with no organic inputs receive a score of 0.

\## Required Inputs

\### Rotation bounds A data frame containing rotation-year boundaries:

- `MGT_combo`

- `rot_start_yr`

- `rot_end_yr`

\### Amendment events A data frame containing:

- `MGT_combo`

- `SA_date` — amendment date

- `SA_cat` — amendment category (only `"Organic"` counted)

\### Animal events A data frame containing:

- `MGT_combo`

- `AD_start_date` — start date of animal presence
