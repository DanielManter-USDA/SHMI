# Compute the Diversity sub-index

Average annual plant species richness, scaled 0-100.

## Usage

``` r
compute_diversity(crop, rot_bounds, max_richness = 8)
```

## Arguments

- crop:

  Species episodes with `MGT_combo`, `CD_name`, `crop_start` and
  `crop_end`, as in `prepare_shmi_inputs()$crop`.

- rot_bounds:

  Rotation bounds with `MGT_combo`, `rot_start` and `rot_end`. Episodes
  are clipped to this window.

- max_richness:

  Average species per year that scores 100.

## Value

A tibble with `MGT_combo`, `Diversity` (0-100) and `Richness` (average
species per year), one row per unit in `rot_bounds`.

## Details

For each calendar year in a unit's evaluation window, Diversity counts
the plant species present at any time that year, then averages the
counts over the years. A cover crop or a seed mix therefore raises
Diversity in the years it grows; a rotation of single crops (corn, then
soybean) counts one species per year.

**Species.** Each distinct `CD_name` is a species (whitespace tidied).
Count-first placeholder mixtures such as `"8-species"`, `"8 spp"` or
`"8-species mix"` count as that many species. Names joined by `"+"` are
split. Rows named `"fallow"`, `"none"` or `"bare"` are not plants.

**Score.** \$\$Diversity = 100 \min\left(\frac{R - 1}{R\_{max} - 1},
1\right)\$\$ where \\R\\ is the average annual richness: one species a
year scores 0, and \\R\_{max}\\ (8) or more species a year scores 100.

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
compute_diversity(crop, rot_bounds)   # 2 species in 2020 and 2021
#> # A tibble: 1 × 3
#>   MGT_combo Diversity Richness
#>   <chr>         <dbl>    <dbl>
#> 1 field_1        14.3        2
```
