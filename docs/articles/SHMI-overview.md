# SHMI Overview

### Introduction

The Soil Health Management Index (SHMI) provides a quantitative,
rotation‑scale assessment of soil‑health management practices. It
integrates four biologically grounded sub‑indices:

- **Cover/Roots** — seasonal plant presence  
- **Crop Diversity** — rotation‑scale crop diversity (Hill numbers)  
- **Inverse Disturbance** — mechanistic mixing‑efficiency × depth
  metric  
- **Organic Inputs** — organic amendments and animal presence

This vignette walks through the **standard SHMI workflow** using the
official Excel template.

------------------------------------------------------------------------

## **1. Preparing Inputs**

SHMI begins with a standardized Excel workbook containing the following
sheets:

- `Mgt_Unit`  
- `Crop_Diversity`  
- `Soil_Disturbance`  
- `Amendment_Diversity`  
- `Animal_Diversity`

Download the blank template:

``` r
library(SHMI)

# Save the template to a specific file path
template_file <- "SHMI_template.xlsx"
download_shmi_template(path = template_file)
```

Then: 1. Open **SHMI_template.xlsx** in Excel  
2. Enter your management data into each sheet  
3. Save the completed file (e.g., `"my_SHMI_inputs.xlsx"`)

Prepare the inputs:

``` r
inputs <- prepare_shmi_inputs("my_SHMI_inputs.xlsx")
```

[`prepare_shmi_inputs()`](https://danielmanter-usda.github.io/SHMI/reference/prepare_shmi_inputs.md):

- validates required sheets and columns  
- harmonizes crop windows  
- constructs rotation bounds  
- builds daily grids  
- computes daily disturbance  
- assembles amendment and animal events

The returned object is a named list containing:

- `rot_bounds`  
- `crop_harmonized`  
- `daily`  
- `daily_dist`  
- `amend`  
- `animal`  
- metadata

These feed directly into
[`build_shmi()`](https://danielmanter-usda.github.io/SHMI/reference/build_shmi.md).

------------------------------------------------------------------------

## **2. Computing SHMI**

Once inputs are prepared:

``` r
result <- build_shmi(inputs)
result$indicator_df
```

The output includes:

- **Cover**  
- **Diversity**  
- **InvDist**  
- **OrgInputs**  
- **SHMI**

Plus metadata:

- `settings_used`  
- `expert_mode`  
- `timestamp`  
- `shmi_version`

------------------------------------------------------------------------

## **3. Expert Mode**

By default, SHMI uses the official national settings (locked mode).  
To explore scenarios or conduct research, you may override settings:

``` r
custom <- list(
  # cover/roots
  w_winter = 0.25,
  w_spring = 0.25,
  w_summer = 0.25,
  w_fall   = 0.25,

  # crop diversity
  hill    = 2,
  max_div = 8,

  # inverse disturbance
  # NA
  # organic inputs
  w_amend   = 1,
  w_animals = 1,
  
  # SHMI index weights
  w_cover = 0.25,
  w_div   = 0.25,
  w_dist  = 0.25,
  w_ani   = 0.25
)

shmi_exp <- build_shmi(inputs, settings = custom, expert_mode = TRUE)
```

When `expert_mode = TRUE`, SHMI values are **not comparable** to the
national scale.

------------------------------------------------------------------------

## **4. Sub‑Index Details**

You may compute sub‑indices individually:

#### Cover

``` r
compute_cover(inputs$daily, inputs$rot_bounds)
```

#### Diversity

``` r
compute_diversity(inputs$crop_harmonized, inputs$daily)
```

#### Inverse Disturbance

``` r
compute_disturbance(inputs$daily_dist, inputs$rot_bounds)
```

#### Organic Inputs

``` r
compute_orginput(inputs$rot_bounds, inputs$amend, inputs$animal)
```

------------------------------------------------------------------------

## **5. Interpreting SHMI**

The final SHMI score reflects:

- year‑round cover  
- crop diversity  
- reduced soil disturbance  
- organic inputs

Higher SHMI values indicate management systems that are more supportive
of soil health.

------------------------------------------------------------------------

## Conclusion

The SHMI package provides a fast, reproducible, and biologically
grounded framework for quantifying soil‑health management across diverse
systems.

For more details:

- [`?prepare_shmi_inputs`](https://danielmanter-usda.github.io/SHMI/reference/prepare_shmi_inputs.md)  
- [`?build_shmi`](https://danielmanter-usda.github.io/SHMI/reference/build_shmi.md)  
- [`?compute_cover`](https://danielmanter-usda.github.io/SHMI/reference/compute_cover.md)  
- [`?compute_diversity`](https://danielmanter-usda.github.io/SHMI/reference/compute_diversity.md)  
- [`?compute_disturbance`](https://danielmanter-usda.github.io/SHMI/reference/compute_disturbance.md)  
- [`?compute_orginput`](https://danielmanter-usda.github.io/SHMI/reference/compute_orginput.md)
