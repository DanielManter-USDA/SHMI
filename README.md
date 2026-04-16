# SHMI: Soil Health Management Index <img src="man/figures/logo.png" align="right" width="120" />

<!-- badges: start -->
![R-CMD-check](https://github.com/DanielManter-USDA/SHMI/actions/workflows/R-CMD-check.yaml/badge.svg)
![pkgdown](https://github.com/DanielManter-USDA/SHMI/actions/workflows/pkgdown.yaml/badge.svg)
![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg?logo=open-source-initiative&logoColor=white)
<!-- badges: end -->


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


## ⭐ Why SHMI?

Agricultural management is multidimensional, and many soil health indicators respond to long‑term patterns 
rather than single‑year practices. SHMI provides:

- A **rotation‑scale** measure of management intensity  
- A **standardized, reproducible** workflow for diverse datasets  
- A **transparent scoring system** grounded in ecological function  
- A **consistent template** for data entry and QA/QC  
- Tools that help researchers and practitioners compare systems, evaluate interventions, and link management 
to soil outcomes

---

## 🚀 Installation

Install the development version from GitHub:

```r
# install.packages("devtools")
devtools::install_github("DanielManter-USDA/SHMI")
```

---

## 📘 Minimal Example

A complete SHMI workflow in just a few lines

```r
library(SHMI)

# 1. Retrieve the Excel template
template <- get_shmi_template()

# 2. Prepare inputs (validates structure and expands events)
df <- prepare_shmi_inputs(template)

# 3. Compute pillar scores and SHMI
result <- build_shmi(df)

head(result)

```

---

## 📘 User-supplied data

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
prepare_shmi_inputs() performs full validation and will return clear, actionable error messages 
if anything is missing or incorrectly formatted.

---

## 📂 Workflow Overview

SHMI provides a structured, end‑to‑end workflow:
1. **Template generation**
   - `get_shmi_template()`
   - `get_shmi_example()`


2. **Input preparation**
   - Validates required columns
   - Expands crop windows to daily resolution
   - Summarizes disturbance and organic inputs
   - Harmonizes dates and management events
   - `prepare_shmi_inputs()`

3. **Computation of individual pillar scores**
   - Cover `compute_cover()`
   - Diversity `compute_diversity()`
   - Disturbance `compute_disturbance()`
   - Organic inputs `compute_orginput()`

4. **Final SHMI calculation**
   - `build_shmi()`


---

## 📚 Documentation

Full documentation and examples are available at:
👉 https://danielmanter-usda.github.io/SHMI/

This includes:
• 	Function reference
• 	Workflow overview
• 	Example data
• 	Template documentation
• 	Articles and vignettes

---

## 🤝 Contributing

Issues, suggestions, and pull requests are welcome:
👉 https://github.com/DanielManter-USDA/SHMI/issues

---

## License

This software is a work of the United States Government and is not subject to 
copyright protection in the United States. Foreign copyrights may apply.

Distributed under the MIT license.

---

📌 Citation
If you use SHMI in a publication, please cite:

Manter DK, Moore JM. (202X). SHMI: Soil Health Management Index R package.

---
