---
editor_options: 
  markdown: 
    wrap: 72
---

# SHMI 1.0.0

First public release.

## The index

SHMI scores a field's management record from 0 to 100:

SHMI = 0.400 Cover + 0.317 OrgInput + 0.153 Diversity + 0.130 InvDist

Each sub-index also runs from 0 to 100.

-   **Cover**: share of days with living plants in each unit's growing
    and non-growing seasons, set by its climate. A month is in the
    growing season when its mean temperature is at least 5 °C and,
    unless the unit is irrigated, its precipitation (mm) is at least
    twice its temperature (°C). The growing season counts 0.860 and the
    rest of the year 0.140.
-   **Organic Inputs**: share of years with an organic amendment or
    grazing animals. Grazing counts in every calendar year a grazing
    period spans.
-   **Diversity**: number of plant species (cash crops, forages and cover
    crops) in each 4-year span of the record, sliding one year at a time
    and averaged (a record of 4 years or fewer is one span); 0 for one
    species, 100 for eight or more. A corn-soybean rotation scores 14,
    corn-soybean-wheat 29, and corn-soybean-wheat with a rye cover 43.
    `compute_diversity(window = 1)` gives species per calendar year.
    Placeholder mixtures such as "8-species mix" count as that many
    species. Diversity's weight is fixed at 0.15 (see Calibration).
-   **Inverse Disturbance**: tillage intensity computed exactly as
    USDA's Tillage Disturbance Index for Soil Carbon (T-DISC, version
    1.1.1). Each cash crop defines a crop interval; passes fall into
    five tillage windows around planting; implements combine within a
    window by the EPA soil-mixing model; and each interval is rated by
    its most intense window. Each unit also receives T-DISC's
    designation: no-till, reduced till or conventional till. STIR
    records can be scored on the same intervals and windows.

## Calibration

The weights were calibrated against a soil-health score built from 11
laboratory indicators, adjusted for climate and soil texture, on 354 US
plots at 74 sites of the North American Project to Evaluate Soil Health
Measurements (NAPESHM). Each weight is the median of 1,000
cross-validated fits. Cover/Roots and Diversity share much of their
information, so their combined weight is well determined but its split
is not; Diversity's weight was fixed at 0.15, within the range where
cross-validated fit was unchanged, and the other weights were fitted
under that constraint. For
sites held out of the fitting, SHMI explained about a quarter of the
differences in soil health and ranked practices in the right order at
82% of sites. SHMI is calibrated for US systems; other regions should
recalibrate.

## The workbook

-   A standard Excel workbook (`download_shmi_template()`), with a
    completed example (`download_shmi_example()`, `get_shmi_example()`).
-   **Mgt_Unit**: one row per management unit, with its location
    (`MGT_lat`, `MGT_lon`) and irrigation method (`MGT_irr_cat`, "None"
    if rain-fed). `MGT_combo` is built automatically from study, farm,
    field and treatment.
-   **Crop_Diversity**: one row per crop species per planting, with
    planting, harvest and termination dates; no sequence numbers are
    needed.
-   **Soil_Disturbance**: each pass's implement is chosen from T-DISC's
    implements, and the workbook shows its T-DISC mixing efficiency and
    depth. `SD_mixeff` and `SD_depth` (inches) are optional overrides,
    either alone or together; STIR values have their own column
    (`SD_stir`).
-   **Soil_Amendments** and **Animal_Diversity**: organic amendments and
    grazing periods.

## Preparing the records

`prepare_shmi_inputs()` reads and validates the workbook and:

-   converts crop records into species episodes, so mixtures, relays,
    intercrops and perennial cuttings need no special coding;
-   fills gaps with fixed rules (a crop without an end date ends at the
    next planting, at the first intensive tillage, or at the end of the
    record) and reports every assumption, along with data checks that
    flag likely entry errors, in `$assumptions`;
-   scores each unit from 1 January of its first year with a record to
    31 December of its last, or over fixed dates, or up to each unit's
    soil sampling date;
-   optionally converts yields to kg/ha;
-   optionally converts nitrogen rates (fertilizer and organic sources)
    to kg N/ha and assigns them to the crop they were applied for
    (`calc_n_rate = TRUE`). Each application counts toward the first
    cash or perennial harvest after it, so a crop's N runs from the
    previous harvest (the unit's first from the start of its record) to
    its own harvest, and fall manure or fertilizer applied after
    harvest goes to the next crop. Cover crops and fallow do not end a
    crop's window. `$n_rate` gives one row per unit and harvest
    (`crop_year`, `harvest_date`, `crop`, `N_kg_ha`); `crop_year` is the
    year of the harvest and matches `$yield$year`. Calendar-year totals
    are in `$n_rate_calendar`, and `$n_applications` lists each
    application with its calendar and crop year. N applied after a
    unit's last harvest, and units without harvest dates (which fall
    back to calendar years), are reported in `$assumptions`. The first
    crop in each unit's record has no previous harvest, so N applied
    before the record began (for example the previous fall) is missing;
    it is marked `first_in_record` and reported.

Missing records mean a practice did not happen: no tillage, no cover or
no organic input.

## Main functions

-   `prepare_shmi_inputs()`: read, validate and prepare a workbook.
-   `get_shmi_climate()`: WorldClim monthly climate normals at each
    unit's coordinates (needs `geodata` and `terra`).
-   `build_shmi()`: the four sub-indices and SHMI, with the official
    weights (`shmi_weights()`) or custom weights for research.
-   `compute_cover()`, `compute_orginput()`, `compute_diversity()`,
    `compute_disturbance()` and `shmi_components()`: the sub-indices on
    their own.
-   `tdisc_implements()` and `tdisc_mapping()`: the T-DISC implement
    values and operation names used for tillage; a user table
    (`implements =`) can replace or add to them.
-   `plot_shmi_gauge()` and `plot_shmi_lollipop()`: results for one unit
    or many.
