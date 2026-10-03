# SHMI Overview

## Introduction

The Soil Health Management Index (SHMI) turns a record of field
management into a single 0-100 score. It combines four sub-indices, each
also scored 0-100, with weights calibrated against measured soil health:

- **Cover** (weight 0.40): the share of days with living plants in the
  growing and non-growing seasons, set by the site’s climate.
- **Organic inputs (OrgInput)** (0.32): the share of years with an
  organic amendment or grazing animals.
- **Diversity** (0.15): the average number of plant species per year.
- **Inverse disturbance (InvDist)** (0.13): how little the soil was
  tilled; 100 means no tillage.

This vignette walks through the standard workflow: fill in the Excel
workbook, prepare the inputs, add climate, compute SHMI, and review the
results.

SHMI 1.0 was calibrated on 354 US plots at 74 sites of the North
American Project to Evaluate Soil Health Measurements (NAPESHM), mostly
annual cropping systems plus perennial and native reference systems. It
is most reliable for comparing practices at the same site, and should be
recalibrated before use in other regions.

``` r
library(SHMI)
```

## 1. Get a workbook

SHMI reads a standard Excel workbook. Start from the blank template, or
from a completed example to see how entries should look:

``` r
download_shmi_template("SHMI_template.xlsx")  # blank
download_shmi_example()                       # completed example
```

