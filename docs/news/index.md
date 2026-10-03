# Changelog

## SHMI 1.0.0

First public release.

### The index

SHMI scores a field’s management record from 0 to 100:

SHMI = 0.400 Cover + 0.317 OrgInput + 0.153 Diversity + 0.130 InvDist

Each sub-index also runs from 0 to 100.

- **Cover**: share of days with living plants in each unit’s growing and
  non-growing seasons, set by its climate. A month is in the growing
  season when its mean temperature is at least 5 °C and, unless the unit
  is irrigated, its precipitation (mm) is at least twice its temperature
  (°C). The growing season counts 0.860 and the rest of the year 0.140.
- **Organic Inputs**: share of years with an organic amendment or
  grazing animals. Grazing counts in every calendar year a grazing
  period spans.
- **Diversity**: average number of plant species per year (0 for one
  species, 100 for eight or more). Placeholder mixtures such as
  “8-species mix” count as that many species.
- **Inverse Disturbance**: tillage intensity computed exactly as USDA’s
  Tillage Disturbance Index for Soil Carbon (T-DISC, version 1.1.1).
  Each cash crop defines a crop interval; passes fall into five tillage
  windows around planting; implements combine within a window by the EPA
  soil-mixing model; and each interval is rated by its most intense
  window. Each unit also receives T-DISC’s designation: no-till, reduced
  till or conventional till. STIR records can be scored on the same
  intervals and windows.

### Calibration

The weights were calibrated against a soil-health score built from 11
laboratory indicators, adjusted for climate and soil texture, on 354 US
plots at 74 sites of the North American Project to Evaluate Soil Health
Measurements (NAPESHM). Each weight is the median of 1,000
cross-validated fits, and every weight was positive in all of them. For
sites held out of the fitting, SHMI explained about a quarter of the
differences in soil health and ranked practices in the right order at
82% of sites. SHMI is calibrated for US systems; other regions should
recalibrate.

### The workbook

- A standard Excel workbook
  ([`download_shmi_template()`](https://danielmanter-usda.github.io/SHMI/reference/download_shmi_template.md)),
  with a completed example
  ([`download_shmi_example()`](https://danielmanter-usda.github.io/SHMI/reference/download_shmi_example.md),
  [`get_shmi_example()`](https://danielmanter-usda.github.io/SHMI/reference/get_shmi_example.md)).
- **Mgt_Unit**: one row per management unit, with its location
  (`MGT_lat`, `MGT_lon`) and irrigation method (`MGT_irr_cat`, “None” if
  rain-fed). `MGT_combo` is built automatically from study, farm, field
  and treatment.
- **Crop_Diversity**: one row per crop species per planting, with
  planting, harvest and termination dates; no sequence numbers are
  needed.
- **Soil_Disturbance**: each pass’s implement is chosen from T-DISC’s
  implements, and the workbook shows its T-DISC mixing efficiency and
  depth. `SD_mixeff` and `SD_depth` (inches) are optional overrides,
  either alone or together; STIR values have their own column
  (`SD_stir`).
- **Soil_Amendments** and **Animal_Diversity**: organic amendments and
  grazing periods.

### Preparing the records

[`prepare_shmi_inputs()`](https://danielmanter-usda.github.io/SHMI/reference/prepare_shmi_inputs.md)
reads and validates the workbook and:

- converts crop records into species episodes, so mixtures, relays,
  intercrops and perennial cuttings need no special coding;
- fills gaps with fixed rules (a crop without an end date ends at the
  next planting, at the first intensive tillage, or at the end of the
  record) and reports every assumption, along with data checks that flag
  likely entry errors, in `$assumptions`;
- scores each unit from 1 January of its first year with a record to 31
  December of its last, or over fixed dates, or up to each unit’s soil
  sampling date;
- optionally converts yields and nitrogen rates to kg/ha.

Missing records mean a practice did not happen: no tillage, no cover or
no organic input.

### Main functions

- [`prepare_shmi_inputs()`](https://danielmanter-usda.github.io/SHMI/reference/prepare_shmi_inputs.md):
  read, validate and prepare a workbook.
- [`get_shmi_climate()`](https://danielmanter-usda.github.io/SHMI/reference/get_shmi_climate.md):
  WorldClim monthly climate normals at each unit’s coordinates (needs
  `geodata` and `terra`).
- [`build_shmi()`](https://danielmanter-usda.github.io/SHMI/reference/build_shmi.md):
  the four sub-indices and SHMI, with the official weights
  ([`shmi_weights()`](https://danielmanter-usda.github.io/SHMI/reference/shmi_weights.md))
  or custom weights for research.
- [`compute_cover()`](https://danielmanter-usda.github.io/SHMI/reference/compute_cover.md),
  [`compute_orginput()`](https://danielmanter-usda.github.io/SHMI/reference/compute_orginput.md),
  [`compute_diversity()`](https://danielmanter-usda.github.io/SHMI/reference/compute_diversity.md),
  [`compute_disturbance()`](https://danielmanter-usda.github.io/SHMI/reference/compute_disturbance.md)
  and
  [`shmi_components()`](https://danielmanter-usda.github.io/SHMI/reference/shmi_components.md):
  the sub-indices on their own.
- [`tdisc_implements()`](https://danielmanter-usda.github.io/SHMI/reference/tdisc_implements.md)
  and
  [`tdisc_mapping()`](https://danielmanter-usda.github.io/SHMI/reference/tdisc_mapping.md):
  the T-DISC implement values and operation names used for tillage; a
  user table (`implements =`) can replace or add to them.
- [`plot_shmi_gauge()`](https://danielmanter-usda.github.io/SHMI/reference/plot_shmi_gauge.md)
  and
  [`plot_shmi_lollipop()`](https://danielmanter-usda.github.io/SHMI/reference/plot_shmi_lollipop.md):
  results for one unit or many.
