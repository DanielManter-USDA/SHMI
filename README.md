# SHMI: Soil Health Management Index

The **SHMI** R package provides a complete, reproducible workflow for computing
the Soil Health Management Index (SHMI) from standardized Excel workbooks.
SHMI integrates four management pillars:

- **Cover** — seasonal plant presence  
- **Diversity** — rotation-scale crop diversity (Hill numbers)  
- **Inverse Disturbance** — mechanistic mixing-efficiency × depth metric  
- **Organic Inputs** — amendments and animal presence  

The package includes:

- robust Excel ingestion and validation  
- biologically realistic crop-window harmonization  
- fast vectorized daily-grid construction  
- mechanistic disturbance modeling  
- rotation-scale aggregation  
- official national SHMI settings (locked mode)  
- expert-mode overrides for research and scenario analysis  

---

## Installation

```r
# install.packages("devtools")
devtools::install_github("Daniel.Manter-USDA/SHMI")
```

---

## Basic Workflow

```r
library(SHMI)

# Example input file included with the package
example_file <- get_shmi_example()

# Prepare inputs
inputs <- prepare_shmi_inputs(example_file)

# Compute SHMI
shmi <- build_shmi(inputs)

shmi$indicator_df

```

---

## User-supplied data

```r
library(SHMI)

# Get a blank SHMI template
blank_file <- get_shmi_template()

# (1) Open the template in Excel
# (2) Fill in your management data
# (3) Save it as "my_shmi_inputs.xlsx"

user_file <- "path/to/my_shmi_inputs.xlsx"

# Prepare inputs
inputs <- prepare_shmi_inputs(user_file)

# Compute SHMI
shmi <- build_shmi(inputs)

shmi$indicator_df
```
The SHMI template enforces required column names, date formats, and sheet structure. 
prepare_shmi_inputs() performs full validation and will return clear, actionable error messages if anything is missing or incorrectly formatted.

---

## Input data structure

SHMI expects a standardized Excel workbook with sheets for:

- **Crop_Diversity**
- **Soil_Disturbance**
- **Soil_Amendments**
- **Animal_Diversity**

The `prepare_shmi_inputs()` function validates and harmonizes these sheets.

---

## Expert mode

```r
custom <- list(
  w_winter = 0.2,
  w_spring = 0.2,
  w_summer = 0.4,
  w_fall   = 0.2
)

shmi_exp <- build_shmi(inputs, settings = custom, expert_mode = TRUE)
```

---

## License

This software is a work of the United States Government and is not subject to 
copyright protection in the United States. Foreign copyrights may apply.

Distributed under the MIT license.
