---
editor_options: 
  markdown: 
    wrap: 72
---

# SHMI 2.0.0

First public release: the calibrated Soil Health Management Index
described in Moore and Manter (in review).

**Version numbers follow the published index.** SHMI v1 is the index of
Deel et al. (2024): its parts were scored in classes and summed with equal
weights. Version 2.0.0 is the calibrated SHMI below. Development builds
before this release were numbered 1.x; they are not separate published
versions of the index.

## Changes from the development builds

### Bug fixes

-   `prepare_shmi_inputs()` and `validate_excel_input()` no longer reject a
    workbook whose required date column (e.g. `CD_term_date`) is present but
    blank in every row, as when every crop ends at harvest.
-   `prepare_shmi_inputs()` accepts workbooks with an empty sheet, such as
    `Soil_Disturbance` for a no-till system with no recorded passes. Empty
    sheets are read as zero rows with typed columns (`MGT_combo` character,
    dates as `Date`), and a unit without tillage records scores Inverse
    Disturbance 100.
-   N-rate assignment (`calc_n_rate = TRUE`) no longer emits repeated
    "no non-missing arguments to min" warnings when no harvest follows an
    application.

### Removed

-   `compute_orginput()`, the Organic Inputs score of the development
    builds. Organic inputs now enter as the grazing credit in Diversity and
    the amendment bonus in SHMI; `compute_orginput_components()` gives the
    shares of years with amendments and with animals.
-   The `expert_mode` and `settings_used` elements of the `build_shmi()`
    result; use `official`, `weights`, `parameters` and `dist_meth`.
-   The unused residue tables in `inst/extdata`
    (`residue_classes.csv`, `residue_crop_map.csv`): residue gets no
    weight once plant presence is known.

### Other changes

-   Documentation uses the names of the paper: **Cover/Roots** (column
    `Cover`), **Diversity** and **Inverse Disturbance** (column
    `InvDist`). Output column names are unchanged; the gauge plot labels
    the first gauge "Cover/Roots".
-   Ranking statistics are reported as in the paper: practices ranked in
    the right direction (a positive within-site rank correlation with
    measured soil health) at 81% of the 58 calibration sites with at least
    three systems.
-   `get_shmi_climate()` keeps the WorldClim normals in a persistent cache,
    `shmi_climate_dir()` (by default `tools::R_user_dir("SHMI", "cache")`;
    set `options(shmi.climate_dir = ...)` or `SHMI_CLIMATE_DIR` to change it),
    instead of the session's temporary folder, so they are downloaded once
    rather than in every R session. Downloads use a longer timeout and one
    retry, and a failure says where to get the files by hand.

## The index

SHMI reports two scores from a field's management record, both 0 to 100:

SHMI_base = 0.687 Cover + 0.150 Diversity + 0.163 InvDist

SHMI = SHMI_base + 0.60 p_amend (100 − SHMI_base)

Each sub-index also runs from 0 to 100.

-   **Cover/Roots** (`Cover`): share of days with plants present in each unit's growing
    and non-growing seasons, set by its climate. A month is in the
    growing season when its mean temperature is at least 5 °C and,
    unless the unit is irrigated, its precipitation (mm) is at least
    twice its temperature (°C). The growing season counts 0.760 and the
    rest of the year 0.240.
-   **Diversity**: number of plant species (cash crops, forages and cover
    crops) in each 4-year span of the record, sliding one year at a time
    and averaged (a record of 4 years or fewer is one span); 0 for one
    species, 100 for eight or more. A corn-soybean rotation scores 14,
    corn-soybean-wheat 29, and corn-soybean-wheat with a rye cover 43.
    `compute_diversity(window = 1)` gives species per calendar year.
    Placeholder mixtures such as "8-species mix" count as that many
    species. **Grazing credit:** animals grazing in a share p_animal of
    years close 0.25 p_animal of the gap to 100 (Diversity = plants +
    0.25 p_animal (100 − plants)); every calendar year a grazing period
    spans counts. Diversity's weight is fixed at 0.15 (see Calibration).
-   **Inverse Disturbance**: tillage intensity computed exactly as
    USDA's Tillage Disturbance Index for Soil Carbon (T-DISC, version
    1.1.1). Each cash crop defines a crop interval; passes fall into
    five tillage windows around planting; implements combine within a
    window by the EPA soil-mixing model; and each interval is rated by
    its most intense window. Each unit also receives T-DISC's
    designation: no-till, reduced till or conventional till. STIR
    records can be scored on the same intervals and windows.
