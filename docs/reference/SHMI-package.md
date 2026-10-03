# SHMI: Soil Health Management Index

Computes the Soil Health Management Index (SHMI) from management records
entered in a standard Excel workbook. SHMI is a 0-100 weighted sum of
four sub-indices, each also 0-100:

## Details

- **Cover** (weight 0.400): share of days with living plants in the
  growing and non-growing seasons, set by each unit's climate.

- **Organic inputs** (0.317): share of years with an organic amendment
  or grazing animals.

- **Diversity** (0.153): average number of plant species per year.

- **Inverse disturbance** (0.130): how little the soil was tilled,
  computed as in USDA's Tillage Disturbance Index for Soil Carbon
  (T-DISC).

The weights were calibrated against measured soil health on 354 US plots
at 74 sites of the North American Project to Evaluate Soil Health
Measurements (NAPESHM); see
[`shmi_weights()`](https://danielmanter-usda.github.io/SHMI/reference/shmi_weights.md).

## Workflow

1.  [`download_shmi_template()`](https://danielmanter-usda.github.io/SHMI/reference/download_shmi_template.md)
    provides a blank workbook, and
    [`download_shmi_example()`](https://danielmanter-usda.github.io/SHMI/reference/download_shmi_example.md)
    a completed one;
    [`get_shmi_example()`](https://danielmanter-usda.github.io/SHMI/reference/get_shmi_example.md)
    gives the path of the installed example.

2.  [`prepare_shmi_inputs()`](https://danielmanter-usda.github.io/SHMI/reference/prepare_shmi_inputs.md)
    reads and validates the workbook, converts crop records into species
    episodes, and records every assumption it makes.

3.  [`get_shmi_climate()`](https://danielmanter-usda.github.io/SHMI/reference/get_shmi_climate.md)
    provides monthly climate normals for each unit, which set Cover's
    growing season.

4.  [`build_shmi()`](https://danielmanter-usda.github.io/SHMI/reference/build_shmi.md)
    computes the four sub-indices and SHMI.

5.  [`plot_shmi_gauge()`](https://danielmanter-usda.github.io/SHMI/reference/plot_shmi_gauge.md)
    and
    [`plot_shmi_lollipop()`](https://danielmanter-usda.github.io/SHMI/reference/plot_shmi_lollipop.md)
    display the results.

The sub-indices can also be computed directly with
[`compute_cover()`](https://danielmanter-usda.github.io/SHMI/reference/compute_cover.md),
[`compute_diversity()`](https://danielmanter-usda.github.io/SHMI/reference/compute_diversity.md),
[`compute_disturbance()`](https://danielmanter-usda.github.io/SHMI/reference/compute_disturbance.md)
and
[`compute_orginput()`](https://danielmanter-usda.github.io/SHMI/reference/compute_orginput.md),
or all at once with
[`shmi_components()`](https://danielmanter-usda.github.io/SHMI/reference/shmi_components.md).

## Design principles

- **Missing records mean "did not happen".** No disturbance record means
  no disturbance (InvDist = 100); no crop means no cover; no amendment
  or animal record means no organic input.

- **The evaluation window is set by the data or by overrides.** Each
  unit is scored from 1 January of its first year with a record to 31
  December of its last, unless `start_date_override` /
  `end_date_override` or `end_at_sample_date` are given to
  [`prepare_shmi_inputs()`](https://danielmanter-usda.github.io/SHMI/reference/prepare_shmi_inputs.md).
  All four sub-indices use the same window.

- **Assumptions are reported, not hidden.** Every imputed date and every
  value that could not be converted is listed in
  `prepare_shmi_inputs()$assumptions`.

## Official scores

[`build_shmi()`](https://danielmanter-usda.github.io/SHMI/reference/build_shmi.md)
uses the official weights and computes tillage intensity as T-DISC does,
with implement values from T-DISC
([`tdisc_implements()`](https://danielmanter-usda.github.io/SHMI/reference/tdisc_implements.md),
[`tdisc_mapping()`](https://danielmanter-usda.github.io/SHMI/reference/tdisc_mapping.md))
unless the records or a user table give others (STIR values can be
scored with `dist_meth = "STIR"`). Custom weights can be supplied for
research; those scores are flagged in the result (`official = FALSE`).
Each result records the weights, the tillage scale, the package version
and a timestamp.

## See also

Useful links:

- <https://danielmanter-usda.github.io/SHMI/>

- <https://github.com/DanielManter-USDA/SHMI>

- Report bugs at <https://github.com/DanielManter-USDA/SHMI/issues>

## Author

**Maintainer**: Daniel Manter <daniel.manter@usda.gov>

Authors:

- Daniel Manter <daniel.manter@usda.gov>

- Jennifer Moore <jennifer.moore2@usda.gov>
