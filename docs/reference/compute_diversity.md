# Compute Rotation‑Scale Crop Diversity (Entropy‑Based Hill Numbers)

Computes the SHMI diversity sub‑index for each management unit
(\`MGT_combo\`) using rotation‑scale plant‑day totals for each species.
Diversity reflects the distribution of crop species across the entire
rotation and is calculated using Hill‑number metrics (richness, Shannon,
or Simpson). The final diversity score is scaled to 0–100.

## Usage

``` r
compute_diversity(crop, hill = 2, max_div = 8)
```

## Arguments

- crop:

  A data frame containing one row per crop species with harmonized
  start/end dates, including:

  - `MGT_combo` — management unit identifier

  - `CD_name` — crop or mixture name

  - `crop_start`, `crop_end` — daily cover interval

- hill:

  Hill‑number order. Supported values:

  - `0`: species richness

  - `1`: Shannon entropy

  - `2`: Simpson entropy (entropy form)

  Default is `2`.

- max_div:

  The theoretical maximum diversity used for scaling the final index to
  0–100. For richness, this is the maximum number of species. For
  entropy‑based metrics, scaling uses `log(max_div)`.

## Value

A data frame with:

- `MGT_combo`

- `Diversity` — rotation‑scale diversity score (0–100)

## Details

\## Mixture expansion

The input \`crop\` table contains one row per crop species. Mixtures
therefore appear as single rows whose \`CD_name\` contains multiple
species (e.g., \`"A + B + C"\`) or placeholder mixture names (e.g.,
\`"8-species"\`).

Mixtures are expanded into individual species using:

- splitting real mixtures on \`"+"\`, and

- expanding placeholder mixtures into synthetic species (\`species_1\`,
  \`species_2\`, …).

Each species inherits the same \`crop_start\` and \`crop_end\` interval.

\## Rotation‑scale plant‑days

For each species, plant‑days are computed as:

\$\$ \text{days} = (\text{crop\\end} - \text{crop\\start}) + 1 \$\$

Plant‑days are summed across all years of the rotation. Fallow
contributes zero plant‑days.

\## Hill‑number diversity

Species proportions are:

\$\$ p_i = \frac{\text{days}\_i}{\sum_j \text{days}\_j} \$\$

Diversity is computed using Hill‑number entropy metrics:

- Richness: \\D = \sum I(p_i \> 0)\\

- Shannon entropy: \\D = -\sum p_i \log p_i\\

- Simpson entropy (entropy form): \\D = -\log \sum p_i^2\\

The diversity value is capped at `max_div` and scaled to 0–100:

- Richness: \\D / max\\div\\

- Entropy metrics: \\D / \log(max\\div)\\
