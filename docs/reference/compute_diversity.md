# Compute Rotation-Scale Crop Diversity (Entropy-Based Hill Numbers)

Calculates the SHMI diversity sub-index for each management unit
(\`MGT_combo\`) using daily crop presence data and harmonized crop
windows. Diversity is computed at the \*rotation scale\* by expanding
species mixtures, summing plant-days across years, and applying
Hill-number diversity metrics in entropy form (Shannon or Simpson). The
final diversity score is scaled to 0–100 using a user-specified
theoretical maximum.

## Usage

``` r
compute_diversity(crop_harmonized, daily, hill = 2, max_div = 8)
```

## Arguments

- crop_harmonized:

  A data frame produced by
  [`prepare_shmi_inputs()`](https://danielmanter-usda.github.io/SHMI/reference/prepare_shmi_inputs.md),
  containing one row per crop event with harmonized start/end dates and
  mixture names.

- daily:

  A daily data frame from
  [`prepare_shmi_inputs()`](https://danielmanter-usda.github.io/SHMI/reference/prepare_shmi_inputs.md),
  containing:

  - `MGT_combo` — management unit identifier

  - `date` — calendar date

  - `CD_seq_num` — crop sequence number

  - `CD_name` — crop or mixture name

  - `crop_present` — 1 if crop present, 0 otherwise

- hill:

  Hill-number order. Supported values:

  - `0`: species richness

  - `1`: Shannon entropy

  - `2`: Simpson entropy (entropy form)

  Default is `2`.

- max_div:

  The theoretical maximum diversity used for scaling the final index to
  0–100. For richness (`hill = 0`), this is the maximum number of
  species. For entropy-based metrics, scaling uses `log(max_div)`.

## Value

A data frame with:

- `MGT_combo`

- `Diversity` — rotation-scale diversity score (0–100)

## Details

The algorithm proceeds in four stages:

1.  **Daily plant-days**: Sum daily crop presence by
    `MGT_combo × CD_seq_num × CD_name × year`.

2.  **Mixture expansion**: Mixtures such as `"A + B"` are split into
    individual species. Placeholder mixtures like `"3-species"` are
    expanded into `species_1`, `species_2`, `species_3`.

3.  **Rotation-scale plant-days**: Plant-days are summed across all
    years of the rotation for each species.

4.  **Entropy-based diversity**: Species proportions \\p_i\\ are
    computed and diversity is calculated as:

    - Richness: \\D = \sum I(p_i \> 0)\\

    - Shannon entropy: \\D = -\sum p_i \log p_i\\

    - Simpson entropy: \\D = -\log \sum p_i^2\\

    The result is capped at `max_div` and scaled to 0–100.
