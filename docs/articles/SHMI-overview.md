# SHMI Overview

``` r
library(SHMI)
```

## Introduction

The Soil Health Management Index (SHMI) provides a quantitative,
rotation‑scale assessment of soil health management practices. It
integrates four biologically grounded pillars:

- **Cover** — seasonal plant presence  
- **Diversity** — rotation-scale crop diversity (Hill numbers)  
- **Inverse Disturbance** — mechanistic mixing-efficiency × depth
  metric  
- **Organic Inputs** — amendments and animal presence

This vignette provides a complete walkthrough of the SHMI workflow using
the functions in the SHMI R package.

------------------------------------------------------------------------

## 1. Preparing Inputs

The SHMI workflow begins with a standardized Excel workbook containing:

- `Mgt_Unit`  
- `Crop_Diversity`  
- `Soil_Disturbance`  
- `Amendment_Diversity`  
- `Animal_Diversity`

The function
[`prepare_shmi_inputs()`](https://danielmanter-usda.github.io/SHMI/reference/prepare_shmi_inputs.md):

- reads and validates all sheets  
- harmonizes crop windows  
- constructs rotation bounds  
- builds daily grids  
- computes daily disturbance  
- assembles amendment and animal events

``` r
# Example (replace with your file path)
# inputs <- prepare_shmi_inputs("example.xlsx", verbose = TRUE)
```

The returned object is a named list containing:

- `rot_bounds`  
- `crop_harmonized`  
- `daily`  
- `daily_dist`  
- `amend`  
- `animal`  
- and additional metadata

These objects feed directly into
[`build_shmi()`](https://danielmanter-usda.github.io/SHMI/reference/build_shmi.md).

------------------------------------------------------------------------

## 2. Computing SHMI

Once inputs are prepared, computing SHMI is straightforward:

``` r
# shmi <- build_shmi(inputs)
# shmi$indicator_df
```

The output includes:

- **Cover**  
- **Diversity**  
- **InvDist**  
- **Animals**  
- **SHMI** (weighted composite)

as well as:

- `settings_used`  
- `expert_mode`  
- `timestamp`  
- `shmi_version`

------------------------------------------------------------------------

## 3. Expert Mode

By default, SHMI uses the official national settings (locked mode). To
explore scenarios or conduct research, you may override settings:

``` r
custom <- list(
  w_winter = 0.2,
  w_spring = 0.2,
  w_summer = 0.4,
  w_fall   = 0.2
)

# shmi_exp <- build_shmi(inputs, settings = custom, expert_mode = TRUE)
```

When `expert_mode = TRUE`, SHMI values are not comparable to the
national SHMI scale.

------------------------------------------------------------------------

## 4. Pillar Details

This section demonstrates how each pillar is computed individually.

### 4.1 Cover

``` r
# compute_w.cover(inputs$daily, inputs$rot_bounds)
```

Cover is based on seasonal plant-days, normalized by rotation length and
weighted by seasonal importance.

------------------------------------------------------------------------

### 4.2 Diversity

``` r
# compute_rot_diversity(inputs$crop_harmonized, inputs$daily)
```

Diversity uses Hill-number entropy metrics at the rotation scale, with
mixture expansion and species-level plant-day aggregation.

------------------------------------------------------------------------

### 4.3 Inverse Disturbance

``` r
# compute_avg_annual_disturbance(inputs$daily_dist, inputs$rot_bounds)
```

Disturbance is computed using a mechanistic mixing-efficiency × depth
model:

- cumulative mechanical energy  
- profile penetration (Tₜ)  
- annual aggregation  
- rotation averaging  
- scaling to 0–100

------------------------------------------------------------------------

### 4.4 Organic Inputs

``` r
# compute_orginput(inputs$rot_bounds, inputs$amend, inputs$animal)
```

Organic inputs combine amendment and animal events using user-defined
weights.

------------------------------------------------------------------------

## 5. Interpreting SHMI

The final SHMI score reflects:

- year-round cover  
- crop diversity  
- reduced soil disturbance  
- organic inputs

Higher SHMI values indicate management systems that are more supportive
of soil health.

------------------------------------------------------------------------

## Conclusion

The SHMI package provides a fast, reproducible, and biologically
grounded framework for quantifying soil health management across diverse
systems.

For more details, see:

- [`?prepare_shmi_inputs`](https://danielmanter-usda.github.io/SHMI/reference/prepare_shmi_inputs.md)  
- [`?build_shmi`](https://danielmanter-usda.github.io/SHMI/reference/build_shmi.md)  
- [`?compute_w.cover`](https://danielmanter-usda.github.io/SHMI/reference/compute_w.cover.md)  
- [`?compute_rot_diversity`](https://danielmanter-usda.github.io/SHMI/reference/compute_rot_diversity.md)  
- [`?compute_avg_annual_disturbance`](https://danielmanter-usda.github.io/SHMI/reference/compute_avg_annual_disturbance.md)  
- [`?compute_orginput`](https://danielmanter-usda.github.io/SHMI/reference/compute_orginput.md)
