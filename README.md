# **SHMI: Soil Health Management Index** <img src="man/figures/logo.png" align="right" width="120" />

<!-- badges: start -->
![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg?logo=open-source-initiative&logoColor=white)
<!-- badges: end -->

SHMI converts multi-year crop, disturbance, and amendment records into standardized soil-health management scores.

> **Scope.** SHMI 1.0 is calibrated on **US cropping systems**: 354 plots at 74 sites of the North American Project to Evaluate Soil Health Measurements (NAPESHM), mostly annual cropping systems plus perennial and native reference systems. It is most reliable for comparing practices at the same site. An independent test at Mexican sites showed it does not transfer directly to other regions without recalibration.

> **Version 1.0.0 is the first public release.** See [NEWS](https://github.com/DanielManter-USDA/SHMI/blob/master/NEWS.md).

---

The **SHMI** R package provides a complete, reproducible workflow for computing the Soil Health Management Index (SHMI) from a standardized Excel workbook. SHMI is a 0-100 score built from four management sub-indices, each also scored 0-100:

- **Cover** (weight 0.40): share of days with living plants in the growing and non-growing seasons, set by each site's climate
- **Organic Inputs** (0.32): share of years with an organic amendment or grazing animals
- **Diversity** (0.15): average number of plant species per year
- **Inverse Disturbance** (0.13): how little the soil was tilled, computed as in USDA's T-DISC tool

The package includes:

- Excel ingestion with validation and clear error messages
- crop records converted to species episodes, so mixtures, relays, intercrops, and perennial cuttings are handled without sequence numbers
- a report of every assumption made while filling gaps in the records, and data checks that flag likely entry errors
- evaluation windows by calendar year, fixed dates, or ending at each unit's soil sampling date
- mechanistic disturbance modeling
- yield and nitrogen-rate conversion to kg/ha
- climate-based growing seasons from WorldClim monthly normals (`get_shmi_climate()`)
- official weights, with optional custom weights for research
- plots for single units and for comparing many units

---

## ⭐ Why SHMI?

Agricultural management is multidimensional, and many soil health indicators respond to **long-term patterns**, not single-year practices. SHMI provides:

- A **rotation-scale** measure of management intensity
- A **standardized, reproducible** workflow for diverse datasets
- A **transparent scoring system** grounded in ecological function, with every assumption reported
- A **consistent template** for data entry and QA/QC
- Tools that help researchers and practitioners compare systems, evaluate interventions, and link management to soil outcomes

---

## 🚀 Installation

Install a released version (recommended for analyses, so results can be traced to a fixed version):

```r
# install.packages("remotes")
remotes::install_github("DanielManter-USDA/SHMI@v1.0.0")
```

Or the latest development version:

```r
remotes::install_github("DanielManter-USDA/SHMI")
```

---

# 📘 Quick Start

SHMI supports two workflows, depending on whether you want to try the package or analyze your own management data.

---

# **1. Use the fully populated example Excel file**
*(Fastest way to test the complete SHMI workflow)*

```r
library(SHMI)

# Save the example Excel file to your working directory
my_file <- download_shmi_example()

# ...or somewhere specific
my_file <- download_shmi_example(path = "~/Desktop")
```

Or skip the download and use the copy installed with the package:

```r
my_file <- get_shmi_example()
```

Now run the full workflow. Cover needs each unit's monthly climate, which `get_shmi_climate()` takes from WorldClim using the coordinates on the Mgt_Unit tab (it needs the `geodata` and `terra` packages):

```r
inputs  <- prepare_shmi_inputs(my_file)
climate <- get_shmi_climate(inputs)     # coordinates and irrigation from Mgt_Unit
result  <- build_shmi(inputs, climate)
result$indicator_df
```

The example contains eight management units from a long-term experiment (2020-2024), already formatted correctly. It is ideal for:

- testing SHMI end-to-end
- verifying installation and dependencies
- learning the expected input structure

---

# **2. Use the blank SHMI template**
*(Standard workflow for analyzing your own management data)*

```r
library(SHMI)

# Choose where to save the blank template (full file path)
template_file <- "myDir/SHMI_template.xlsx"

# Download the blank template
download_shmi_template(path = template_file)

# (1) Open "myDir/SHMI_template.xlsx" in Excel
# (2) Enter your management data into each sheet
# (3) Save the completed file as "myDir/my_SHMI_inputs.xlsx"
```

Then run:

```r
user_file <- "myDir/my_SHMI_inputs.xlsx"
inputs  <- prepare_shmi_inputs(user_file)
climate <- get_shmi_climate(inputs)     # needs MGT_lat and MGT_lon on Mgt_Unit
result  <- build_shmi(inputs, climate)
result$indicator_df
```

**Important:**
The template is intentionally blank. It contains the required sheets and column structure, but no management data. Fill in your crop, disturbance, amendment, and animal records before running `prepare_shmi_inputs()`. Enter each crop by name with its dates; mixtures are one row per species, and sequence numbers are not needed.

A few entry conventions matter for scoring:

- **Location and irrigation (`Mgt_Unit`):** enter each unit's latitude and longitude (`MGT_lat`, `MGT_lon`, decimal degrees) and its irrigation method (`MGT_irr_cat`, "None" if rain-fed); they set Cover's growing season.
- **Tillage (`Soil_Disturbance`):** choose each pass's implement from the T-DISC list (`SD_equip`); the template shows its T-DISC mixing efficiency and depth. Enter `SD_mixeff` or `SD_depth` only to override them, and STIR values, if you have them, in `SD_stir`.
- **Crop category (`CD_cat`):** use *Cash* or *Cover* (or *Annual*) for crops grown within a season, *Perennial* for stands kept more than one growing season, and *Fallow* for bare-fallow periods. A nurse crop sown with a perennial forage is annual.
- **Cover crops interseeded, broadcast, or frost-seeded into a growing crop** get their own planting date and their own termination date; they do not end at the companion crop's harvest.
- **Termination dates** matter most for cover crops and perennials. Without one, the crop runs to the next planting or to the end of the window (or ends earlier at intensive tillage, see below).
- **Soil sampling date (optional):** add `MGT_sample_date` in column O of `Mgt_Unit` to stop each unit's record at its sampling date (`end_at_sample_date = TRUE`).

`prepare_shmi_inputs()` validates the workbook and stops with clear, actionable error messages if, for example:

- required sheets or columns are missing
- a management unit (`MGT_combo`) is missing, duplicated, or not listed in `Mgt_Unit`
- a disturbance pass has a missing or invalid date
- disturbance values are non-numeric or negative

This is the workflow most users will follow when computing SHMI for their own fields or research datasets.

---

## 🔍 Reviewing assumptions

Management records are rarely complete, especially at the start and end of a record kept by calendar year. SHMI fills gaps with fixed rules and records every one:

```r
table(inputs$assumptions$type)

# Items flagged for review, e.g. a perennial species entered as an annual
subset(inputs$assumptions, level == "check")
```

Rows with `level == "assumption"` are routine gap-filling (for example, a crop with no end date ending at the next planting). Rows with `level == "check"` usually point to a data-entry issue worth correcting in the workbook, such as:

- a species usually grown as a perennial entered as an annual, or the reverse
- an unrecognized or missing crop category, or a placeholder species name
- an annual crop lasting more than 400 days, or a cover crop more than 480 days (usually a missing end date)
- an imputed planting date, listed with the disturbance dates that may be the real planting
- a crop running to the end of the window although tillage is recorded after planting
- a unit with management records but no crops (scored as bare soil)

---

## ⚙️ Settings, evaluation windows, and missing records

**Official settings.** `build_shmi()` uses the official weights and computes tillage intensity as USDA's **T-DISC** tool does: per crop interval, from each pass's mixing efficiency and depth. Each pass names its implement (`SD_equip`, chosen from the T-DISC list in the template), and its mixing efficiency and depth come from T-DISC's tables (`tdisc_implements()`, `tdisc_mapping()`) or from your own (`implements =`). `SD_mixeff` and `SD_depth` (inches) are overrides: leave them blank to use the implement's values, or enter either or both to replace them. STIR values go in `SD_stir` and are scored with `dist_meth = "STIR"`, on the same crop intervals. Custom weights can be supplied for research:

```r
result <- build_shmi(inputs, climate, weights = c(Cover = 0.25, OrgInput = 0.25,
                                                  Diversity = 0.25, InvDist = 0.25))
```

Scores with custom weights are flagged (`result$official` is `FALSE`) and are **not comparable** to the official SHMI scale.

**Climate and irrigation.** A month is in a unit's growing season when its mean temperature is at least 5 °C and, unless the unit is irrigated, it is not dry (precipitation in mm at least twice the temperature in °C). Record irrigation on the Mgt_Unit tab (`MGT_irr_cat`: the irrigation method, or "None" if rain-fed); `build_shmi()` reports each unit's `irrigated` flag. Any source of monthly normals can be used instead of `get_shmi_climate()`, as long as the table has `MGT_combo`, `tavg_01`...`tavg_12` and `prec_01`...`prec_12`; an `irrigated` column in it overrides Mgt_Unit.

**Evaluation window.** By default, each unit is scored from 1 January of its first year with a record to 31 December of its last, so bare periods before the first and after the last event are counted. To score a fixed period instead (the window then runs exactly between these dates):

```r
inputs <- prepare_shmi_inputs(user_file,
                              start_date_override = "2018-01-01",
                              end_date_override   = "2020-12-31")
```

To exclude management after soil sampling, add `MGT_sample_date` to `Mgt_Unit` and use `end_at_sample_date = TRUE`.

**Crops without an end date.** A crop with no harvest or termination record ends at the next planting or, if none, at the end of the window. It ends earlier on the first day after planting with intensive tillage (the day's passes sum to STIR ≥ 80, or EPA tillage intensity ≥ 0.252, the conventional-tillage threshold). Use `tillage_end = "none"` in `prepare_shmi_inputs()` to switch this rule off.

**Missing records mean "did not happen."** No disturbance records means no tillage (Inverse Disturbance = 100, as for continuous no-till); no crop means no cover; no amendments means no organic inputs. Record every tillage pass, planting, harvest, and amendment for the period being evaluated.

**Official weights.** The weights (`shmi_weights()`) are the medians of 1,000 cross-validated fits of SHMI against a soil-health score built from 11 laboratory indicators (adjusted for climate and soil texture) on 354 US plots at 74 NAPESHM sites, with tillage computed as in USDA's T-DISC. Within Cover, the growing season counts for 0.86 and the non-growing season for 0.14. Every weight was positive in all 1,000 fits. For sites held out of the fitting, SHMI explained about a quarter of the differences in soil health (R² = 0.27) and ranked practices in the right order at 82% of sites.

---

## 📊 Plotting results

```r
# One unit: gauges for each sub-index and overall SHMI
plot_shmi_gauge(result$indicator_df, MGT_combo = "my_field_1")

# Many units: overall SHMI, sorted
plot_shmi_lollipop(result$indicator_df)
```

---

## 📂 Workflow Overview

### **1. Template & Example Files**
- Blank Template: [`download_shmi_template()`](https://danielmanter-usda.github.io/SHMI/reference/download_shmi_template.html)
- Example Excel: [`download_shmi_example()`](https://danielmanter-usda.github.io/SHMI/reference/download_shmi_example.html)
- Installed example (no download): [`get_shmi_example()`](https://danielmanter-usda.github.io/SHMI/reference/get_shmi_example.html)

### **2. Input Preparation**
- [`prepare_shmi_inputs()`](https://danielmanter-usda.github.io/SHMI/reference/prepare_shmi_inputs.html)
- Validates the workbook ([`validate_excel_input()`](https://danielmanter-usda.github.io/SHMI/reference/validate_excel_input.html))
- Converts crop records into species episodes and fills missing dates (ending crops at intensive tillage where recorded)
- Sets calendar-year rotation bounds, or applies your evaluation window
- Optionally converts yields and nitrogen rates to kg/ha
- Returns an assumptions table for review

### **3. Climate**
- Monthly normals for Cover's growing season: [`get_shmi_climate()`](https://danielmanter-usda.github.io/SHMI/reference/get_shmi_climate.html)

### **4. Sub-index Computation**
- Cover: [`compute_cover()`](https://danielmanter-usda.github.io/SHMI/reference/compute_cover.html)
- Diversity: [`compute_diversity()`](https://danielmanter-usda.github.io/SHMI/reference/compute_diversity.html)
- Inverse Disturbance: [`compute_disturbance()`](https://danielmanter-usda.github.io/SHMI/reference/compute_disturbance.html)
- Organic Inputs: [`compute_orginput()`](https://danielmanter-usda.github.io/SHMI/reference/compute_orginput.html)

### **5. Final SHMI Calculation**
- [`build_shmi()`](https://danielmanter-usda.github.io/SHMI/reference/build_shmi.html), with the official weights from [`shmi_weights()`](https://danielmanter-usda.github.io/SHMI/reference/shmi_weights.html)
- All four sub-indices, for calibration or inspection: [`shmi_components()`](https://danielmanter-usda.github.io/SHMI/reference/shmi_components.html)

### **6. Visualization**
- [`plot_shmi_gauge()`](https://danielmanter-usda.github.io/SHMI/reference/plot_shmi_gauge.html)
- [`plot_shmi_lollipop()`](https://danielmanter-usda.github.io/SHMI/reference/plot_shmi_lollipop.html)

---

## 📚 Documentation

Full documentation and examples:
👉 [https://danielmanter-usda.github.io/SHMI/](https://danielmanter-usda.github.io/SHMI/)

Includes:

- Function reference
- The *SHMI Overview* vignette (`vignette("SHMI-overview", package = "SHMI")`)
- Template documentation

---

## 🤝 Contributing

Issues, suggestions, and pull requests are welcome:
👉 [https://github.com/DanielManter-USDA/SHMI/issues](https://github.com/DanielManter-USDA/SHMI/issues)

---

### License

This software is a work of the United States Government and is not subject to copyright protection in the United States.
Foreign copyrights may apply.

Distributed under the MIT license.

---

### 📌 **Citation**
If you use SHMI in a publication, please cite:

Manter DK, Moore JM. (2026). *SHMI: Soil Health Management Index R package.*

---
