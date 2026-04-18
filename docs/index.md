# **SHMI: Soil Health Management Index**

![License:
MIT](https://img.shields.io/badge/License-MIT-blue.svg?logo=open-source-initiative&logoColor=white)

SHMI converts multi‑year crop, disturbance, and amendment records into
standardized soil‑health management scores.

------------------------------------------------------------------------

The **SHMI** R package provides a complete, reproducible workflow for
computing the Soil Health Management Index (SHMI) from standardized
Excel workbooks or R‑native example data. SHMI integrates four
management sub‑indices:

- **Cover** — seasonal plant presence  
- **Diversity** — rotation‑scale crop diversity (Hill numbers)  
- **Inverse Disturbance** — mechanistic mixing‑efficiency × depth
  metric  
- **Organic Inputs** — organic amendments and animal presence

The package includes:

- robust Excel ingestion and validation  
- biologically realistic crop‑window harmonization  
- fast vectorized daily‑grid construction  
- mechanistic disturbance modeling  
- rotation‑scale aggregation  
- official national SHMI settings (locked mode)  
- expert‑mode overrides for research and scenario analysis

------------------------------------------------------------------------

## ⭐ Why SHMI?

Agricultural management is multidimensional, and many soil health
indicators respond to **long‑term patterns**, not single‑year practices.
SHMI provides:

- A **rotation‑scale** measure of management intensity  
- A **standardized, reproducible** workflow for diverse datasets  
- A **transparent scoring system** grounded in ecological function  
- A **consistent template** for data entry and QA/QC  
- Tools that help researchers and practitioners compare systems,
  evaluate interventions, and link management to soil outcomes

------------------------------------------------------------------------

## 🚀 Installation

Install the development version from GitHub:

``` r
# install.packages("devtools")
devtools::install_github("DanielManter-USDA/SHMI")
```

------------------------------------------------------------------------

# 📘 Quick Start

SHMI supports **three user‑friendly workflows**:

------------------------------------------------------------------------

# **1. Minimal R‑native workflow**

*(No Excel required)*

``` r
library(SHMI)

# Load the built-in example dataset
data(shmi_example)

# Compute SHMI
result <- build_shmi(shmi_example)

result$indicator_df
```

The built‑in shmi_example dataset has already been processed through
[`prepare_shmi_inputs()`](https://danielmanter-usda.github.io/SHMI/reference/prepare_shmi_inputs.md),
so it can be passed directly to
[`build_shmi()`](https://danielmanter-usda.github.io/SHMI/reference/build_shmi.md).

This is ideal for teaching, demos, and unit tests.

------------------------------------------------------------------------

# **2. Download the fully populated example Excel file**

``` r
library(SHMI)

# Save example Excel file to working directory
download_shmi_example("SHMI_example.xlsx")

# Prepare inputs
inputs <- prepare_shmi_inputs("SHMI_example.xlsx")

# Compute SHMI
result <- build_shmi(inputs)

result$indicator_df
```

This file contains **realistic management data** and is ready to use
immediately.

------------------------------------------------------------------------

# **3. Download the blank SHMI template**

(This is the standard workflow for analyzing your own management data)

``` r
library(SHMI)

# Download a blank SHMI template to a known location
path <- "myDir/SHMI_template.xlsx"
download_shmi_template(path = path)

# (1) Open "myDir/SHMI_template.xlsx" in Excel
# (2) Enter your management data into each sheet
# (3) Save the completed file as "myDir/my_shmi_inputs.xlsx"

# Prepare inputs
user_file <- "myDir/my_shmi_inputs.xlsx"
inputs <- prepare_shmi_inputs(user_file)

# Compute SHMI
result <- build_shmi(inputs)

result$indicator_df
```

**Important:** The template is intentionally blank. It contains the
required sheets and column structure, but no management data. You must
fill in your crop, disturbance, amendment, and animal records before
running
[`prepare_shmi_inputs()`](https://danielmanter-usda.github.io/SHMI/reference/prepare_shmi_inputs.md).
[`prepare_shmi_inputs()`](https://danielmanter-usda.github.io/SHMI/reference/prepare_shmi_inputs.md)
performs full validation and will return clear, actionable error
messages if:

- required sheets or columns are missing
- dates are invalid
- MGT_combo identifiers are inconsistent
- crop windows are malformed
- disturbance or amendment entries are incomplete

This workflow is the one most users will follow when computing SHMI for
their own fields or research datasets

------------------------------------------------------------------------

## 📂 Workflow Overview

SHMI provides a structured, end‑to‑end workflow:

### **1. Template & Example Files**

- Blank Template:
  [`download_shmi_template()`](https://danielmanter-usda.github.io/SHMI/reference/download_shmi_template.html)  
- Example Excel:
  [`download_shmi_example()`](https://danielmanter-usda.github.io/SHMI/reference/download_shmi_example.html)  
- R‑native dataset:
  [`data(shmi_example)`](https://danielmanter-usda.github.io/SHMI/reference/shmi_example.html)

### **2. Input Preparation**

- Validates required columns  
- Expands crop windows to daily resolution  
- Summarizes disturbance and organic inputs  
- Harmonizes dates and management events  
- [`prepare_shmi_inputs()`](https://danielmanter-usda.github.io/SHMI/reference/prepare_shmi_inputs.html)

### **3. Sub‑index Computation**

- Cover —
  [`compute_cover()`](https://danielmanter-usda.github.io/SHMI/reference/compute_cover.html)  
- Diversity —
  [`compute_diversity()`](https://danielmanter-usda.github.io/SHMI/reference/compute_diversity.html)  
- Disturbance —
  [`compute_disturbance()`](https://danielmanter-usda.github.io/SHMI/reference/compute_disturbance.html)  
- Organic Inputs —
  [`compute_orginput()`](https://danielmanter-usda.github.io/SHMI/reference/compute_orginput.html)

### **4. Final SHMI Calculation**

- [`build_shmi()`](https://danielmanter-usda.github.io/SHMI/reference/build_shmi.html)

------------------------------------------------------------------------

## 📚 Documentation

Full documentation and examples:  
👉 <https://danielmanter-usda.github.io/SHMI/>

Includes:

- Function reference  
- Workflow overview  
- Example data  
- Template documentation  
- Articles and vignettes

------------------------------------------------------------------------

## 🤝 Contributing

Issues, suggestions, and pull requests are welcome:  
👉 <https://github.com/DanielManter-USDA/SHMI/issues>

------------------------------------------------------------------------

### License

This software is a work of the United States Government and is not
subject to copyright protection in the United States.  
Foreign copyrights may apply.

Distributed under the MIT license.

------------------------------------------------------------------------

### 📌 **Citation**

If you use SHMI in a publication, please cite:

Manter DK, Moore JM. (2026). *SHMI: Soil Health Management Index R
package.*

------------------------------------------------------------------------
