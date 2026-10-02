#' SHMI: Soil Health Management Index
#'
#' Computes the Soil Health Management Index (SHMI) from management records
#' entered in a standard Excel workbook. SHMI is a 0-100 weighted sum of four
#' sub-indices, each also 0-100:
#'
#' * **Cover** (weight 0.400): share of days with living plants in the
#'   growing and non-growing seasons, set by each unit's climate.
#' * **Organic inputs** (0.317): share of years with an organic amendment or
#'   grazing animals.
#' * **Diversity** (0.153): average number of plant species per year.
#' * **Inverse disturbance** (0.130): how little the soil was tilled,
#'   computed as in USDA's Tillage Disturbance Index for Soil Carbon (T-DISC).
#'
#' The weights were calibrated against measured soil health on 354 US plots
#' at 74 sites of the North American Project to Evaluate Soil Health
#' Measurements (NAPESHM); see [shmi_weights()].
#'
#' @section Workflow:
#' 1. [download_shmi_template()] provides a blank workbook, and
#'    [download_shmi_example()] a completed one; [get_shmi_example()] gives
#'    the path of the installed example.
#' 2. [prepare_shmi_inputs()] reads and validates the workbook, converts crop
#'    records into species episodes, and records every assumption it makes.
#' 3. [get_shmi_climate()] provides monthly climate normals for each unit,
#'    which set Cover's growing season.
#' 4. [build_shmi()] computes the four sub-indices and SHMI.
#' 5. [plot_shmi_gauge()] and [plot_shmi_lollipop()] display the results.
#'
#' The sub-indices can also be computed directly with [compute_cover()],
#' [compute_diversity()], [compute_disturbance()] and [compute_orginput()],
#' or all at once with [shmi_components()].
#'
#' @section Design principles:
#' * **Missing records mean "did not happen".** No disturbance record means
#'   no disturbance (InvDist = 100); no crop means no cover; no amendment or
#'   animal record means no organic input.
#' * **The evaluation window is set by the data or by overrides.** Each unit
#'   is scored from 1 January of its first year with a record to 31 December
#'   of its last, unless `start_date_override` / `end_date_override` or
#'   `end_at_sample_date` are given to [prepare_shmi_inputs()]. All four
#'   sub-indices use the same window.
#' * **Assumptions are reported, not hidden.** Every imputed date and every
#'   value that could not be converted is listed in
#'   `prepare_shmi_inputs()$assumptions`.
#'
#' @section Official scores:
#' [build_shmi()] uses the official weights and computes tillage intensity
#' as T-DISC does, with implement values from T-DISC ([tdisc_implements()],
#' [tdisc_mapping()]) unless the records or a user table give others (STIR
#' values can be scored with `dist_meth = "STIR"`). Custom weights can be supplied for research; those
#' scores are flagged in the result (`official = FALSE`). Each result records
#' the weights, the tillage scale, the package version and a timestamp.
#'
#' @keywords internal
"_PACKAGE"
