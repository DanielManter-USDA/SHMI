# Compute the Diversity sub-index

Rotation-scale crop diversity based on the number of days each species
is present, scaled 0-100.

## Usage

``` r
compute_diversity(crop, hill = 1, max_div = 10)
```

## Arguments

- crop:

  Species episodes with `MGT_combo`, `CD_name`, `crop_start`, and
  `crop_end`, as in `prepare_shmi_inputs()$crop`.

- hill:

  Diversity order: `0` (richness), `1` (Shannon, official), or `2`
  (Simpson).

- max_div:

  Number of species (or effective species) that scores 100.

## Value

A data frame with `MGT_combo` and `Diversity` (0-100). Units with no
non-fallow species are omitted;
[`build_shmi()`](https://danielmanter-usda.github.io/SHMI/reference/build_shmi.md)
scores them 0.

## Details

**Species.** Each distinct `CD_name` is a species. Full names are used,
so `"Rye"` and `"Rye, Cereal"` are different species; extra whitespace
is ignored. Count-first placeholder mixtures such as `"8-species"`,
`"8 species"`, or `"8-spp"` are expanded into synthetic species
`species_1`, ..., `species_8`. Placeholders in the same unit share these
names, so a mix repeated in several years counts as the same species.
Names such as `"Species 1"` are ordinary named species. Legacy names
joined by `"+"` (`"A + B"`) are split. Fallow rows are excluded.

**Plant-days.** For each species, plant-days are the union of its
episodes, so overlapping episodes of the same species count once, while
different species present on the same day each count. Species
proportions are \\p_i = days_i / \sum_j days_j\\.

**Order** (`hill`):

- `0`: richness, the number of species, divided by `max_div`.

- `1`: Shannon entropy \\-\sum_i p_i \log p_i\\, divided by
  `log(max_div)`.

- `2`: Simpson (order-2 Renyi) entropy \\-\log \sum_i p_i^2\\, divided
  by `log(max_div)`.

Orders 1 and 2 are logarithms of the corresponding Hill numbers, so the
score reaches 100 when the effective number of species reaches
`max_div`. Scores are capped at 100. Under orders 1 and 2 a single
species scores 0.

## See also

[`build_shmi()`](https://danielmanter-usda.github.io/SHMI/reference/build_shmi.md),
[`compute_cover()`](https://danielmanter-usda.github.io/SHMI/reference/compute_cover.md)

## Examples

``` r
crop <- data.frame(
  MGT_combo  = "field_1",
  CD_name    = c("Corn", "Soybean", "8-species"),
  crop_start = as.Date(c("2019-05-01", "2020-05-10", "2020-10-15")),
  crop_end   = as.Date(c("2019-09-30", "2020-09-25", "2021-04-01"))
)
compute_diversity(crop)            # Shannon (official)
#> # A tibble: 1 × 2
#>   MGT_combo Diversity
#>   <chr>         <dbl>
#> 1 field_1        99.9
compute_diversity(crop, hill = 0)  # richness
#> # A tibble: 1 × 2
#>   MGT_combo Diversity
#>   <chr>         <dbl>
#> 1 field_1         100
```
