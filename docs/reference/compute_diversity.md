# Compute the Diversity sub-index

Plant species richness over a rotation window, scaled 0-100.

## Usage

``` r
compute_diversity(
  crop,
  rot_bounds,
  max_richness = 8,
  window = getOption("SHMI.diversity_window", 4)
)
```

## Arguments

- crop:

  Species episodes with `MGT_combo`, `CD_name`, `crop_start` and
  `crop_end`, as in `prepare_shmi_inputs()$crop`.

- rot_bounds:

  Rotation bounds with `MGT_combo`, `rot_start` and `rot_end`. Episodes
  are clipped to this window.

- max_richness:

  Species per window that scores 100.

- window:

  Window length in years (default 4; 1 = calendar years, as in SHMI
  1.0). Can be set for a session with
  `options(SHMI.diversity_window = )`, which also changes
  [`build_shmi()`](https://danielmanter-usda.github.io/SHMI/reference/build_shmi.md)
  and
  [`shmi_components()`](https://danielmanter-usda.github.io/SHMI/reference/shmi_components.md).

## Value

A tibble with `MGT_combo`, `Diversity` (0-100) and `Richness` (average
species per window), one row per unit in `rot_bounds`.

## Details

Diversity counts the distinct plant species (cash crops, forages and
cover crops alike) grown in each `window`-year span of a unit's
evaluation window, sliding one calendar year at a time, and averages the
counts. A record of `window` years or fewer is a single span. With the
default 4-year window a corn-soybean rotation counts 2 species,
corn-soybean-wheat 3, and a rye cover grown in the rotation adds 1; a
long stand of a single perennial counts 1 except in the spans where it
meets the next crop. `window = 1` counts species per calendar year (the
SHMI 1.0 definition).

**Species.** Each distinct `CD_name` is a species (whitespace tidied).
Count-first placeholder mixtures such as `"8-species"`, `"8 spp"` or
`"8-species mix"` count as that many species. Names joined by `"+"` are
split. Rows named `"fallow"`, `"none"` or `"bare"` are not plants.

**Score.** \$\$Diversity = 100 \min\left(\frac{R - 1}{R\_{max} - 1},
1\right)\$\$ where \\R\\ is the average richness per window: one species
scores 0, and \\R\_{max}\\ (8) or more scores 100. Corn-soybean scores
14, corn-soybean-wheat 29, corn-soybean-wheat with a rye cover 43.

## See also

[`build_shmi()`](https://danielmanter-usda.github.io/SHMI/reference/build_shmi.md)

## Examples

``` r
crop <- data.frame(
  MGT_combo  = "field_1",
  CD_name    = c("Corn", "Rye", "Soybean"),
  crop_start = as.Date(c("2020-05-01", "2020-10-15", "2021-05-10")),
  crop_end   = as.Date(c("2020-09-30", "2021-04-20", "2021-09-25"))
)
rot_bounds <- data.frame(MGT_combo = "field_1",
                         rot_start = as.Date("2020-01-01"),
                         rot_end   = as.Date("2021-12-31"))
compute_diversity(crop, rot_bounds)              # 3 species in the rotation: 29
#> # A tibble: 1 × 3
#>   MGT_combo Diversity Richness
#>   <chr>         <dbl>    <dbl>
#> 1 field_1        28.6        3
compute_diversity(crop, rot_bounds, window = 1)  # 2 a year (SHMI 1.0): 14
#> # A tibble: 1 × 3
#>   MGT_combo Diversity Richness
#>   <chr>         <dbl>    <dbl>
#> 1 field_1        14.3        2
```