-   **SHMI (SHMI_base plus the amendment bonus)**: organic amendments (`SA_cat` "Organic")
    in a share p_amend of years close 0.60 p_amend of the gap between
    SHMI_base and 100. A unit without amendments has SHMI =
    SHMI_base; no score can exceed 100, and a low SHMI_base gains more than a high one
    (amendments every year add 36 points at SHMI_base 40, 12 at SHMI_base 80).

Scores are named so the calibrated score carries the plain name:
`SHMI` includes the amendment bonus, and `SHMI_base` is the score
without it.

Organic Inputs is no longer a weighted sub-index. As a weighted
sub-index it scored 0 for any field without manure or animals, which
read as a penalty; grazing now raises Diversity, and amendments raise
SHMI_base to SHMI. Custom `weights` naming `OrgInput` give an error
that explains the change.

## Calibration

The weights were calibrated against a soil-health score built from 11
laboratory indicators, adjusted for climate and soil texture, on 354 US
plots at 74 sites of the North American Project to Evaluate Soil Health
Measurements (NAPESHM). They were fitted with the amendment bonus in
place, so SHMI is the calibrated score. Each weight is the median of
1,000 cross-validated fits. Cover/Roots and Diversity share much of
their information, so their combined weight is well determined but its
split is not; Diversity's weight was fixed at 0.15, within the range
where cross-validated fit was unchanged, and the other weights were
fitted under that constraint. The grazing share (0.25) and amendment
share (0.60) were chosen where held-out fit was flat (0.25-0.5 and
0.5-0.8). For sites held out of the fitting, SHMI explained about a
quarter of the differences in soil health (R² = 0.26) and ranked
practices in the right direction at 81% of sites (47 of the 58 with at
least three systems); SHMI_base alone explained 0.23. Each part alone
ranked practices in the right direction at only 50-64% of sites. SHMI is calibrated for US
systems; other regions should recalibrate. `shmi_parameters()`
returns every calibrated constant, and each `build_shmi()` result
records them.

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
    crop's window. A perennial stand that ends with a termination date
    only (plowed down, not harvested) does not take N applied in the 270
    days before it: manure spread ahead of the plow-down, including fall
    manure before a spring plow-down, goes to the next
    crop (reported as `n_plowdown_next_crop`). N rates summarise recorded
    applications only (total N as entered); legume N and carry-over
    credits are not estimated. `$n_rate` gives one row per unit and harvest
    (`crop_year`, `harvest_date`, `crop`, `N_kg_ha`); `crop_year` is the
    year of the harvest and matches `$yield$year`. Calendar-year totals
    are in `$n_rate_calendar`, and `$n_applications` lists each
    application with its calendar and crop year. N applied after a
    unit's last harvest, and units without harvest dates (which fall
    back to calendar years), are reported in `$assumptions`. The first
    crop in each unit's record has no previous harvest, so N applied
    before the record began (for example the previous fall) is missing;
    it is marked `first_in_record` and reported.

Missing records mean a practice did not happen: no tillage, no cover, no
grazing credit or no amendment bonus.

## Main functions

-   `prepare_shmi_inputs()`: read, validate and prepare a workbook.
-   `get_shmi_climate()`: WorldClim monthly climate normals at each
    unit's coordinates (needs `geodata` and `terra`).
-   `build_shmi()`: the sub-indices, `SHMI_base` and `SHMI`, with
    `Amend_bonus` between them, with the official weights and
    constants (`shmi_weights()`, `shmi_parameters()`) or custom values
    (`weights`, `growing_share`, `graze_gap`, `amend_gap`) for research.
-   `compute_cover()`, `compute_diversity()`, `compute_disturbance()`,
    `compute_orginput_components()` and `shmi_components()`: the
    sub-indices and the shares of years with amendments and animals on
    their own.
-   `tdisc_implements()` and `tdisc_mapping()`: the T-DISC implement
    values and operation names used for tillage; a user table
    (`implements =`) can replace or add to them.
-   `plot_shmi_gauge()` and `plot_shmi_lollipop()`: results for one unit
    or many, with SHMI_base shown alongside SHMI.
