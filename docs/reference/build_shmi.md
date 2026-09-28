# Compute SHMI scores from prepared inputs

Computes the Soil Health Management Index (SHMI) for each management
unit (`MGT_combo`) from the rotation-scale inputs returned by
[`prepare_shmi_inputs()`](https://danielmanter-usda.github.io/SHMI/reference/prepare_shmi_inputs.md).
SHMI is a weighted mean of four sub-indices, each scaled 0-100:

## Usage

``` r
build_shmi(shmi_inputs, settings = NULL, expert_mode = FALSE)
```

## Arguments

- shmi_inputs:

  A list returned by
  [`prepare_shmi_inputs()`](https://danielmanter-usda.github.io/SHMI/reference/prepare_shmi_inputs.md).

- settings:

  Optional named list of settings (see *Settings and expert mode*).
  Ignored unless `expert_mode = TRUE`.

- expert_mode:

  Logical. If `TRUE`, elements of `settings` override the official
  national settings.

## Value

A list with:

- `indicator_df`: one row per management unit with `MGT_combo`, the
  management metadata that is present (`MGT_study`, `MGT_farm`,
  `MGT_field`, `MGT_trt`), `SHMI`, `Cover`, `Diversity`, `InvDist`, and
  `OrgInput`.

- `settings_used`: the full list of settings applied.

- `expert_mode`: logical flag.

- `shmi_version`: version of the SHMI package used.

- `timestamp`: time of computation.

## Details

- **Cover**: season-weighted proportion of days with living plants
  ([`compute_cover()`](https://danielmanter-usda.github.io/SHMI/reference/compute_cover.md)).

- **Diversity**: rotation-scale crop diversity
  ([`compute_diversity()`](https://danielmanter-usda.github.io/SHMI/reference/compute_diversity.md)).

- **InvDist**: inverse soil disturbance
  ([`compute_disturbance()`](https://danielmanter-usda.github.io/SHMI/reference/compute_disturbance.md)).

- **OrgInput**: organic amendments and animal integration
  ([`compute_orginput()`](https://danielmanter-usda.github.io/SHMI/reference/compute_orginput.md)).

## Settings and expert mode

With `expert_mode = FALSE` (the default, "locked mode") the official
national settings below are always used and `settings` is ignored. With
`expert_mode = TRUE`, each element of `settings` replaces the official
value; elements not supplied keep their official value. Expert-mode
scores are not comparable to the national SHMI scale.

|  |  |  |
|----|----|----|
| Setting | Official value | Used by |
| `w_winter`, `w_spring`, `w_summer`, `w_fall` | 0.1259, 0.1260, 0.3755, 0.3726 | [`compute_cover()`](https://danielmanter-usda.github.io/SHMI/reference/compute_cover.md) |
| `hill`, `max_div` | 1, 10 | [`compute_diversity()`](https://danielmanter-usda.github.io/SHMI/reference/compute_diversity.md) |
| `dist_meth`, `max_stir`, `ti_rep` | `"EPA"`, 342, `"max"` | [`compute_disturbance()`](https://danielmanter-usda.github.io/SHMI/reference/compute_disturbance.md) |
| `w_amend`, `w_animal` | 0.6615, 0.3385 | [`compute_orginput()`](https://danielmanter-usda.github.io/SHMI/reference/compute_orginput.md) |
| `animal_presence` | `"span"` | [`compute_orginput()`](https://danielmanter-usda.github.io/SHMI/reference/compute_orginput.md) |
| `clip_to_rotation` | `TRUE` | [`compute_cover()`](https://danielmanter-usda.github.io/SHMI/reference/compute_cover.md), [`compute_diversity()`](https://danielmanter-usda.github.io/SHMI/reference/compute_diversity.md) |
| `w_cover`, `w_diversity`, `w_invdist`, `w_orginput` | 0.4481, 0.0904, 0.1431, 0.3184 | SHMI |

The four pillar weights are rescaled to sum to 1 and combined as
\$\$SHMI = w\_{cover} Cover + w\_{diversity} Diversity + w\_{invdist}
InvDist + w\_{orginput} OrgInput\$\$

Settings are checked before use: unknown names (for example a misspelled
weight) and out-of-range values stop with an error rather than being
silently ignored.

The official disturbance method, `"EPA"`, requires a tillage depth
(`SD_depth`) for every pass. Data without depths can be scored in expert
mode with `settings = list(dist_meth = "STIR")`.

## Missing records

Every management unit in `shmi_inputs$mgt` receives a score. A missing
record means the practice did not happen: a unit with no crops scores
Cover = 0 and Diversity = 0, no disturbance scores InvDist = 100, and no
organic inputs scores OrgInput = 0. Units with no dated records at all
are removed earlier, by
[`prepare_shmi_inputs()`](https://danielmanter-usda.github.io/SHMI/reference/prepare_shmi_inputs.md).

## See also

[`prepare_shmi_inputs()`](https://danielmanter-usda.github.io/SHMI/reference/prepare_shmi_inputs.md),
[`validate_shmi_input()`](https://danielmanter-usda.github.io/SHMI/reference/validate_shmi_input.md),
[`plot_shmi_gauge()`](https://danielmanter-usda.github.io/SHMI/reference/plot_shmi_gauge.md),
[`plot_shmi_lollipop()`](https://danielmanter-usda.github.io/SHMI/reference/plot_shmi_lollipop.md)

## Examples

``` r
inputs <- prepare_shmi_inputs(get_shmi_example(), verbose = FALSE)
#> ℹ Validating inputs...
#> ✔ Validating inputs... [613ms]
#> 
#> ℹ Reading Excel file...
#> ✔ Reading Excel file... [325ms]
#> 
#> ℹ Calculating rotation lengths...
#> ✔ Calculating rotation lengths... [45ms]
#> 
#> ℹ Calculating crop start/end dates...
#> ✔ Calculating crop start/end dates... [150ms]
#> 
#> ℹ Applying overrides...
#> ✔ Applying overrides... [14ms]
#> 
#> ℹ Re-calculating rotation lengths...
#> ✔ Re-calculating rotation lengths... [38ms]
#> 

# Official national settings
result <- build_shmi(inputs)
#> ℹ Validating inputs...
#> ✔ Validating inputs... [14ms]
#> 
#> ℹ Computing cover...
#> ✔ Computing cover... [89ms]
#> 
#> ℹ Computing diversity...
#> ✔ Computing diversity... [51ms]
#> 
#> ℹ Computing disturbance...
#> ✔ Computing disturbance... [42ms]
#> 
#> ℹ Computing organic inputs...
#> ✔ Computing organic inputs... [18ms]
#> 
#> ℹ Combining indices...
#> ✔ Combining indices... [32ms]
#> 
#> 
#> 
#> SHMI computed using official national settings.
result$indicator_df
#> # A tibble: 8 × 10
#>   MGT_combo   MGT_study MGT_farm MGT_field MGT_trt  SHMI Cover Diversity InvDist
#>   <chr>       <chr>     <chr>    <chr>     <chr>   <dbl> <dbl>     <dbl>   <dbl>
#> 1 MLSH_ARDEC… MLSH      ARDEC    200A      DMP-Ma…  56.9  62.3         0    55.1
#> 2 MLSH_ARDEC… MLSH      ARDEC    200A      DMP-Ma…  56.9  62.3         0    55.1
#> 3 MLSH_ARDEC… MLSH      ARDEC    200A      DMP-N0   35.8  62.3         0    55.1
#> 4 MLSH_ARDEC… MLSH      ARDEC    200A      DMP-N1…  35.8  62.3         0    55.1
#> 5 MLSH_ARDEC… MLSH      ARDEC    200A      Rot1-N0  42.2  62.3         0   100  
#> 6 MLSH_ARDEC… MLSH      ARDEC    200A      Rot1-N…  42.2  62.3         0   100  
#> 7 MLSH_ARDEC… MLSH      ARDEC    200A      Rot1-N…  42.2  62.3         0   100  
#> 8 MLSH_ARDEC… MLSH      ARDEC    200A      Rot1-N…  42.2  62.3         0   100  
#> # ℹ 1 more variable: OrgInput <dbl>

# Expert mode: STIR disturbance, for data without tillage depths
if (FALSE) { # \dontrun{
result_stir <- build_shmi(inputs, settings = list(dist_meth = "STIR"),
                          expert_mode = TRUE)
} # }
```