The completed example is also installed with the package, and
[`get_shmi_example()`](https://danielmanter-usda.github.io/SHMI/reference/get_shmi_example.md)
returns its path. The rest of this vignette uses it: eight management
units from a long-term experiment (2020-2024), with continuous corn and
a rotation under several nitrogen and manure treatments.

The workbook has one sheet per kind of record, each with column names on
the fourth row:

| Sheet | Records |
|----|----|
| `Mgt_Unit` | Management units (`MGT_combo`), with study, farm, field, treatment, and optionally the soil sampling date (`MGT_sample_date`) |
| `Crop_Diversity` | Crops: name, category, and plant, harvest, and termination dates |
| `Soil_Disturbance` | Tillage and other soil-disturbing passes |
| `Soil_Amendments` | Amendments, including organic inputs |
| `Animal_Diversity` | Periods with grazing or other animals |

The disturbance, amendment, and animal sheets may be left empty. Each
crop is entered by name with its dates; mixtures are entered as one row
per species. Sequence numbers (`CD_seq_num`) and mixture flags
(`CD_mix`) are not needed.

The crop category (`CD_cat`) decides how a crop ends, so it is worth
getting right. *Cash*, *Cover*, and *Annual* crops end at their harvest
or termination; *Perennial* (and *Woody perennial*) stands continue
through harvests until a termination; *Fallow* marks bare-fallow
periods. Categories are matched regardless of capitalization. A cover
crop interseeded, broadcast, or frost-seeded into a growing crop is
entered with its own planting and termination dates, and does not end at
the companion crop’s harvest.

## 2. Prepare the inputs

``` r
inputs <- prepare_shmi_inputs("my_SHMI_inputs.xlsx")   # your own workbook
```

With the installed example:

``` r
inputs <- prepare_shmi_inputs(get_shmi_example(), verbose = FALSE)
names(inputs)
#>  [1] "rot_bounds"  "mgt"         "crop"        "harvests"    "dist"       
#>  [6] "amend"       "animal"      "yield"       "n_rate"      "assumptions"
head(inputs$crop)
#> # A tibble: 6 × 8
#>   MGT_combo        episode_id CD_cat CD_name crop_start crop_end   start_imputed
#>   <chr>                 <int> <chr>  <chr>   <date>     <date>     <lgl>        
#> 1 MLSH_ARDEC_200A…          1 Annual Corn    2020-04-27 2020-10-13 FALSE        
#> 2 MLSH_ARDEC_200A…          2 Annual Corn    2021-05-08 2021-10-20 FALSE        
#> 3 MLSH_ARDEC_200A…          3 Annual Corn    2022-04-27 2022-10-20 FALSE        
#> 4 MLSH_ARDEC_200A…          4 Annual Corn    2023-04-24 2023-10-23 FALSE        
#> 5 MLSH_ARDEC_200A…          5 Annual Corn    2024-05-01 2024-10-22 FALSE        
#> 6 MLSH_ARDEC_200A…          1 Annual Corn    2020-04-27 2020-10-13 FALSE        
#> # ℹ 1 more variable: end_imputed <lgl>
```

[`prepare_shmi_inputs()`](https://danielmanter-usda.github.io/SHMI/reference/prepare_shmi_inputs.md):

1.  **Validates the workbook** with
    [`validate_excel_input()`](https://danielmanter-usda.github.io/SHMI/reference/validate_excel_input.md)
    and stops with a list of problems if, for example, a required sheet
    or column is missing, a unit is not listed in `Mgt_Unit`, or a
    disturbance pass has no date.
2.  **Builds crop episodes**: one row per species per continuous period
    of presence. Mixtures, relays, and intercrops are simply overlapping
    episodes. Harvest rows without a plant date are attached to a
    standing perennial as cuttings.
3.  **Fills in missing dates**, following fixed rules. A crop with no
    plant date starts where the previous crop ended, or at the start of
    the window. A crop with no end date ends at the next planting, or at
    the end of the window, and earlier if intensive tillage is recorded
    after its planting (see *Crops without an end date* below).
4.  **Sets the evaluation window** from 1 January of the first year with
    a record to 31 December of the last, so bare periods before the
    first and after the last recorded event count as bare.

It returns a list:

| Element | Contents |
|----|----|
| `rot_bounds` | Rotation start and end for each unit |
| `mgt` | Management-unit details |
| `crop` | Species episodes, with `crop_start` and `crop_end` |
| `dist`, `amend`, `animal` | Disturbance, amendment, and animal events |
| `yield`, `n_rate` | Yields and nitrogen rates, if requested |
| `assumptions` | Every date that was filled in, and every value to review |

### Reviewing assumptions

Management records are rarely complete, particularly at the start and
end of a record kept by calendar year. Rather than filling gaps
silently,
[`prepare_shmi_inputs()`](https://danielmanter-usda.github.io/SHMI/reference/prepare_shmi_inputs.md)
records each assumption:

``` r
table(inputs$assumptions$type)
#> < table of extent 0 >

# Items flagged for review, such as a perennial species entered as an annual
subset(inputs$assumptions, level == "check")
#> # A tibble: 0 × 8
#> # ℹ 8 variables: MGT_combo <chr>, source <chr>, name <chr>, date_start <date>,
#> #   date_end <date>, level <chr>, type <chr>, message <chr>
```

Rows with `level == "assumption"` are routine gap-filling. Rows with
`level == "check"` usually point to a data-entry issue worth correcting
in the workbook: a perennial species entered as an annual (or the
reverse), an unrecognized crop category or placeholder name, an annual
crop lasting more than 400 days, an imputed planting date (listed with
the disturbance dates that may be the real planting), a crop running to
the end of the window although tillage is recorded after planting, or a
unit with no crops at all.
[`?prepare_shmi_inputs`](https://danielmanter-usda.github.io/SHMI/reference/prepare_shmi_inputs.md)
describes each type.

### Crops without an end date

A crop with no harvest or termination record first gets an imputed end:
the next planting or, if there is none, the end of the window. It then
ends earlier on the first day after planting with intensive tillage,
meaning a day whose passes sum to STIR ≥ 80, or whose EPA tillage
intensity (mixed depth / 30 cm) is ≥ 0.252. Both thresholds are the
lower bound of the conventional-tillage class. Each such change is
recorded as `end_intensive_tillage`:

``` r
subset(inputs$assumptions, type == "end_intensive_tillage")
#> # A tibble: 0 × 8
#> # ℹ 8 variables: MGT_combo <chr>, source <chr>, name <chr>, date_start <date>,
#> #   date_end <date>, level <chr>, type <chr>, message <chr>
```

The scale is chosen from the data (`tillage_end = "auto"`: EPA when
every pass has a depth, otherwise STIR); set `tillage_end = "none"` to
switch the rule off.

### Choosing the evaluation window

By default the window runs over whole calendar years, from the first to
the last year with a record. To score a fixed period instead, give start
and end dates; events outside the window are dropped, crops and grazing
periods are clipped to it, and the window runs exactly between the two
dates:

``` r
inputs_2022_23 <- prepare_shmi_inputs(
  get_shmi_example(), verbose = FALSE,
  start_date_override = "2022-01-01",
  end_date_override   = "2023-12-31"
)
inputs_2022_23$rot_bounds
#> # A tibble: 8 × 5
#>   MGT_combo                   rot_start  rot_end    rot_start_yr rot_end_yr
#>   <chr>                       <date>     <date>            <dbl>      <dbl>
#> 1 MLSH_ARDEC_200A_DMP-Manure  2022-01-01 2023-12-31         2022       2023
#> 2 MLSH_ARDEC_200A_DMP-Manure+ 2022-01-01 2023-12-31         2022       2023
#> 3 MLSH_ARDEC_200A_DMP-N0      2022-01-01 2023-12-31         2022       2023
#> 4 MLSH_ARDEC_200A_DMP-N160    2022-01-01 2023-12-31         2022       2023
#> 5 MLSH_ARDEC_200A_Rot1-N0     2022-01-01 2023-12-31         2022       2023
#> 6 MLSH_ARDEC_200A_Rot1-N120   2022-01-01 2023-12-31         2022       2023
#> 7 MLSH_ARDEC_200A_Rot1-N180   2022-01-01 2023-12-31         2022       2023
#> 8 MLSH_ARDEC_200A_Rot1-N60    2022-01-01 2023-12-31         2022       2023
```

Other options include `exclude` (leave out some units),
`end_at_sample_date` (stop each unit at its soil sampling date, taken
from the `MGT_sample_date` column of `Mgt_Unit`), and `calc_yield` /
`calc_n_rate` (also return yields in kg/ha and annual nitrogen rates).
Overrides are best placed on calendar-year boundaries, because Organic
Inputs and Inverse Disturbance are scored by calendar year.

## 3. Add climate

Cover splits the year into a growing and a non-growing season for each
management unit. A month is in the growing season when its long-term
mean temperature is at least 5 °C and, unless the unit is irrigated, it
is not dry (precipitation in mm at least twice the mean temperature in
°C). Each unit’s coordinates (`MGT_lat`, `MGT_lon`) and irrigation
method (`MGT_irr_cat`) are recorded on the Mgt_Unit tab.
[`get_shmi_climate()`](https://danielmanter-usda.github.io/SHMI/reference/get_shmi_climate.md)
takes the monthly normals from WorldClim at those coordinates (it needs
the `geodata` and `terra` packages):

``` r
climate <- get_shmi_climate(inputs)
```

The example’s units are sprinkler-irrigated, so none of their months is
treated as too dry for growth:

``` r
inputs$mgt[, c("MGT_combo", "MGT_irr_cat", "irrigated")]
#> # A tibble: 8 × 3
#>   MGT_combo                   MGT_irr_cat       irrigated
#>   <chr>                       <chr>             <lgl>    
#> 1 MLSH_ARDEC_200A_DMP-N0      Sprinkler, Linear TRUE     
#> 2 MLSH_ARDEC_200A_DMP-Manure  Sprinkler, Linear TRUE     
#> 3 MLSH_ARDEC_200A_DMP-N160    Sprinkler, Linear TRUE     
#> 4 MLSH_ARDEC_200A_DMP-Manure+ Sprinkler, Linear TRUE     
#> 5 MLSH_ARDEC_200A_Rot1-N0     Sprinkler, Linear TRUE     
#> 6 MLSH_ARDEC_200A_Rot1-N60    Sprinkler, Linear TRUE     
#> 7 MLSH_ARDEC_200A_Rot1-N120   Sprinkler, Linear TRUE     
#> 8 MLSH_ARDEC_200A_Rot1-N180   Sprinkler, Linear TRUE
```

Any source of monthly normals works, as long as the table has one row
per `MGT_combo` with `tavg_01` … `tavg_12` (°C) and `prec_01` …
`prec_12` (mm). Here, typical values for a temperate site are entered by
hand:

``` r
climate <- data.frame(MGT_combo = inputs$mgt$MGT_combo)
climate[sprintf("tavg_%02d", 1:12)] <- as.list(c(-5, -3, 3, 10, 16, 21, 24, 23, 18, 11, 4, -2))
climate[sprintf("prec_%02d", 1:12)] <- as.list(c(20, 25, 50, 70, 110, 115, 95, 85, 70, 50, 35, 25))
growing_months(climate[1, ])
#>                          Jan   Feb   Mar  Apr  May  Jun  Jul  Aug  Sep  Oct
#> MLSH_ARDEC_200A_DMP-N0 FALSE FALSE FALSE TRUE TRUE TRUE TRUE TRUE TRUE TRUE
#>                          Nov   Dec
#> MLSH_ARDEC_200A_DMP-N0 FALSE FALSE
```

## 4. Compute SHMI

``` r
result <- build_shmi(inputs, climate)
result$indicator_df
#> # A tibble: 8 × 16
#>   MGT_combo  MGT_study MGT_farm MGT_field MGT_trt irrigated  SHMI Cover OrgInput
#>   <chr>      <chr>     <chr>    <chr>     <chr>   <lgl>     <dbl> <dbl>    <dbl>
#> 1 MLSH_ARDE… MLSH      ARDEC    200A      DMP-Ma… TRUE       67.1  70.0      100
#> 2 MLSH_ARDE… MLSH      ARDEC    200A      DMP-Ma… TRUE       67.1  70.0      100
#> 3 MLSH_ARDE… MLSH      ARDEC    200A      DMP-N0  TRUE       35.4  70.0        0
#> 4 MLSH_ARDE… MLSH      ARDEC    200A      DMP-N1… TRUE       35.4  70.0        0
#> 5 MLSH_ARDE… MLSH      ARDEC    200A      Rot1-N0 TRUE       41.0  70.0        0
#> 6 MLSH_ARDE… MLSH      ARDEC    200A      Rot1-N… TRUE       41.0  70.0        0
#> 7 MLSH_ARDE… MLSH      ARDEC    200A      Rot1-N… TRUE       41.0  70.0        0
#> 8 MLSH_ARDE… MLSH      ARDEC    200A      Rot1-N… TRUE       41.0  70.0        0
#> # ℹ 7 more variables: Diversity <dbl>, InvDist <dbl>, Cover_growing <dbl>,
#> #   Cover_nongrowing <dbl>, Richness <dbl>, TI_tillage <dbl>,
#> #   tillage_designation <chr>
```

`indicator_df` has one row per management unit, with `SHMI`, `Cover`,
`OrgInput`, `Diversity` and `InvDist`, the two parts of Cover
(`Cover_growing`, `Cover_nongrowing`), the average number of species per
year (`Richness`), and the unit’s study, farm, field and treatment. The
result also records the weights, the tillage scale used (`dist_meth`),
whether the scores are official, the package version and a timestamp.

**Tillage.**
[`build_shmi()`](https://danielmanter-usda.github.io/SHMI/reference/build_shmi.md)
computes tillage intensity as USDA’s Tillage Disturbance Index for Soil
Carbon (T-DISC) does: per crop interval, from each pass’s mixing
efficiency and depth. Each pass names its implement (`SD_equip`), whose
values come from T-DISC
([`tdisc_implements()`](https://danielmanter-usda.github.io/SHMI/reference/tdisc_implements.md),
[`tdisc_mapping()`](https://danielmanter-usda.github.io/SHMI/reference/tdisc_mapping.md))
or from a table you supply with `implements =`. `SD_mixeff` and
`SD_depth` (inches) are overrides: blank means the implement’s values,
and either can be entered alone. STIR values go in `SD_stir` and are
scored with `dist_meth = "STIR"`, on the same crop intervals and
windows. The result also gives each unit’s T-DISC tillage designation
(NT, RT or CT).

## 5. Custom weights

For research or scenario analysis, the weights can be changed. They are
rescaled to sum to 1, and the scores are flagged as not official:

``` r
result_equal <- build_shmi(inputs, climate,
                           weights = c(Cover = 0.25, OrgInput = 0.25,
                                       Diversity = 0.25, InvDist = 0.25))
shmi_weights()   # the official weights
```

## 6. How missing records are scored

SHMI treats a missing record as a practice that did not happen:

- **No disturbance records** means no tillage, so InvDist = 100. This is
  how continuous no-till is represented.
- **No crop on a given day** means no cover that day. A fallow reference
  site scores Cover = 0 and Diversity = 0. A unit with management
  records but no crop records is flagged (`no_crop_records`), so a
  forgotten crop sheet is not mistaken for a fallow.
- **No amendment or animal records** means no organic inputs, so
  OrgInput = 0.

Record every tillage pass, planting, harvest, and amendment for the
period being evaluated, so that gaps in the records are not mistaken for
practices.

## 7. The sub-indices one at a time

Each sub-index can be computed directly from the prepared inputs:

``` r
compute_cover(inputs$crop, inputs$rot_bounds, climate)
#> # A tibble: 8 × 4
#>   MGT_combo                   Cover Cover_growing Cover_nongrowing
#>   <chr>                       <dbl>         <dbl>            <dbl>
#> 1 MLSH_ARDEC_200A_DMP-Manure   70.0          81.4                0
#> 2 MLSH_ARDEC_200A_DMP-Manure+  70.0          81.4                0
#> 3 MLSH_ARDEC_200A_DMP-N0       70.0          81.4                0
#> 4 MLSH_ARDEC_200A_DMP-N160     70.0          81.4                0
#> 5 MLSH_ARDEC_200A_Rot1-N0      70.0          81.4                0
#> 6 MLSH_ARDEC_200A_Rot1-N120    70.0          81.4                0
#> 7 MLSH_ARDEC_200A_Rot1-N180    70.0          81.4                0
#> 8 MLSH_ARDEC_200A_Rot1-N60     70.0          81.4                0
compute_diversity(inputs$crop, inputs$rot_bounds)
#> # A tibble: 8 × 3
#>   MGT_combo                   Diversity Richness
#>   <chr>                           <dbl>    <dbl>
#> 1 MLSH_ARDEC_200A_DMP-Manure          0        1
#> 2 MLSH_ARDEC_200A_DMP-Manure+         0        1
#> 3 MLSH_ARDEC_200A_DMP-N0              0        1
#> 4 MLSH_ARDEC_200A_DMP-N160            0        1
#> 5 MLSH_ARDEC_200A_Rot1-N0             0        1
#> 6 MLSH_ARDEC_200A_Rot1-N120           0        1
#> 7 MLSH_ARDEC_200A_Rot1-N180           0        1
#> 8 MLSH_ARDEC_200A_Rot1-N60            0        1
compute_disturbance(inputs$dist, inputs$rot_bounds, inputs$crop, inputs$harvests)
#> # A tibble: 8 × 5
#>   MGT_combo                   InvDist    TI designation n_intervals
#>   <chr>                         <dbl> <dbl> <chr>             <int>
#> 1 MLSH_ARDEC_200A_DMP-Manure     56.8 0.391 CT                    6
#> 2 MLSH_ARDEC_200A_DMP-Manure+    56.8 0.391 CT                    6
#> 3 MLSH_ARDEC_200A_DMP-N0         56.8 0.391 CT                    6
#> 4 MLSH_ARDEC_200A_DMP-N160       56.8 0.391 CT                    6
#> 5 MLSH_ARDEC_200A_Rot1-N0       100   0     NT                    6
#> 6 MLSH_ARDEC_200A_Rot1-N120     100   0     NT                    6
#> 7 MLSH_ARDEC_200A_Rot1-N180     100   0     NT                    6
#> 8 MLSH_ARDEC_200A_Rot1-N60      100   0     NT                    6
compute_orginput(inputs$rot_bounds, inputs$amend, inputs$animal)
#> # A tibble: 8 × 2
#>   MGT_combo                   OrgInput
#>   <chr>                          <dbl>
#> 1 MLSH_ARDEC_200A_DMP-Manure       100
#> 2 MLSH_ARDEC_200A_DMP-Manure+      100
#> 3 MLSH_ARDEC_200A_DMP-N0             0
#> 4 MLSH_ARDEC_200A_DMP-N160           0
#> 5 MLSH_ARDEC_200A_Rot1-N0            0
#> 6 MLSH_ARDEC_200A_Rot1-N120          0
#> 7 MLSH_ARDEC_200A_Rot1-N180          0
#> 8 MLSH_ARDEC_200A_Rot1-N60           0
```

The functions also accept small tables built by hand, which is a quick
way to see how each one responds to a change in management. Here is one
field over two years: corn followed by a cereal rye cover crop, then
soybean.

``` r
crop <- data.frame(
  MGT_combo  = "field_1",
  CD_name    = c("Corn", "Rye", "Soybean"),
  crop_start = as.Date(c("2019-05-01", "2019-10-15", "2020-05-10")),
  crop_end   = as.Date(c("2019-09-30", "2020-04-20", "2020-09-25"))
)
rot_bounds <- data.frame(
  MGT_combo    = "field_1",
  rot_start    = as.Date("2019-01-01"),
  rot_end      = as.Date("2020-12-31"),
  rot_start_yr = 2019,
  rot_end_yr   = 2020
)
climate_1 <- climate[1, ]
climate_1$MGT_combo <- "field_1"
```

**Cover** is the share of days with a living crop in each season. The
rye keeps the soil covered through most of the non-growing season:

``` r
compute_cover(crop, rot_bounds, climate_1)
#> # A tibble: 1 × 4
#>   MGT_combo Cover Cover_growing Cover_nongrowing
#>   <chr>     <dbl>         <dbl>            <dbl>
#> 1 field_1    73.1          76.9             50.2
```

**Diversity** counts the species present each year: corn and rye in
2019, rye and soybean in 2020, so two species a year. One species a year
scores 0 and eight or more score 100:

``` r
compute_diversity(crop, rot_bounds)
#> # A tibble: 1 × 3
#>   MGT_combo Diversity Richness
#>   <chr>         <dbl>    <dbl>
#> 1 field_1        14.3        2
```

**Inverse disturbance** is computed as in USDA’s T-DISC tool. Each cash
crop defines a crop interval, ending at its harvest; passes are grouped
into tillage windows around planting; and the interval is rated by its
most intense window. Here a heavy disk before corn and a planter pass
each year are given by implement name, so their mixing efficiency and
depth come from T-DISC
([`tdisc_implements()`](https://danielmanter-usda.github.io/SHMI/reference/tdisc_implements.md)):

``` r
dist <- data.frame(
  MGT_combo = "field_1",
  SD_date   = as.Date(c("2019-04-20", "2019-05-01", "2020-05-10")),
  SD_equip  = c("HARROW, DISK, TANDEM, HEAVYDUTY", "PLANTER, REGULAR", "PLANTER, REGULAR")
)
harvests <- data.frame(
  MGT_combo = "field_1", CD_name = c("Corn", "Soybean"), CD_cat = "cash",
  harv_date = as.Date(c("2019-09-30", "2020-09-25"))
)
res <- compute_disturbance(dist, rot_bounds, crop, harvests, details = TRUE)
res
#>   MGT_combo  InvDist        TI designation n_intervals
#> 1   field_1 82.73776 0.1526767          RT           3
attr(res, "intervals")
#> # A tibble: 3 × 9
#>   MGT_combo start      end        plant           TI class_value score  days
#>   <chr>     <date>     <date>     <date>       <dbl>       <dbl> <dbl> <dbl>
#> 1 field_1   2019-01-01 2019-09-30 2019-05-01 0.4           0.449  55.1   273
#> 2 field_1   2019-10-01 2020-09-25 2020-05-10 0.00667       0.01   99     361
#> 3 field_1   2020-09-26 2020-12-31 NA         0             0     100      97
#> # ℹ 1 more variable: designation <chr>
```

The corn interval is rated 0.40 (the disk; conventional till), the
soybean interval only by its planter pass, and the score is their
average weighted by interval length. Values for any implement can be
replaced with your own:

``` r
my_disk <- data.frame(implement = "HARROW, DISK, TANDEM, HEAVYDUTY",
                      mixing_efficiency = 0.6, depth_cm = 10)
compute_disturbance(dist, rot_bounds, crop, harvests, implements = my_disk)
#>   MGT_combo  InvDist        TI designation n_intervals
#> 1   field_1 91.96224 0.0779845          RT           3
```

**Organic inputs**: manure applied in one of the two years, and no
animals:

``` r
amend  <- data.frame(MGT_combo = "field_1",
                     SA_date = as.Date("2019-04-01"), SA_cat = "Organic")
animal <- data.frame(MGT_combo = character(),
                     AD_start_date = as.Date(character()),
                     AD_end_date = as.Date(character()))
compute_orginput(rot_bounds, amend, animal)
#> # A tibble: 1 × 2
#>   MGT_combo OrgInput
#>   <chr>        <dbl>
#> 1 field_1         50
```

## 8. Plotting results

One unit, with a gauge for each sub-index and for overall SHMI:

``` r
plot_shmi_gauge(result$indicator_df, row = 1)
```

![](SHMI-overview_files/figure-html/plot-gauge-1.png)

Many units, overall SHMI sorted by score:

``` r
plot_shmi_lollipop(result$indicator_df)
```

![](SHMI-overview_files/figure-html/plot-lollipop-1.png)

Select a unit by name with `MGT_combo = "..."` instead of `row`.

## 9. Interpreting SHMI

Higher scores indicate management that is more supportive of soil
health: more of the year under living cover, more frequent organic
inputs, more plant species each year, and less tillage.

When comparing units, keep the weights in mind. A unit that scores 0 on
one sub-index cannot score above 100 × (1 − that sub-index’s weight): a
system with no organic inputs, for example, can reach at most 68.3
however well it does otherwise. Looking at the four sub-indices
alongside SHMI shows which practices drive a unit’s score. SHMI is most
informative for comparing practices at the same site; a single score
predicted for a new site is typically within about 13 soil-health
points.

## Further reading

- [`?prepare_shmi_inputs`](https://danielmanter-usda.github.io/SHMI/reference/prepare_shmi_inputs.md):
  workbook structure, crop-date rules, the assumptions table, and
  overrides.
- [`?build_shmi`](https://danielmanter-usda.github.io/SHMI/reference/build_shmi.md)
  and
  [`?shmi_weights`](https://danielmanter-usda.github.io/SHMI/reference/shmi_weights.md):
  the index and its official weights.
- [`?compute_cover`](https://danielmanter-usda.github.io/SHMI/reference/compute_cover.md),
  [`?growing_months`](https://danielmanter-usda.github.io/SHMI/reference/growing_months.md),
  [`?get_shmi_climate`](https://danielmanter-usda.github.io/SHMI/reference/get_shmi_climate.md):
  Cover’s seasons and climate.
- [`?compute_diversity`](https://danielmanter-usda.github.io/SHMI/reference/compute_diversity.md),
  [`?compute_disturbance`](https://danielmanter-usda.github.io/SHMI/reference/compute_disturbance.md),
  [`?compute_orginput`](https://danielmanter-usda.github.io/SHMI/reference/compute_orginput.md):
  the other sub-indices.
- [`?shmi_components`](https://danielmanter-usda.github.io/SHMI/reference/shmi_components.md):
  all four sub-indices, for calibration or inspection.
- `NEWS.md`: what changed in each version.
